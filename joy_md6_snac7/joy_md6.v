// Sega Mega Drive / Genesis six-button pad reader for JTFRAME experiments.
// Seven signals: TH (output), U/D/L/R/TL/TR (inputs). Physical data active-low.
// Reuses joy_db15's ACTIVE-HIGH logical joystick bit layout.
// This module needs SNAC7 pin allocation and proper voltage-level handling upstream.
module joy_md6 #(
    parameter integer CLK_HZ = 50000000,
    parameter integer POLL_HZ = 200,
    parameter integer SETTLE_US = 20,
    parameter integer RESET_US = 3000
)(
    input wire clk,
    input wire reset,
    input wire enable,
    input wire MD_UP,    // DE9 pin 1 / D0
    input wire MD_DOWN,  // DE9 pin 2 / D1
    input wire MD_LEFT,  // DE9 pin 3 / D2
    input wire MD_RIGHT, // DE9 pin 4 / D3
    input wire MD_TL,    // DE9 pin 6 / D4
    input wire MD_TR,    // DE9 pin 9 / D5
    output reg MD_TH,    // DE9 pin 7 / SELECT
    output reg [15:0] joystick1,
    output wire [15:0] joystick2,
    output reg detected_6button,
    output reg valid
);
    // 7 samples H,L,H,L,H,L,H; sample #5 identifies six-button pad,
    // sample #6 carries Z/Y/X/MODE on D0/D1/D2/D3.
    localparam integer TICKS_US = (CLK_HZ + 999999) / 1000000;
    localparam integer SETTLE_TICKS = (TICKS_US * SETTLE_US < 2) ? 2 : TICKS_US * SETTLE_US;
    localparam integer RESET_TICKS = TICKS_US * RESET_US;
    localparam integer PERIOD_TICKS = CLK_HZ / POLL_HZ;
    localparam integer ACTIVE_TICKS = 7 * SETTLE_TICKS;
    localparam integer IDLE_TICKS = (PERIOD_TICKS > ACTIVE_TICKS + RESET_TICKS) ?
                                   PERIOD_TICKS - ACTIVE_TICKS : RESET_TICKS;
    localparam [1:0] ST_WAIT=2'd0, ST_READ=2'd1;
    reg [1:0] state;
    reg [31:0] timer;
    reg [2:0] phase;
    reg [15:0] buttons_tmp;
    reg six_tmp;
    wire [5:0] physical = {MD_TR, MD_TL, MD_RIGHT, MD_LEFT, MD_DOWN, MD_UP};
    reg [5:0] meta, pins;
    assign joystick2 = 16'd0;

    // Synchronize data lines after external level conversion.
    always @(posedge clk) begin
        meta <= physical;
        pins <= meta;
    end

    always @(posedge clk) begin
        if (reset || !enable) begin
            MD_TH <= 1'b1;
            joystick1 <= 16'd0;
            detected_6button <= 1'b0;
            valid <= 1'b0;
            buttons_tmp <= 16'd0;
            six_tmp <= 1'b0;
            phase <= 3'd0;
            timer <= 32'd0;
            state <= ST_WAIT;
        end else begin
            valid <= 1'b0;
            case(state)
                ST_WAIT: begin
                    MD_TH <= 1'b1;
                    if (timer == IDLE_TICKS - 1) begin
                        timer <= 0;
                        phase <= 0;
                        buttons_tmp <= 0;
                        six_tmp <= 0;
                        state <= ST_READ;
                    end else timer <= timer + 1'b1;
                end
                ST_READ: begin
                    MD_TH <= ~phase[0];
                    if (timer == SETTLE_TICKS - 1) begin
                        timer <= 0;
                        case (phase)
                            3'd0: begin
                                // TH=1: {C,B,Right,Left,Down,Up}
                                buttons_tmp[0] <= ~pins[3];
                                buttons_tmp[1] <= ~pins[2];
                                buttons_tmp[2] <= ~pins[1];
                                buttons_tmp[3] <= ~pins[0];
                                buttons_tmp[5] <= ~pins[4];
                                buttons_tmp[6] <= ~pins[5];
                            end
                            3'd1: begin
                                // TH=0: Start/A
                                buttons_tmp[4] <= ~pins[4];
                                buttons_tmp[10] <= ~pins[5];
                            end
                            3'd5: begin
                                // Third low phase has all D0..D3 low only on 6-button pads.
                                six_tmp <= (pins[3:0] == 4'b0000);
                            end
                            3'd6: begin
                                // Third/fourth high phase presents Z/Y/X/Mode as D0..D3.
                                // Map arcade D/E/F to X/Y/Z, MODE to Select.
                                if (six_tmp) begin
                                    buttons_tmp[7] <= ~pins[2]; // X
                                    buttons_tmp[8] <= ~pins[1]; // Y
                                    buttons_tmp[9] <= ~pins[0]; // Z
                                    buttons_tmp[11] <= ~pins[3]; // MODE
                                end
                            end
                            default: ;
                        endcase
                        if (phase == 3'd6) begin
                            joystick1 <= buttons_tmp;
                            // Nonblocking staging: phase-6 values override simultaneously.
                            if (six_tmp) begin
                                joystick1[7] <= ~pins[2];
                                joystick1[8] <= ~pins[1];
                                joystick1[9] <= ~pins[0];
                                joystick1[11] <= ~pins[3];
                            end
                            detected_6button <= six_tmp;
                            valid <= 1'b1;
                            MD_TH <= 1'b1;
                            phase <= 0;
                            state <= ST_WAIT;
                        end else phase <= phase + 1'b1;
                    end else timer <= timer + 1'b1;
                end
                default: state <= ST_WAIT;
            endcase
        end
    end
endmodule
