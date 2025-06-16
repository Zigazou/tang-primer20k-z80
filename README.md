# Tang Primer 20K Z80 Example

This repository contains a small Z80 based design for the **Tang Primer 20K** FPGA board. It uses the Gowin toolchain and demonstrates how to run a simple program on a soft Z80 CPU with USB to UART communication.

## Directory overview

- **src** – Verilog sources and support files
  - `zz80.v` – top level for the Z80 computer
  - `ram*.v` – generated single port RAM blocks
  - `usb_wrapper.v` and related IP files
  - `z80-soft` – Z80 assembly example
- **impl** – output of synthesis and place & route
- `zz80.gprj` – Gowin project file

## Building the Z80 program

A simple assembly program is provided under `src/z80-soft`. The `Makefile` builds the Z80 binary, converts it to a RAM initialization file and regenerates the RAM module:

```make
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
```

Before running `make`, adjust `GOWIN_BIN_DIR` to the location of your Gowin tools and ensure `z80asm` is available.

The helper script [`gen_ram_init.bash`](src/z80-soft/gen_ram_init.bash) creates a hex initialization file from the compiled binary:

```bash
#!/bin/bash

# This script generates a RAM initialization file in hex format suitable for use
# with hardware description languages in GoWin environments.
#
# Usage: gen_ram_init.bash <bytes_count>
#
# It reads a specified number of bytes (bytes_count) from standard input and
# outputs them in hex format. If standard input is shorter than the specified
# bytes_count, it pads the output with zeros until the required length is
# reached.
#
# Example:
#
#   cat input_file.bin | gen_ram_init.bash 256 > ram_init.hex

bytes_count="$1"

printf "#File_format=Hex\n"
printf "#Address_depth=%d\n" "$bytes_count"
printf "#Data_width=8\n"

(cat ; dd if=/dev/zero bs=1 count="$bytes_count" status=none) \
    | head --bytes="$bytes_count" \
    | hexdump \
        --no-squeezing \
        --format '1/1 "%02X\n"'
```

## Synthesizing the design

Open `zz80.gprj` in the Gowin IDE and run Synthesis and Place & Route. The resulting bitstream can be found under `impl/pnr/zz80.fs`. Command line builds can also be performed using the provided `cmd.do` script (paths may need adjusting).

## Z80 top-level overview

The main module exposes the board clocks, LED outputs and the ULPI interface used by the USB to UART bridge:

```verilog
module zz80 (
    input wire CLK_G,
    input wire RST_N,
    input wire NEXT_N,

    // Leds
    output reg [3:0] state_leds_n,

    // USB OTG
    output wire       ulpi_rst,
    input  wire       ulpi_clk,
    input  wire       ulpi_dir,
    input  wire       ulpi_nxt,
    output wire       ulpi_stp,
    inout  wire [7:0] ulpi_data
);
```

An interrupt is generated every second using a simple counter:

```verilog
// Generate a maskable interrupt every second.
localparam MAX_COUNT = 23'd5_999_999;
reg [22:0] counter;
always @(posedge z80_clk) begin
    if (system_reset) begin
        counter <= 23'd0;
        interrupt_request_n <= INACTIVE_N;
    end else begin
        if (counter == MAX_COUNT) begin
            counter <= 23'd0;
            interrupt_request_n <= ACTIVE_N;
        end else begin
            counter <= counter + 23'd1;

            if (interrupt_request_n == ACTIVE_N) begin
                // Wait until the Z80 acknowledges the interruption.
                if (z80_interrupt_acknowledge) begin
                    interrupt_request_n <= INACTIVE_N;
                end else begin
                    interrupt_request_n <= ACTIVE_N;
                end
            end else begin
                interrupt_request_n <= INACTIVE_N;
            end
        end
    end
end
```

USB transfers are handled through `usb_wrapper`:

```verilog
usb_wrapper usb(
    .rst_n (RST_N),
    .clk (usb_clk),

    .data_o (usb_to_bus),
    .rdav (receive_available),
    .rden (receive_enable),

    .data_i (bus_to_usb),
    .wrav (transmit_available),
    .wren (transmit_enable),

    .ulpi_rst (ulpi_rst),
    .ulpi_clk (ulpi_clk),
    .ulpi_dir (ulpi_dir),
    .ulpi_nxt (ulpi_nxt),
    .ulpi_stp (ulpi_stp),
    .ulpi_data (ulpi_data)
);
```

## Example software

`set_led.z80` demonstrates a tiny program that rotates the LEDs and echoes characters received over UART:

```asm
; This program sets an LED pattern on a Z80-based system.

bootstrap:              equ 0x0000 ; Address for the bootstrap code
interrupt_handler:      equ 0x0038 ; Address for the interrupt handler
nmi_handler:            equ 0x0066 ; Address for the NMI handler
program_start:          equ 0x0100 ; Start of the program in memory
initial_stack_pointer:  equ 0x0400 ; The stack starts at the end of memory

memory_size:            equ 0x0400 ; 1024 bytes
initial_led_pattern:    equ 0x11 ; Initial LED pattern to display "1010"
led_port:               equ 0x10 ; Port address for the LED
uart_data:              equ 0x11 ; UART data port address
uart_state:             equ 0x12 ; UART state port address

; =============================================================================
; System bootstrap
; =============================================================================
org bootstrap
    ; Initialize the stack pointer, enable interrupts, and jump to the main
    ; program
    ld hl, initial_stack_pointer
    ld sp, hl
    ei
    jp program_start

; =============================================================================
; Interrupt handler
; =============================================================================
seek interrupt_handler
org interrupt_handler
    ex af, af'

    ; Make the LED rotate.
    ld a, (led_pattern)
    rlca
    ld (led_pattern), a
    out (led_port), a

    ex af, af'
    ei
    reti

; =============================================================================
; NMI Handler
; =============================================================================
seek nmi_handler
org nmi_handler
    ex af, af'
    ld a, (led_pattern)
    xor 0xff
    ld (led_pattern), a
    ex af, af'
    retn

; =============================================================================
; Main program
; =============================================================================
seek program_start
org program_start
    ; Initialize the LED pattern.
    ld a, initial_led_pattern
    ld (led_pattern), a

loop:
    in a, (uart_state)
    and 0x01
    jr z, loop

    in a, (uart_data)
    out (uart_data), a

    jr loop

led_pattern: db 0
```

## Timing constraints

The clocks used by the design are defined in `zz80.sdc`:

```tcl
create_clock -name ulpi_clk -period 16.667 -waveform {0 5.75} [get_ports {ulpi_clk}]
create_clock -name CLK_G -period 37.037 -waveform {0 18.518} [get_ports {CLK_G}] -add
set_clock_latency -source 0.4 [get_clocks {ulpi_clk}]
```

## Notes

Some IP blocks used in this project are encrypted files distributed with the Gowin toolchain (for example `usb_to_uart.v`). The open source TV80 core referenced by the synthesis logs is not included in this repository.
