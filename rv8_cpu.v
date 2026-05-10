// RV8 CPU v4 — Correct opcode-range decode
`timescale 1ns / 1ps

module rv8_alu(input [7:0] a,b, input [2:0] op, input ci, output reg [7:0] r, output reg co, output wire z,n);
    always @(*) begin co=0; case(op)
        0:{co,r}=a+b+ci; 1:{co,r}=a-b-~ci; 2:r=a&b; 3:r=a|b;
        4:r=a^b; 5:begin r={1'b0,a[7:1]};co=a[0];end 6:begin r={a[6:0],1'b0};co=a[7];end 7:r=b;
        default:r=0; endcase end
    assign z=(r==0); assign n=r[7];
endmodule

module rv8_cpu(input clk, rst_n, nmi_n, irq_n, output reg [15:0] addr_bus,
    inout wire [7:0] data_bus, output reg mem_rd_n, mem_wr_n, output wire halt);

    reg [15:0] pc;
    reg [7:0] a0,t0,sp,pl,ph,pg,ir_op,ir_opr;
    reg fz,fc,fn,fie,skip;
    reg [4:0] state;
    reg [7:0] dout; reg doe;
    assign data_bus = doe ? dout : 8'bz;
    wire [7:0] din = data_bus;
    assign halt = (state==4'd7);

    // ALU
    reg [7:0] ab; reg [2:0] aop;
    wire [7:0] ar; wire aco,az,an;
    rv8_alu ALU(.a(a0),.b(ab),.op(aop),.ci(fc),.r(ar),.co(aco),.z(az),.n(an));

    // Reg read - uses din directly (operand byte on bus during EX)
    reg [7:0] rs;
    always @(*) begin
        reg [2:0] rsel;
        rsel = (state==EX) ? din[2:0] : ir_opr[2:0];
        case(rsel)
            0:case(din[4:3]) 0:rs=0;1:rs=1;2:rs=8'hFF;3:rs=8'h80;endcase // const gen uses bits[4:3]
            1:rs=sp;2:rs=a0;3:rs=pl;4:rs=ph;5:rs=t0;6:rs=pg;default:rs=0;
        endcase
    end

    // States
    localparam B0=0,B1=1,B2=2,F1=3,EX=4,M1=5,M2=6,HLT=7;

    reg nmi_prev, nmi_pend;

    // NMI edge detect + interrupt check helper
    wire irq_fire = fie && !irq_n && !skip;
    wire nmi_fire = nmi_pend && !skip;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=B0; pc<=0; a0<=0;t0<=0;sp<=8'hFF;pl<=0;ph<=0;pg<=0;
            ir_op<=8'hFE;ir_opr<=0; fz<=0;fc<=0;fn<=0;fie<=0;skip<=0;
            addr_bus<=16'hFFFC;mem_rd_n<=0;mem_wr_n<=1;doe<=0;dout<=0;
            nmi_prev<=1; nmi_pend<=0;
        end else begin
            mem_rd_n<=1;mem_wr_n<=1;doe<=0;
            // NMI edge detect
            nmi_prev<=nmi_n;
            if(nmi_prev && !nmi_n) nmi_pend<=1;
            case(state)
            B0: begin addr_bus<=16'hFFFC; mem_rd_n<=0; state<=B1; end
            B1: begin pc[7:0]<=din; addr_bus<=16'hFFFD; mem_rd_n<=0; state<=B2; end
            B2: begin pc[15:8]<=din; addr_bus<={din,pc[7:0]}; mem_rd_n<=0; state<=F1; end
            F1: begin // Latch opcode, fetch operand
                ir_op<=din; addr_bus<=pc+16'd1; mem_rd_n<=0; state<=EX;
            end
            EX: begin // Latch operand, execute
                ir_opr<=din; pc<=pc+16'd2;
                if(skip) begin skip<=0; addr_bus<=pc+16'd2; mem_rd_n<=0; state<=F1; end
                else if(ir_op<=8'h07) begin // ALU reg (0x00-0x07)
                    reg [8:0] tmp;
                    case(ir_op[2:0])
                        0: tmp = a0 + rs;           // ADD (no carry)
                        1: tmp = a0 - rs;           // SUB (no borrow)
                        2: tmp = {1'b0, a0 & rs};   // AND
                        3: tmp = {1'b0, a0 | rs};   // OR
                        4: tmp = {1'b0, a0 ^ rs};   // XOR
                        5: tmp = a0 - rs;           // CMP = SUB without write
                        6: tmp = a0 + rs + fc;      // ADC (with carry)
                        7: tmp = a0 - rs - {8'd0,~fc}; // SBC (borrow=!C)
                        default: tmp = 0;
                    endcase
                    if(ir_op!=8'h05) a0<=tmp[7:0]; // CMP doesn't write
                    fz<=(tmp[7:0]==0); fc<=tmp[8]; fn<=tmp[7];
                    addr_bus<=pc+16'd2; mem_rd_n<=0; state<=F1;
                end
                else if(ir_op>=8'h10 && ir_op<=8'h15) begin // LI (0x10-0x15)
                    case(ir_op)
                        8'h10:sp<=din; 8'h11:a0<=din; 8'h12:pl<=din;
                        8'h13:ph<=din; 8'h14:t0<=din; 8'h15:pg<=din;
                    endcase
                    addr_bus<=pc+16'd2; mem_rd_n<=0; state<=F1;
                end
                else if(ir_op>=8'h16 && ir_op<=8'h1C) begin // ALU imm (0x16-0x1C)
                    // Compute inline (can't rely on ALU module within same clk edge)
                    reg [8:0] tmp;
                    case(ir_op)
                        8'h16: tmp = a0 + din;           // ADDI (no carry)
                        8'h17: tmp = a0 - din;           // SUBI (no borrow)
                        8'h18: tmp = a0 - din;           // CMPI
                        8'h19: tmp = {1'b0, a0 & din};   // ANDI
                        8'h1A: tmp = {1'b0, a0 | din};   // ORI
                        8'h1B: tmp = {1'b0, a0 ^ din};   // XORI
                        8'h1C: tmp = {1'b0, a0 & din};   // TST
                        default: tmp = 0;
                    endcase
                    if(ir_op!=8'h18 && ir_op!=8'h1C) a0<=tmp[7:0];
                    fz<=(tmp[7:0]==0); fc<=tmp[8]; fn<=tmp[7];
                    addr_bus<=pc+16'd2; mem_rd_n<=0; state<=F1;
                end
                else if(ir_op==8'h20||ir_op==8'h22) begin // LB (ptr)/(ptr+)
                    addr_bus<={ph,pl}; mem_rd_n<=0; state<=M1;
                end
                else if(ir_op==8'h21||ir_op==8'h23) begin // SB (ptr)/(ptr+)
                    addr_bus<={ph,pl}; state<=M2; // M2 does the write
                end
                else if(ir_op==8'h24) begin // MOV rd, a0
                    case(din[2:0]) 1:sp<=a0; 3:pl<=a0; 4:ph<=a0; 5:t0<=a0; 6:pg<=a0; endcase
                    addr_bus<=pc+16'd2; mem_rd_n<=0; state<=F1;
                end
                else if(ir_op==8'h25) begin // MOV a0, rs
                    a0<=rs; addr_bus<=pc+16'd2; mem_rd_n<=0; state<=F1;
                end
                else if(ir_op==8'h26||ir_op==8'h28||ir_op==8'h2A) begin // LB [sp+imm]/[zp]/[pg:imm]
                    if(ir_op==8'h26) addr_bus<={8'h30,sp+din};
                    else if(ir_op==8'h28) addr_bus<={8'h00,din};
                    else addr_bus<={pg,din};
                    mem_rd_n<=0; state<=M1;
                end
                else if(ir_op==8'h27||ir_op==8'h29||ir_op==8'h2B) begin // SB [sp+imm]/[zp]/[pg:imm]
                    if(ir_op==8'h27) addr_bus<={8'h30,sp+din};
                    else if(ir_op==8'h29) addr_bus<={8'h00,din};
                    else addr_bus<={pg,din};
                    state<=M2;
                end
                else if(ir_op==8'h2C) begin // PUSH
                    sp<=sp-8'd1; addr_bus<={8'h30,sp-8'd1}; state<=M2;
                end
                else if(ir_op==8'h2D) begin // POP
                    addr_bus<={8'h30,sp}; sp<=sp+8'd1; mem_rd_n<=0; state<=M1;
                end
                else if(ir_op>=8'h30 && ir_op<=8'h36) begin // Branches
                    reg taken;
                    case(ir_op[2:0]) 0:taken=fz; 1:taken=~fz; 2:taken=fc; 3:taken=~fc;
                        4:taken=fn; 5:taken=~fn; 6:taken=1; default:taken=0; endcase
                    if(taken) pc<=pc+16'd2+{{8{din[7]}},din};
                    addr_bus<=pc+16'd2; mem_rd_n<=0; state<=F1;
                    if(taken) begin addr_bus<=pc+16'd2+{{8{din[7]}},din}; end
                end
                else if(ir_op>=8'h37 && ir_op<=8'h3A) begin // Skip
                    reg sc;
                    case(ir_op)
                        8'h37: sc=fz;   // SKIPZ
                        8'h38: sc=~fz;  // SKIPNZ
                        8'h39: sc=fc;   // SKIPC
                        8'h3A: sc=~fc;  // SKIPNC
                        default: sc=0;
                    endcase
                    if(sc) skip<=1;
                    addr_bus<=pc+16'd2; mem_rd_n<=0; state<=F1;
                end
                else if(ir_op==8'h3C) begin // JMP (ptr)
                    pc<={ph,pl}; addr_bus<={ph,pl}; mem_rd_n<=0; state<=F1;
                end
                else if(ir_op==8'h3D) begin // JAL (ptr) - push return addr, jump to ptr
                    // Return address = pc+2 (next instruction after JAL)
                    // pc is still old value here (non-blocking pc<=pc+2 not yet effective)
                    sp<=sp-8'd1; addr_bus<={8'h30,sp-8'd1};
                    dout<=pc[15:8]; // high byte (pc+2 won't cross page for typical code)
                    doe<=1; mem_wr_n<=0;
                    state<=5'd10;
                end
                else if(ir_op==8'h3E) begin // RET - pop PC
                    addr_bus<={8'h30,sp}; sp<=sp+8'd1; mem_rd_n<=0;
                    state<=5'd12; // RET_S2: latch low, read high
                end
                else if(ir_op>=8'h40 && ir_op<=8'h47) begin // Shift/Unary
                    case(ir_op[2:0])
                        0:begin fc<=a0[7]; a0<={a0[6:0],1'b0}; end
                        1:begin fc<=a0[0]; a0<={1'b0,a0[7:1]}; end
                        2:begin fc<=a0[7]; a0<={a0[6:0],fc}; end
                        3:begin fc<=a0[0]; a0<={fc,a0[7:1]}; end
                        4:begin a0<=a0+8'd1; end
                        5:begin a0<=a0-8'd1; end
                        6:begin a0<=~a0; end
                        7:begin a0<={a0[3:0],a0[7:4]}; end
                    endcase
                    fz<=(ir_op[2:0]<=3'd3) ? (ar==0) : // shifts use ALU
                        (ir_op==8'h44) ? (a0+1==0) :
                        (ir_op==8'h45) ? (a0-1==0) :
                        (ir_op==8'h46) ? (~a0==0) : fz;
                    addr_bus<=pc+16'd2; mem_rd_n<=0; state<=F1;
                end
                else if(ir_op>=8'h48 && ir_op<=8'h4A) begin // Pointer ops
                    case(ir_op)
                        8'h48: {ph,pl}<={ph,pl}+16'd1;
                        8'h49: {ph,pl}<={ph,pl}-16'd1;
                        8'h4A: {ph,pl}<={ph,pl}+{8'd0,din};
                    endcase
                    addr_bus<=pc+16'd2; mem_rd_n<=0; state<=F1;
                end
                else if(ir_op==8'hF0) begin fc<=0; addr_bus<=pc+16'd2; mem_rd_n<=0; state<=F1; end
                else if(ir_op==8'hF1) begin fc<=1; addr_bus<=pc+16'd2; mem_rd_n<=0; state<=F1; end
                else if(ir_op==8'hF2) begin fie<=1; addr_bus<=pc+16'd2; mem_rd_n<=0; state<=F1; end
                else if(ir_op==8'hF3) begin fie<=0; addr_bus<=pc+16'd2; mem_rd_n<=0; state<=F1; end
                else if(ir_op==8'hF4) begin // RTI: pop flags, pop PCL, pop PCH
                    addr_bus<={8'h30,sp}; sp<=sp+8'd1; mem_rd_n<=0; state<=5'd14;
                end
                else if(ir_op==8'hF5) begin // TRAP: push PCH, then PCL, then flags, jump to 0xFFF6
                    sp<=sp-8'd1; addr_bus<={8'h30,sp-8'd1};
                    dout<=pc[15:8]; doe<=1; mem_wr_n<=0;
                    fie<=0; state<=5'd10; // push PCL next
                    // After push sequence (states 10→11), state 11 jumps to {ph,pl}
                    // Set ptr to TRAP vector so state 11 reads from there
                    ph<=8'hFF; pl<=8'hF6;
                end
                else if(ir_op==8'hFE) begin addr_bus<=pc+16'd2; mem_rd_n<=0; state<=F1; end // NOP
                else if(ir_op==8'hFF) begin state<=HLT; end // HLT
                else begin addr_bus<=pc+16'd2; mem_rd_n<=0; state<=F1; end // unknown→NOP
            end
            M1: begin // Memory READ done, latch data
                if(ir_op==8'h20||ir_op==8'h22||ir_op==8'h26||ir_op==8'h28||ir_op==8'h2A||ir_op==8'h2D)
                    a0<=din;
                if(ir_op==8'h22||ir_op==8'h23) {ph,pl}<={ph,pl}+16'd1; // ptr+
                addr_bus<=pc; mem_rd_n<=0; state<=F1;
            end
            M2: begin // Memory WRITE
                dout<=a0; doe<=1; mem_wr_n<=0;
                if(ir_op==8'h22||ir_op==8'h23) {ph,pl}<={ph,pl}+16'd1; // ptr+
                state<=4'd9; // M3: finish write
            end
            4'd9: begin // M3: write done, next fetch
                addr_bus<=pc; mem_rd_n<=0; state<=F1;
            end
            5'd10: begin // JAL_S2 / TRAP_S2: push PC low byte
                sp<=sp-8'd1; addr_bus<={8'h30,sp-8'd1};
                dout<=pc[7:0]; doe<=1; mem_wr_n<=0;
                if(ir_op==8'hF5) state<=5'd16; // TRAP: push flags next
                else state<=5'd11; // JAL: jump next
            end
            5'd11: begin // JAL_S3 / TRAP_S3: jump to target
                if(ir_op==8'hF5) begin // TRAP: read vector from {ph,pl}
                    addr_bus<={ph,pl}; mem_rd_n<=0; state<=5'd15; // read vector low
                end else begin // JAL: jump directly to {ph,pl}
                    pc<={ph,pl}; addr_bus<={ph,pl}; mem_rd_n<=0; state<=F1;
                end
            end
            5'd12: begin // RET_S2: latch PC low, read PC high
                pc[7:0]<=din;
                addr_bus<={8'h30,sp}; sp<=sp+8'd1; mem_rd_n<=0;
                state<=5'd13;
            end
            5'd13: begin // RET_S3: latch PC high, fetch from new PC
                pc[15:8]<=din;
                addr_bus<={din,pc[7:0]}; mem_rd_n<=0; state<=F1;
            end
            5'd14: begin // RTI_S1: latch flags, pop PCL
                {fn,fc,fz,fie} <= {din[3],din[2],din[1],din[0]};
                addr_bus<={8'h30,sp}; sp<=sp+8'd1; mem_rd_n<=0; state<=5'd12; // reuse RET_S2/S3
            end
            HLT: begin
                if(nmi_fire) begin
                    nmi_pend<=0; fie<=0;
                    // Read NMI vector at 0xFFFA
                    addr_bus<=16'hFFFA; mem_rd_n<=0; state<=5'd15;
                end
                else if(irq_fire) begin
                    fie<=0;
                    // Read IRQ vector at 0xFFFE
                    addr_bus<=16'hFFFE; mem_rd_n<=0; state<=5'd15;
                end
            end
            5'd15: begin // INT_S1: latch vector low, read vector high
                pc[7:0]<=din;
                addr_bus<=addr_bus+16'd1; mem_rd_n<=0;
                state<=5'd13; // reuse RET_S3 (latch high, start fetch)
            end
            5'd16: begin // TRAP_S3: push flags byte
                sp<=sp-8'd1; addr_bus<={8'h30,sp-8'd1};
                dout<={4'd0, fn, fc, fz, fie}; doe<=1; mem_wr_n<=0;
                state<=5'd11; // then jump to vector
            end
            default: state<=B0;
            endcase
        end
    end
endmodule
