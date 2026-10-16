// MiSTer SNAC7 standard SNES pad port-1 connection.
// Pin mapping checked against MiSTer-devel/SNES_MiSTer/SNES.sv (2026).
// This is an integration helper; it does NOT configure JTFRAME OSD mux.
// SPDX-License-Identifier: MIT
module joy_snes_snac7 #(
    parameter integer CLK_HZ = 50000000,
    parameter integer POLL_HZ = 1000
)(
    input  wire        clk,
    input  wire [6:0]  USER_IN,
    output wire [6:0]  USER_OUT,
    output wire [15:0] joystick1,
    output wire [15:0] joystick2
);
    wire pad_clock, pad_latch;
    joy_snes #(.CLK_HZ(CLK_HZ), .POLL_HZ(POLL_HZ)) reader (
        .clk(clk), .JOY_CLK(pad_clock), .JOY_LOAD(pad_latch),
        .JOY_DATA(USER_IN[5]), .joystick1(joystick1), .joystick2(joystick2)
    );

    // Standard SNES SNAC7 port 1: D+ LATCH, D- CLOCK, RX- DATA.
    // Other USER_OUT lines are idle high, as in official SNES core.
    assign USER_OUT[0] = pad_latch;
    assign USER_OUT[1] = pad_clock;
    assign USER_OUT[2] = 1'b1;
    assign USER_OUT[3] = 1'b1;
    assign USER_OUT[4] = 1'b1;
    assign USER_OUT[5] = 1'b1;
    assign USER_OUT[6] = 1'b1;
endmodule
