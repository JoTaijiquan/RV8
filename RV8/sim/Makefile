# RV8 Lab Simulations — requires Icarus Verilog
# Install: sudo apt install iverilog gtkwave

all: lab1 lab2 lab3 lab4 lab5 lab6 lab7 lab8

lab1: lab1_clock_tb.v
	iverilog -o $@ $< && vvp $@

lab2: lab2_pc_tb.v
	iverilog -o $@ $< && vvp $@

lab3: lab3_rom_tb.v
	iverilog -o $@ $< && vvp $@

lab4: lab4_ir_tb.v
	iverilog -o $@ $< && vvp $@

lab5: lab5_alu_tb.v
	iverilog -o $@ $< && vvp $@

lab6: lab6_regs_tb.v
	iverilog -o $@ $< && vvp $@

lab7: lab7_pointer_tb.v
	iverilog -o $@ $< && vvp $@

lab8: lab8_cpu_tb.v ../rv8_cpu.v
	iverilog -o $@ $^ && vvp $@

wave%: lab%
	gtkwave $<.vcd &

clean:
	rm -f lab[1-8] *.vcd

.PHONY: all clean
