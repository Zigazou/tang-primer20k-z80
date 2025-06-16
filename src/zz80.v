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

localparam
    INACTIVE         = 1'b0,
    ACTIVE           = 1'b1,
    INACTIVE_N       = 1'b1,
    ACTIVE_N         = 1'b0,
    LED_PORT_ADDRESS = 8'h10,
    UART_DATA        = 8'h11,
    UART_STATE       = 8'h12;

// ============================================================================
// Clocks
// ============================================================================
wire z80_clk;
Gowin_rPLL clk_6mhz (
    .clkin (CLK_G),   // 27 MHz clock
    .clkout (z80_clk) // 6 MHz clock
);

wire usb_clk;
Gowin_rPLL120 clk_120mhz (
    .clkin (CLK_G),   // 27 MHz clock
    .clkout (usb_clk) // 120 MHz clock
);

// ============================================================================
// Small computer 
// ============================================================================
wire [15:0] bus_address;
wire [7:0]  ram_to_bus;
wire [7:0]  bus_to_ram;
wire [7:0]  data;
wire [7:0]  to_z80;
reg interrupt_request_n;

/*
ram1 z80_ram (
    .dout (ram_to_bus),
    .wre (ram_write_enable),
    .ad (bus_address[9:0]),
    .di (bus_to_ram),
    .clk (z80_clk)
);
*/

wire z80_memory_request;
wire system_reset;
wire ram_write_enable;
ram2 z80_ram (
    .dout  (ram_to_bus),
    .clk   (z80_clk),
    .oce   (z80_memory_request),
    .ce    (~system_reset),
    .reset (system_reset),
    .wre   (ram_write_enable),
    .ad    (bus_address[9:0]),
    .din   (bus_to_ram)
);

reg nWAIT;
reg [1:0] wait_state;
localparam
    WAIT_STATE_IDLE    = 3'd0,
    WAIT_STATE_READ    = 3'd1,
    WAIT_STATE_WRITE   = 3'd2,
    WAIT_STATE_RELEASE = 3'd3;

always @(posedge z80_clk)
    if (system_reset) begin
        wait_state <= WAIT_STATE_IDLE;
        nWAIT <= INACTIVE_N;
    end else begin
        case (wait_state)
            WAIT_STATE_IDLE:
                if (z80_memory_request) begin
                    if (z80_read_request) begin
                        nWAIT      <= ACTIVE_N;
                        wait_state <= WAIT_STATE_READ;
                    end else if (z80_write_request) begin
                        nWAIT      <= ACTIVE_N;
                        wait_state <= WAIT_STATE_WRITE;
                    end else begin
                        nWAIT      <= INACTIVE_N;
                        wait_state <= WAIT_STATE_IDLE;
                    end
                end else begin
                    nWAIT      <= INACTIVE_N;
                    wait_state <= WAIT_STATE_IDLE;
                end
                
            WAIT_STATE_READ: begin
                nWAIT      <= ACTIVE_N;
                wait_state <= WAIT_STATE_RELEASE;
            end

            WAIT_STATE_WRITE: begin
                nWAIT      <= ACTIVE_N;
                wait_state <= WAIT_STATE_RELEASE;
            end

            WAIT_STATE_RELEASE: begin
                nWAIT <= INACTIVE_N;
                if (z80_memory_request)
                    wait_state <= WAIT_STATE_RELEASE;
                else
                    wait_state <= WAIT_STATE_IDLE;
            end
        endcase
    end

wire nM1;
wire nMREQ;
wire nIORQ;
wire nRD;
wire nWR;
wire nREFRESH;
wire nHALT;
wire nBUSAK;
tv80s z80 (
    .m1_n    (nM1),
    .mreq_n  (nMREQ),
    .iorq_n  (nIORQ),
    .rd_n    (nRD),
    .wr_n    (nWR),
    .rfsh_n  (nREFRESH),
    .halt_n  (nHALT),
    .busak_n (nBUSAK),
    .A       (bus_address),
    .dout    (bus_to_ram),
    .write   (),
    .reset_n (RST_N),
    .clk     (z80_clk),
    .wait_n  (nWAIT),
    .int_n   (interrupt_request_n),
    .nmi_n   (NEXT_N),
    .busrq_n (INACTIVE_N),
    .di      (to_z80),
    .cen     (ACTIVE)
);

// Z80 signals.
wire z80_io_request;
wire z80_interrupt_acknowledge;
wire z80_read_request;
wire z80_write_request;
assign system_reset              = RST_N == ACTIVE_N;
assign z80_io_request            = nIORQ == ACTIVE_N;
assign z80_interrupt_acknowledge = (nM1 == ACTIVE_N) && (nIORQ == ACTIVE_N);
assign z80_memory_request        = nMREQ == ACTIVE_N;
assign z80_read_request          = nRD   == ACTIVE_N;
assign z80_write_request         = nWR   == ACTIVE_N;

// RAM access signals.
wire ram_read_enable;
wire ram_enable;
assign ram_write_enable = z80_memory_request && z80_write_request;
assign ram_read_enable  = z80_memory_request && z80_read_request;
assign ram_enable       = z80_memory_request;

always @(posedge z80_clk) begin
    if (system_reset) begin
        state_leds_n <= { INACTIVE_N, INACTIVE_N, INACTIVE_N, INACTIVE_N };
    end else begin
        if (z80_io_request && z80_write_request) begin
            if (bus_address[7:0] == LED_PORT_ADDRESS) begin
                state_leds_n <= { ~bus_to_ram[3], ~bus_to_ram[2], ~bus_to_ram[1], ~bus_to_ram[0]};
            end
        end
    end
end

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

reg [7:0] bus_to_usb;
wire [7:0] usb_to_bus;

wire transmit_available;
wire receive_available;

reg transmit_enable;
reg receive_enable;

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

wire uart_io_read;
assign uart_io_read = z80_io_request
                   && z80_read_request
                   && bus_address[7:0] == UART_DATA;

wire uart_io_write;
assign uart_io_write = z80_io_request
                    && z80_write_request
                    && bus_address[7:0] == UART_DATA;

wire uart_state;
assign uart_state = z80_io_request
                 && z80_read_request
                 && bus_address[7:0] == UART_STATE;

reg usb_sending;
always @(posedge usb_clk or posedge system_reset) begin
    if (system_reset) begin
        transmit_enable <= INACTIVE;
        receive_enable <= INACTIVE;
        usb_sending <= INACTIVE;
    end else begin
        if (usb_sending) begin
            transmit_enable <= INACTIVE;
            usb_sending <= uart_io_write;
        end else begin
            if (uart_io_write) begin
                transmit_enable <= ACTIVE;
                usb_sending <= ACTIVE;
                bus_to_usb <= bus_to_ram;
            end else begin
                usb_sending <= INACTIVE;
                if (uart_io_read) begin
                    receive_enable <= ACTIVE;
                end else begin
                    transmit_enable <= INACTIVE;
                    receive_enable <= INACTIVE;
                end
            end
        end
    end
end

// ============================================================================
// Bus multiplexer
// ============================================================================
assign to_z80 =
    z80_interrupt_acknowledge ? 8'hFF :
    uart_io_read ? usb_to_bus :
    uart_state ? { 7'b0, receive_available } :
    ram_to_bus;

endmodule