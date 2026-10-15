// Capture one native line, emit a centered 256-pixel line at system rate.
// Two small line banks preserve every source pixel and add 8-pixel borders
// to the 240-wide families. All supported boards have 192 visible rows.
module gb_universal_video(
 input wire clk,reset,ce,
 input wire [7:0] red,green,blue,
 input wire hb,vb,
 input wire wide,
 output reg [2:0] out_r,out_g,out_b,
 output reg de,out_hb,out_vb
);
 (* ram_style="block" *) reg [8:0] pixels[0:511];
 reg bank,read_bank,hb_q,synced,line_seen,read_wide;
 reg [8:0] x,ox;
 reg active,valid_q,black_q,last_q,blank_q;
 reg [8:0] pixel;
 wire black=!read_wide&&(ox<8||ox>=248);
 wire [7:0] sx=read_wide?ox[7:0]:8'(ox-8);
 always @(posedge clk)begin
  pixel<=pixels[{read_bank,sx}];
  de<=valid_q;out_hb<=blank_q;blank_q<=last_q;
  {out_r,out_g,out_b}<=black_q?9'd0:pixel;
  valid_q<=active;black_q<=black;last_q<=active&&ox==255;
  if(active)begin if(ox==255)active<=0;else ox<=ox+1'b1;end
  if(reset)begin
   bank<=0;read_bank<=0;hb_q<=1;synced<=0;line_seen<=0;x<=0;ox<=0;
   active<=0;valid_q<=0;black_q<=1;last_q<=0;blank_q<=0;read_wide<=0;
   de<=0;out_hb<=1;out_vb<=1;
  end else if(ce)begin
   hb_q<=hb;
   if(vb)begin
    x<=0;line_seen<=0;synced<=1;
    if(!active&&!valid_q&&!last_q)out_vb<=1;
   end else if(hb)begin
    x<=0;
    if(!hb_q&&line_seen)begin
     line_seen<=0;read_bank<=bank;bank<=!bank;
     ox<=0;active<=1;read_wide<=wide;out_vb<=0;
    end
   end else if(synced)begin
    line_seen<=1;x<=x+1'b1;
    if(x<256)pixels[{bank,x[7:0]}]<={red[7:5],green[7:5],blue[7:5]};
   end
  end
 end
endmodule
