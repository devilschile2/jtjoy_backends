// Mega Drive / Genesis 3-button controller reader for JTFRAME experiments.
// Clean-room implementation based on public controller protocol documentation.
// Active-low physical inputs; active-high joystick outputs (like joy_db15).
module joy_md3 #(
    parameter integer CLK_HZ  = 50000000,
    parameter integer POLL_HZ = 1000,
    parameter integer SETTLE_US = 20
)(
    input wire clk,
    input wire reset,
    input wire enable,
    // MD DE-9 signals after safe voltage level adaptation:
    input wire MD_UP,       // DE-9 pin 1
    input wire MD_DOWN,     // DE-9 pin 2
    input wire MD_LEFT,     // DE-9 pin 3
    input wire MD_RIGHT,    // DE-9 pin 4
    input wire MD_TL,       // DE-9 pin 6: B(TH=1) / A(TH=0)
    input wire MD_TR,       // DE-9 pin 9: C(TH=1) / START(TH=0)
    output reg MD_TH,       // DE-9 pin 7: select, active LOW
    output reg [15:0] joystick1,
    output wire [15:0] joystick2,
    output reg valid
);
    localparam integer SETTLE_CYCLES = ((CLK_HZ / 1000000) * SETTLE_US > 1) ?
                                        (CLK_HZ / 1000000) * SETTLE_US : 2;
    localparam integer PERIOD_CYCLES = (CLK_HZ / POLL_HZ > 2*SETTLE_CYCLES+2) ?
                                       CLK_HZ / POLL_HZ : 2*SETTLE_CYCLES+3;
    localparam integer IDLE_CYCLES = PERIOD_CYCLES - 2*SETTLE_CYCLES;
    localparam [1:0] HIGH_PHASE=2'd0, LOW_PHASE=2'd1, IDLE_PHASE=2'd2;
    reg [1:0] state = HIGH_PHASE;
    reg [31:0] timer = 0;
    reg [15:0] sampled_hi = 0;
    // Synchronize physical inputs into clk domain.
    wire [5:0] md_pins = {MD_TR,MD_TL,MD_RIGHT,MD_LEFT,MD_DOWN,MD_UP};
    reg [5:0] sync1 = 6'b111111, sync2 = 6'b111111;
    always @(posedge clk) begin
        sync1 <= md_pins;
        sync2 <= sync1;
    end
    assign joystick2 = 16'b0;
    // Bit layout matched to joy_db15: [0] Right, [1] Left, [2] Down,
    // [3] Up, [4] A, [5] B, [6] C, [10] Start. All pressed = 1.
    always @(posedge clk) begin
        if (reset || !enable) begin
            MD_TH <= 1'b1;
            state <= HIGH_PHASE;
            timer <= 0;
            joystick1 <= 16'b0;
            sampled_hi <= 16'b0;
            valid <= 1'b0;
        end else begin
            valid <= 1'b0;
            case (state)
                HIGH_PHASE: begin
                    MD_TH <= 1'b1;
                    if (timer == SETTLE_CYCLES-1) begin
                        sampled_hi <= {9'b0, ~sync2[5], ~sync2[4], 1'b0,
                                       ~sync2[0], ~sync2[1], ~sync2[2], ~sync2[3]};
                        // sampled_hi[6]=C, [5]=B, [3]=Up, [2]=Down, [1]=Left, [0]=Right
                        MD_TH <= 1'b0;
                        timer <= 0;
                        state <= LOW_PHASE;
                    end else timer <= timer+1'b1;
                end
                LOW_PHASE: begin
                    if (timer == SETTLE_CYCLES-1) begin
                        joystick1 <= sampled_hi;
                        joystick1[10] <= ~sync2[5]; // START via TR
                        joystick1[4] <= ~sync2[4];  // A via TL
                        MD_TH <= 1'b1;
                        timer <= 0;
                        state <= IDLE_PHASE;
                        valid <= 1'b1;
                    end else timer <= timer+1'b1;
                end
                default: begin
                    if (timer == IDLE_CYCLES-1) begin
                        timer <= 0;
                        state <= HIGH_PHASE;
                    end else timer <= timer+1'b1;
                end
            endcase
        end
    end
endmodule
