// Per-game MRA config, polarity, DIP defaults and handheld control mapping.
module gb_universal_inputs(
 input wire clk,reset,focus,vblank,
 input wire [7:0] game_id,
 input wire [1:0] portrait_mode,
 input wire up,down,left,right,a,b,x,y,start,select_button,l,r,
 output reg [7:0] ports[0:5]
);
 import universal_catalog::*;
 wire [7:0] flags=config_byte(game_id,1);
 wire portrait=flags[4];
 wire cw=portrait && portrait_mode==1,ccw=portrait && portrait_mode==2;
 wire [3:0] raw={focus&&(cw?left:ccw?right:up),focus&&(cw?right:ccw?left:down),
                 focus&&(cw?down:ccw?up:left),focus&&(cw?up:ccw?down:right)};
 reg [3:0] previous,mask;
 wire [3:0] newly_pressed=raw & ~previous;
 wire [3:0] direction=flags[0]?(raw&mask):raw;
 reg coin_q,pending,vb_q;
 reg [1:0] coin_frames;
 wire coin_raw=select_button&&focus;
 wire coin=flags[2]?(|coin_frames):coin_raw;
 always @(posedge clk)begin
  if(reset)begin previous<=0;mask<=4'hf;coin_q<=0;pending<=0;coin_frames<=0;vb_q<=1;end
  else begin
   previous<=raw;coin_q<=coin_raw;vb_q<=vblank;
   if(newly_pressed[0])mask<=1;
   if(newly_pressed[1])mask<=2;
   if(newly_pressed[2])mask<=4;
   if(newly_pressed[3])mask<=8;
   if(!(raw&mask) || !flags[0])mask<=4'hf;
   if(coin_raw&&!coin_q)pending<=1;
   if(vblank&&!vb_q)begin
    if(pending)begin coin_frames<=2;pending<=0;end
    else if(coin_frames!=0)coin_frames<=coin_frames-1'b1;
   end
  end
 end
 wire twin=config_byte(game_id,0)==9;
 reg [63:0] ctl;
 reg [7:0] base,selector;
 wire [63:0] dips=game_dips(game_id);
 always @* begin
  ctl=0;
  ctl[1]=direction[3];ctl[2]=direction[2];ctl[3]=direction[1];ctl[4]=direction[0];
  ctl[12:9]=ctl[4:1]; // alternating P2 shares movement
  ctl[5]=a&&focus;ctl[6]=b&&focus;ctl[7]=x&&focus;ctl[8]=y&&focus;
  ctl[16:13]=ctl[8:5];
  ctl[17]=coin;ctl[19]=start&&focus&&(!twin||!r);ctl[20]=r&&focus&&(!twin||start);
  // Indoor Soccer: D-pad left stick, ABXY right stick (A right/B down/X up/Y left).
  // L/R supply its two fire buttons; Start+R starts alternating player 2.
  if(twin)begin
   ctl[5]=l&&focus;ctl[6]=r&&focus&&!start;
   ctl[38]=a&&focus;ctl[39]=y&&focus;ctl[40]=b&&focus;ctl[41]=x&&focus;
   ctl[45:42]=ctl[41:38];ctl[16:13]=ctl[8:5];
  end
  for(integer p=0;p<6;p=p+1)begin
   selector=config_byte(game_id,10+p);
   base=selector[7]?config_byte(game_id,4+p):8'(dips>>(selector[2:0]*8));
   for(integer n=0;n<8;n=n+1)ports[p][n]=base[n]^ctl[config_byte(game_id,16+p*8+n)];
  end
 end
endmodule
