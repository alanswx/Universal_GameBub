`timescale 1ns/1ps
module gb_clocks(input wire clk_in_50mhz,output reg clk_sys=0,
 output reg clk_spi=0,output reg clk_display=0,output reg locked=0);
 always #25.4375 clk_sys=~clk_sys;
 // SPI/display outputs are unused by the board-level test.

 initial #500 locked=1;
endmodule
