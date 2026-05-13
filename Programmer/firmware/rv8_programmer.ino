// ============================================================
// RV8 Programmer — ESP32 NodeMCU Firmware
// ROM flasher (PROG) + UART bridge (RUN) for RV8 family CPUs
// Target: AT28C256 (32KB), 74HC595 for A[8:14]
// Serial protocol: 115200 baud
//   'F' + len_hi + len_lo + data[len] → flash ROM
//   'V' → verify (read back and send)
//   'R' → reset CPU (pulse /RST)
// ============================================================

// --- Pin Definitions ---

// Data bus D[7:0] — bidirectional, directly connected via level shifters
const int DATA_PINS[8] = {32, 33, 25, 26, 27, 14, 12, 13};

// Address bus A[7:0] — directly driven in PROG mode
const int ADDR_PINS[8] = {15, 16, 17, 18, 19, 21, 22, 23};

// 74HC595 shift register for A[8:14]
// Hardware: tie 595 RCLK to SRCLK (outputs update on each clock edge)
#define PIN_SR_DATA  4   // SER (pin 14 on 595)
#define PIN_SR_CLK   5   // SRCLK + RCLK (pins 11,12 on 595)

// Control signals
#define PIN_nWE   0   // /WE to ROM — active low (GPIO0: HIGH at boot = safe)
#define PIN_nRST  2   // /RST to CPU — active low (GPIO2: LOW at boot = CPU reset = safe)

// Input-only pins (GPIO 34-39)
#define PIN_nSLOT 34  // /SLOT1 — goes LOW when CPU accesses I/O slot
#define PIN_nRD   35  // /RD from CPU — LOW on read cycle
#define PIN_nWR   36  // /WR from CPU — LOW on write cycle
#define PIN_MODE  39  // PROG/RUN switch: LOW=PROG, HIGH=RUN

// --- State ---
enum Mode { MODE_PROG, MODE_RUN };
volatile Mode currentMode;
volatile bool rxReady = false;   // byte waiting for CPU to read
volatile uint8_t rxByte = 0;     // byte from PC for CPU

// --- Data Bus Helpers ---

void dataBusOutput() {
  for (int i = 0; i < 8; i++) pinMode(DATA_PINS[i], OUTPUT);
}

void dataBusInput() {
  for (int i = 0; i < 8; i++) pinMode(DATA_PINS[i], INPUT);
}

void dataBusWrite(uint8_t val) {
  for (int i = 0; i < 8; i++) {
    digitalWrite(DATA_PINS[i], (val >> i) & 1);
  }
}

uint8_t dataBusRead() {
  uint8_t val = 0;
  for (int i = 0; i < 8; i++) {
    if (digitalRead(DATA_PINS[i])) val |= (1 << i);
  }
  return val;
}

// --- Address Helpers ---

void addrOutput() {
  for (int i = 0; i < 8; i++) pinMode(ADDR_PINS[i], OUTPUT);
}

void addrRelease() {
  for (int i = 0; i < 8; i++) pinMode(ADDR_PINS[i], INPUT);
}

// Set full 15-bit address: A[7:0] direct, A[14:8] via shift register
void setAddress(uint16_t addr) {
  // A[7:0] — direct GPIO
  for (int i = 0; i < 8; i++) {
    digitalWrite(ADDR_PINS[i], (addr >> i) & 1);
  }
  // A[14:8] — shift out via 74HC595 (MSB first, Q0=A8 .. Q6=A14)
  uint8_t hi = (addr >> 8) & 0x7F;
  for (int i = 6; i >= 0; i--) {
    digitalWrite(PIN_SR_DATA, (hi >> i) & 1);
    digitalWrite(PIN_SR_CLK, HIGH);
    digitalWrite(PIN_SR_CLK, LOW);
  }
  // One extra clock to push bit 0 into Q0 position
  // (We shifted 7 bits MSB-first: first bit shifted is Q6 after 7 clocks)
  // Actually with 7 shifts, bit6 is in Q6, bit0 is in Q0. Correct.
}

// --- ROM Write (PROG mode) ---

void romWriteByte(uint16_t addr, uint8_t data) {
  setAddress(addr);
  dataBusOutput();
  dataBusWrite(data);
  delayMicroseconds(1);  // address/data setup time

  // Pulse /WE low (min 100ns, we'll do ~200ns)
  digitalWrite(PIN_nWE, LOW);
  delayMicroseconds(1);  // ~1µs pulse (well above 100ns minimum)
  digitalWrite(PIN_nWE, HIGH);

  delayMicroseconds(1);  // data hold time
}

uint8_t romReadByte(uint16_t addr) {
  setAddress(addr);
  dataBusInput();
  digitalWrite(PIN_nWE, HIGH);  // ensure /WE inactive
  delayMicroseconds(1);         // output enable time
  return dataBusRead();
}

// --- Serial Protocol Handlers ---

