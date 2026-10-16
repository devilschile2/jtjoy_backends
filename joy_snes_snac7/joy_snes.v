// SNES serial gamepad reader with joy_db15-compatible joystick outputs.
// Independent implementation based on the interface of joydb15.v.
// Physical SNAC7 signal assignment and FPGA electrical interface are external.
// SPDX-License-Identifier: MIT
module joy_snes #(
    parameter integer CLK_HZ  = 50000000,
    parameter integer POLL_HZ = 1000
)(
    input  wire        clk,
    output reg         JOY_CLK  = 1'b1,  // SNES clock: idle high
    output reg         JOY_LOAD = 1'b0,  // SNES latch: active high
    input  wire        JOY_DATA,         // SNES serial data: low = pressed
    output reg [15:0]  joystick1 = 16'd0,
    output wire [15:0] joystick2
);
    // Parameterized in system clock cycles. Supports simulation at e.g. 1 MHz.
    localparam integer US_CYCLES = (CLK_HZ + 999999) / 1000000;
    localparam integer LATCH_CYCLES = 12 * US_CYCLES;
    localparam integer HALF_CYCLES  = 6  * US_CYCLES;
    localparam integer PERIOD_CYCLES = (CLK_HZ / POLL_HZ) > 0 ? (CLK_HZ / POLL_HZ) : 1;

    localparam [2:0] IDLE=0, LATCH=1, SETTLE=2, LOW=3, HIGH=4;
    reg [2:0]  state = IDLE;
    reg [31:0] count = 0;
    reg [3:0]  bit_index = 0;
    reg [11:0] pad_bits = 0;
    reg [31:0] since_poll = 0;
    reg data_meta = 1'b1, data_sync = 1'b1;

    // The SNES controller presents B first (after LATCH falls), then changes
    // to the following bit on each rising edge of JOY_CLK. Sample near the
    // end of each low phase, before the rising edge.
    always @(posedge clk) begin
        data_meta <= JOY_DATA;
        data_sync <= data_meta;
        if (since_poll < PERIOD_CYCLES) since_poll <= since_poll + 1'd1;
        case (state)
            IDLE: if (since_poll >= PERIOD_CYCLES) begin
                since_poll <= 0;
                JOY_LOAD <= 1'b1;
                JOY_CLK <= 1'b1;
                count <= 0;
                state <= LATCH;
            end
            LATCH: if (count == LATCH_CYCLES-1) begin
                JOY_LOAD <= 1'b0;
                count <= 0;
                state <= SETTLE;
            end else count <= count + 1'd1;
            SETTLE: if (count == HALF_CYCLES-1) begin
                count <= 0;
                bit_index <= 0;
                JOY_CLK <= 1'b0;
                state <= LOW;
            end else count <= count + 1'd1;
            LOW: if (count == HALF_CYCLES-1) begin
                count <= 0;
                if (bit_index < 12) pad_bits[bit_index] <= ~data_sync;
                JOY_CLK <= 1'b1;
                state <= HIGH;
            end else count <= count + 1'd1;
            HIGH: if (count == HALF_CYCLES-1) begin
                count <= 0;
                if (bit_index == 15) begin
                    // Same bit positions and active-high polarity as joy_db15.
                    // Arcade action mapping: A=B, B=A, C=Y, D=X, E=L, F=R.
                    joystick1 <= {
                        4'b0000, pad_bits[2], pad_bits[3],   // [11:10] Sel,Start
                        pad_bits[11], pad_bits[10],          // [9:8]  F=R,E=L
                        pad_bits[9], pad_bits[1],            // [7:6]  D=X,C=Y
                        pad_bits[8], pad_bits[0],            // [5:4]  B=A,A=B
                        pad_bits[4], pad_bits[5],            // [3:2]  Up,Down
                        pad_bits[6], pad_bits[7]             // [1:0]  Left,Right
                    };
                    state <= IDLE;
                end else begin
                    bit_index <= bit_index + 1'b1;
                    JOY_CLK <= 1'b0;
                    state <= LOW;
                end
            end else count <= count + 1'd1;
            default: state <= IDLE;
        endcase
    end
    assign joystick2 = 16'd0; // Single controller / single serial DATA line
endmodule
