`timescale 1ns/1ps
module tb_inputs;
 import universal_catalog::*;
 reg clk=0;always #5 clk=~clk;
 reg reset=1,focus=1,vb=0;
 reg [7:0] id=0;
 reg [1:0] grip=0;
 reg up=0,down=0,left=0,right=0,a=0,b=0,x=0,y=0,start=0,coin=0,l=0,r=0;
 wire [7:0] ports[0:5];
 gb_universal_inputs dut(.clk(clk),.reset(reset),.focus(focus),.vblank(vb),.game_id(id),.portrait_mode(grip),
 .up(up),.down(down),.left(left),.right(right),.a(a),.b(b),.x(x),.y(y),.start(start),.select_button(coin),.l(l),.r(r),.ports(ports));
 task automatic tick;@(posedge clk);#1;endtask
 task automatic frame;vb=1;tick();vb=0;tick();endtask
 reg [7:0] selector,expected;reg [63:0] dips;integer soccer=-1,impulse=-1;
 initial begin
  for(integer g=0;g<GAME_COUNT;g=g+1)begin
   @(negedge clk);id=8'(g);reset=1;tick();reset=0;tick();
   dips=game_dips(id);
   for(integer p=0;p<6;p=p+1)begin
    selector=config_byte(id,10+p);
    expected=selector[7]?config_byte(id,4+p):8'(dips>>(selector[2:0]*8));
    if(ports[p]!==expected)$fatal(1,"idle/DIP game %0d port%0d",g,p);
   end
   if(config_byte(id,0)==9)soccer=g;
   if(config_byte(id,1)&4)impulse=g;
  end
  if(soccer<0 || impulse<0)$fatal;
  id=8'(soccer);reset=1;tick();reset=0;start=1;r=1;tick();
  if(dut.ctl[19] || !dut.ctl[20])$fatal(1,"Soccer exclusive P2 start");
  start=0;a=1;b=1;x=1;y=1;l=1;tick();
  if(dut.ctl[41:38]!=4'hf || !dut.ctl[5] || !dut.ctl[6])$fatal(1,"Soccer twin-stick/fire");
  a=0;b=0;x=0;y=0;l=0;r=0;
  id=8'(impulse);reset=1;tick();reset=0;coin=1;tick();coin=0;tick();
  frame();if(!dut.coin)$fatal(1,"impulse frame1");
  frame();if(!dut.coin)$fatal(1,"impulse frame2");
  frame();if(dut.coin)$fatal(1,"impulse exceeded two frames");
  focus=0;up=1;a=1;start=1;tick();tick();if(dut.ctl[19:1]!=0)$fatal(1,"menu inputs leak");
  $display("INPUT PASS: all %0d config/DIP defaults, Soccer twin-stick/P2 start, two-frame coins, focus",GAME_COUNT);$finish;
 end
endmodule