void handleFlash() {
  // Read 2-byte length (big-endian)
  while (Serial.available() < 2) yield();
  uint16_t len = (Serial.read() << 8) | Serial.read();

  if (len == 0 || len > 32768) {
    Serial.print("E:BAD_LEN\n");
    return;
  }

  Serial.print("K\n");  // ACK, ready to receive data

  // Hold CPU in reset, set up for programming
  digitalWrite(PIN_nRST, LOW);
  digitalWrite(PIN_nWE, HIGH);
  addrOutput();
  delay(10);

  uint16_t addr = 0;
  uint16_t received = 0;
  uint32_t lastPageAddr = 0xFFFF;

  while (received < len) {
    if (Serial.available()) {
      uint8_t b = Serial.read();

      // AT28C256 page write: 64-byte pages. Insert delay at page boundary.
      uint16_t page = addr & 0x7FC0;  // 64-byte page
      if (page != lastPageAddr && lastPageAddr != 0xFFFF) {
        delay(10);  // page write completion delay
      }
      lastPageAddr = page;

      romWriteByte(addr, b);
      addr++;
      received++;
    }
    yield();
  }

  delay(10);  // final page write completion
  Serial.print("D\n");  // Done
}

void handleVerify() {
  // Read back entire ROM and send to PC for verification
  digitalWrite(PIN_nRST, LOW);
  digitalWrite(PIN_nWE, HIGH);
  addrOutput();
  dataBusInput();
  delay(1);

  // Send 32KB
  for (uint16_t addr = 0; addr < 32768; addr++) {
    Serial.write(romReadByte(addr));
    if ((addr & 0xFF) == 0) yield();  // prevent WDT
  }
}

void handleReset() {
  // Pulse /RST low for 10ms then release
  digitalWrite(PIN_nRST, LOW);
  delay(10);
  digitalWrite(PIN_nRST, HIGH);
  Serial.print("K\n");
}

// --- RUN Mode: UART Bridge ---

void runModePoll() {
  // CPU WRITE: /SLOT1 LOW + /WR LOW → read D[7:0], send to PC
  if (digitalRead(PIN_nSLOT) == LOW && digitalRead(PIN_nWR) == LOW) {
    dataBusInput();
    uint8_t b = dataBusRead();
    Serial.write(b);
    // Wait for /WR to go back HIGH (end of write cycle)
    while (digitalRead(PIN_nWR) == LOW) {}
  }

  // CPU READ: /SLOT1 LOW + /RD LOW → drive D[7:0] with buffered byte
  if (digitalRead(PIN_nSLOT) == LOW && digitalRead(PIN_nRD) == LOW) {
    if (rxReady) {
      dataBusOutput();
      dataBusWrite(rxByte);
      rxReady = false;
    } else {
      dataBusOutput();
      dataBusWrite(0x00);  // no data available (CPU can check status reg)
    }
    // Wait for /RD to go back HIGH
    while (digitalRead(PIN_nRD) == LOW) {}
    dataBusInput();  // release bus
  }

  // Buffer incoming byte from PC
  if (!rxReady && Serial.available()) {
    rxByte = Serial.read();
    rxReady = true;
  }
}

// --- Mode Detection ---

Mode detectMode() {
  return digitalRead(PIN_MODE) == LOW ? MODE_PROG : MODE_RUN;
}

void enterProgMode() {
  Serial.println("[PROG]");
  digitalWrite(PIN_nRST, LOW);   // hold CPU in reset
  digitalWrite(PIN_nWE, HIGH);   // /WE inactive
  addrOutput();
  dataBusInput();
}

void enterRunMode() {
  Serial.println("[RUN]");
  addrRelease();                  // release address bus
  dataBusInput();                 // release data bus
  digitalWrite(PIN_nWE, HIGH);   // /WE inactive
  digitalWrite(PIN_nRST, HIGH);  // release CPU from reset
  rxReady = false;
}

// --- Setup & Loop ---

void setup() {
  Serial.begin(115200);
  while (!Serial) delay(1);

  // Control pins
  pinMode(PIN_nWE, OUTPUT);
  digitalWrite(PIN_nWE, HIGH);
  pinMode(PIN_nRST, OUTPUT);
  digitalWrite(PIN_nRST, LOW);  // hold reset initially

  // Shift register
  pinMode(PIN_SR_DATA, OUTPUT);
  pinMode(PIN_SR_CLK, OUTPUT);
  digitalWrite(PIN_SR_CLK, LOW);

  // Input-only pins
  pinMode(PIN_nSLOT, INPUT);
  pinMode(PIN_nRD, INPUT);
  pinMode(PIN_nWR, INPUT);
  pinMode(PIN_MODE, INPUT);

  // Detect initial mode
  currentMode = detectMode();
  if (currentMode == MODE_PROG) {
    enterProgMode();
  } else {
    enterRunMode();
  }

  Serial.println("RV8 Programmer ready");
}

void loop() {
  // Auto-detect mode switch change
  Mode m = detectMode();
  if (m != currentMode) {
    currentMode = m;
    if (m == MODE_PROG) enterProgMode();
    else enterRunMode();
  }

  if (currentMode == MODE_PROG) {
    // Wait for commands from PC
    if (Serial.available()) {
      char cmd = Serial.read();
      switch (cmd) {
        case 'F': handleFlash();  break;
        case 'V': handleVerify(); break;
        case 'R': handleReset();  break;
        default:  Serial.print("E:UNK\n"); break;
      }
    }
  } else {
    // RUN mode: UART bridge
    runModePoll();
  }
}
