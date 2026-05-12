// RV8 Trainer Board — ESP32 NodeMCU Firmware
// PROG mode: receives binary over USB, writes to AT28C256 (via level shifter)
// RUN mode: USB-serial bridge to MC6850
// All I/O through 74HCT245 level shifter (3.3V → 5V)

// --- Pin definitions ---
// 595 shift register (address)
#define SER    23
#define SRCLK  18
#define RCLK   19

// Data bus D0-D7
const uint8_t DATA_PINS[] = {13, 12, 14, 27, 26, 25, 33, 32};

// ROM control
#define WE_PIN  4
#define CE_PIN  16
#define OE_PIN  17

// Mode + CPU control
#define PROG_SW  34  // input-only pin, fine for reading switch
#define RST_PIN  5

// Serial bridge (RUN mode) — use UART2
#define UART_TX  21
#define UART_RX  22

void setAddress(uint16_t addr) {
  // Shift out 16 bits (only 15 used: A0-A14)
  for (int i = 15; i >= 0; i--) {
    digitalWrite(SER, (addr >> i) & 1);
    digitalWrite(SRCLK, HIGH);
    digitalWrite(SRCLK, LOW);
  }
  digitalWrite(RCLK, HIGH);
  digitalWrite(RCLK, LOW);
}

void setDataOutput(uint8_t val) {
  for (int i = 0; i < 8; i++) {
    pinMode(DATA_PINS[i], OUTPUT);
    digitalWrite(DATA_PINS[i], (val >> i) & 1);
  }
}

void setDataInput() {
  for (int i = 0; i < 8; i++) {
    pinMode(DATA_PINS[i], INPUT);
  }
}

uint8_t readData() {
  uint8_t val = 0;
  for (int i = 0; i < 8; i++) {
    val |= (digitalRead(DATA_PINS[i]) << i);
  }
  return val;
}

void writeByte(uint16_t addr, uint8_t data) {
  setAddress(addr);
  setDataOutput(data);
  digitalWrite(CE_PIN, LOW);
  digitalWrite(OE_PIN, HIGH);
  digitalWrite(WE_PIN, LOW);
  delayMicroseconds(1);
  digitalWrite(WE_PIN, HIGH);
  digitalWrite(CE_PIN, HIGH);
  // Poll D7 for write completion
  setDataInput();
  digitalWrite(CE_PIN, LOW);
  digitalWrite(OE_PIN, LOW);
  for (int i = 0; i < 200; i++) {
    if (readData() == data) break;
    delayMicroseconds(50);
  }
  digitalWrite(OE_PIN, HIGH);
  digitalWrite(CE_PIN, HIGH);
}

uint8_t readByte(uint16_t addr) {
  setAddress(addr);
  setDataInput();
  digitalWrite(CE_PIN, LOW);
  digitalWrite(OE_PIN, LOW);
  delayMicroseconds(1);
  uint8_t val = readData();
  digitalWrite(OE_PIN, HIGH);
  digitalWrite(CE_PIN, HIGH);
  return val;
}

bool isProgMode() {
  return digitalRead(PROG_SW) == HIGH;
}

void progMode() {
  digitalWrite(RST_PIN, LOW); // hold CPU in reset

  pinMode(SER, OUTPUT);
  pinMode(SRCLK, OUTPUT);
  pinMode(RCLK, OUTPUT);
  pinMode(WE_PIN, OUTPUT);
  pinMode(CE_PIN, OUTPUT);
  pinMode(OE_PIN, OUTPUT);
  digitalWrite(WE_PIN, HIGH);
  digitalWrite(CE_PIN, HIGH);
  digitalWrite(OE_PIN, HIGH);

  while (isProgMode()) {
    if (!Serial.available()) continue;
    char cmd = Serial.read();
    if (cmd == 'P') {
      Serial.print("OK");
    } else if (cmd == 'W') {
      while (Serial.available() < 4) yield();
      uint16_t addr = (Serial.read() << 8) | Serial.read();
      uint16_t len  = (Serial.read() << 8) | Serial.read();
      for (uint16_t i = 0; i < len; i++) {
        while (!Serial.available()) yield();
        writeByte(addr + i, Serial.read());
      }
      Serial.write(0x06);
    } else if (cmd == 'R') {
      while (Serial.available() < 4) yield();
      uint16_t addr = (Serial.read() << 8) | Serial.read();
      uint16_t len  = (Serial.read() << 8) | Serial.read();
      for (uint16_t i = 0; i < len; i++) {
        Serial.write(readByte(addr + i));
      }
    } else if (cmd == 'V') {
      while (Serial.available() < 4) yield();
      uint16_t addr = (Serial.read() << 8) | Serial.read();
      uint16_t len  = (Serial.read() << 8) | Serial.read();
      bool ok = true;
      for (uint16_t i = 0; i < len; i++) {
        while (!Serial.available()) yield();
        if (readByte(addr + i) != Serial.read()) ok = false;
      }
      Serial.write(ok ? 0x06 : 0x15);
    }
  }
}

void runMode() {
  // Release CPU
  digitalWrite(RST_PIN, HIGH);
  // Hi-Z all ROM pins
  setDataInput();
  pinMode(SER, INPUT);
  pinMode(SRCLK, INPUT);
  pinMode(RCLK, INPUT);
  pinMode(WE_PIN, INPUT);
  pinMode(CE_PIN, INPUT);
  pinMode(OE_PIN, INPUT);

  // Serial bridge: USB (Serial) ↔ MC6850 (Serial2)
  Serial2.begin(115200, SERIAL_8N1, UART_RX, UART_TX);
  while (!isProgMode()) {
    if (Serial.available()) Serial2.write(Serial.read());
    if (Serial2.available()) Serial.write(Serial2.read());
  }
  Serial2.end();
}

void setup() {
  Serial.begin(115200);
  pinMode(PROG_SW, INPUT);
  pinMode(RST_PIN, OUTPUT);
  digitalWrite(RST_PIN, HIGH);
}

void loop() {
  if (isProgMode()) {
    progMode();
  } else {
    runMode();
  }
}
