`timescale 1ns/1ps
module tb_joy_md3;
  reg clk=0; always #10 clk=~clk; // 50 MHz
  reg reset=1, enable=1;
  reg up=0, down=0, left=0, right=0, a=0, b=0, c=0, start=0;
  wire th;
  wire [15:0] j1,j2;
  wire valid;
  wire md_up = ~up, md_down = ~down;
  wire md_left = th ? ~left : 1'b0;
  wire md_right = th ? ~right : 1'b0;
  wire md_tl = th ? ~b : ~a;
  wire md_tr = th ? ~c : ~start;
  joy_md3 dut(.clk(clk), .reset(reset), .enable(enable), .MD_UP(md_up),
    .MD_DOWN(md_down), .MD_LEFT(md_left), .MD_RIGHT(md_right),
    .MD_TL(md_tl), .MD_TR(md_tr), .MD_TH(th), .joystick1(j1),
    .joystick2(j2), .valid(valid));
  task expect;
    input [15:0] wanted;
    begin
      @(posedge valid); #1;
      if(j1 !== wanted || j2 !== 0) begin
        $display("FAIL expected %04x got %04x (p2 %04x)", wanted,j1,j2);
        $fatal(1);
      end
    end
  endtask
  initial begin
    #80; reset=0;
    expect(16'h0000);
    a=1; b=1; c=1; start=1; left=1; up=1;
    expect(16'h047a); // start(10)+C(6)+B(5)+A(4)+Up(3)+Left(1)
    a=0; b=0; c=0; start=0; left=0; up=0; down=1; right=1;
    expect(16'h0005); // Down(2) + Right(0)
    $display("PASS joy_md3"); $finish;
  end
  initial begin #10000000; $display("TIMEOUT"); $fatal(1); end
endmodule
