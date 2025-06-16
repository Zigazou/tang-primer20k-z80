# This Makefile is used to compile Z80 assembly code and generate a RAM module
# for Gowin FPGA.
GOWIN_BIN_DIR := /home/fred/bin/Gowin_V1.9.11.02_linux/IDE/bin

# Generate the RAM module.
../ram2.v: ../ram_init.mi ../ram2.mod
	$(GOWIN_BIN_DIR)/GowinModGen -do ../ram2.mod

# Generate the RAM initialization file from the Z80 assembly binary.
../ram_init.mi: set_led.bin
	cat $< | bash gen_ram_init.bash 1024 > $@

# Compile the Z80 assembly code to binary.
set_led.bin: set_led.z80
	z80asm --output=$@ $<

clean:
	rm -f set_led.bin
