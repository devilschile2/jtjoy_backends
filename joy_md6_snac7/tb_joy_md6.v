`timescale 1ns/1ps
module tb_joy_md6;
  reg clk=0;
  always #10 clk = ~clk; // 50 MHz
  reg reset=1, enable=1;
  reg [11:0] pressed=0;
  reg is_six=1;
  wire th, valid, detected;
  wire [15:0] j1,j2;
  reg [5:0] p;
  wire [5:0] outputs_pad = p;
  joy_md6 #(.CLK_HZ(50000000), .POLL_HZ(200), .SETTLE_US(20), .RESET_US(3000)) dut (
    .clk(clk), .reset(reset), .enable(enable), .MD_UP(outputs_pad[0]),
    .MD_DOWN(outputs_pad[1]), .MD_LEFT(outputs_pad[2]), .MD_RIGHT(outputs_pad[3]),
    .MD_TL(outputs_pad[4]), .MD_TR(outputs_pad[5]), .MD_TH(th),
    .joystick1(j1), .joystick2(j2), .detected_6button(detected), .valid(valid)
  );
  integer phase_counter=0;
  reg prev_th=1;
  integer idle_cycles=0;
  // Model the timed device: count TH transitions, reset after >2 ms idle.
  always @(negedge clk) begin
    if(reset) begin
      phase_counter=0; prev_th=1; idle_cycles=0;
    end else begin
      if(th != prev_th) begin
        phase_counter = phase_counter + 1;
        idle_cycles=0;
      end else if(th) begin
        idle_cycles=idle_cycles+1;
        if(idle_cycles > 100000) phase_counter=0;
      end
      prev_th=th;
    end
  end
  always @* begin
    // button bit order: 0 R,1 L,2 D,3 U,4 A,5 B,6 C,7 X,8 Y,9 Z,10 Start,11 Mode
    if(th) begin
      if(is_six && phase_counter == 6)
        p={~pressed[6],~pressed[5],~pressed[11],~pressed[7],~pressed[8],~pressed[9]};
      else
        p={~pressed[6],~pressed[5],~pressed[0],~pressed[1],~pressed[2],~pressed[3]};
    end else begin
      if(is_six && phase_counter == 5)
        p={~pressed[10],~pressed[4],4'b0000};
      else
        p={~pressed[10],~pressed[4],2'b00,~pressed[2],~pressed[3]};
    end
  end
  task check;
    input [15:0] expected;
    input expected_six;
    begin
      @(posedge valid);
      #1;
      if(j1 !== expected || detected !== expected_six || j2 !== 0) begin
        $display("FAIL got=%h expected=%h six=%b expected=%b",j1,expected,detected,expected_six);
        $fatal(1);
      end
    end
  endtask
  initial begin
    repeat(5) @(posedge clk);
    reset=0;
    // A+B+C+X+Y+Z+Start+Mode+Left+Up => 0x0FF? calculate from bits below
    pressed = (16'h0FFa & 16'h0fff); // separate expected matches actual buttons
    check({4'b0,pressed},1'b1);
    pressed=0;
    check(16'h0000,1'b1);
    is_six=0;
    pressed=12'h473; // right,left,A,B,C,Start etc
    check({4'b0,(pressed & 12'h47f)},1'b0); // mask extra bits (bits 7..9 and 11)
    $display("PASS joy_md6: six-button, released, three-button fallback");
    $finish;
  end
  initial begin #50000000; $display("TIMEOUT"); $fatal(1); end
endmodule
