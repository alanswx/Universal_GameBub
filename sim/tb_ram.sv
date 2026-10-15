`timescale 1ns/1ps
module tb_ram;
 reg clk=0;always #5 clk=~clk;
 reg [3:0] aa=0,ab=0;reg [15:0] da=0,db=0;reg wa=0,wb=0;reg [1:0] bea=3,beb=3;
 wire [15:0] qa,qb,ra,rb;
 dpram_dc #(.widthad_a(4),.width_a(16)) ram(.clock_a(clk),.clock_b(clk),.address_a(aa),.address_b(ab),.data_a(da),.data_b(db),.wren_a(wa),.wren_b(wb),.byteena_a(bea),.byteena_b(beb),.q_a(qa),.q_b(qb));
 dpram_dc #(.widthad_a(4),.width_a(16),.outdata_reg_a("CLOCK0")) registered_ram(.clock_a(clk),.clock_b(clk),.address_a(aa),.address_b(ab),.data_a(da),.data_b(db),.wren_a(wa),.wren_b(wb),.byteena_a(bea),.byteena_b(beb),.q_a(ra),.q_b(rb));
 task automatic tick;@(posedge clk);#1;endtask
 initial begin
  tick();if(qa!==0 || qb!==0)$fatal(1,"initial zero");
  @(negedge clk);aa=3;da=16'h1234;wa=1;ab=4;db=16'h5678;wb=1;
  tick();if(qa!==16'h1234||qb!==16'h5678||ra!==0||rb!==0)$fatal(1,"write-first / optional latency");
  @(negedge clk);wa=0;wb=0;aa=4;ab=3;
  tick();if(qa!==16'h5678||qb!==16'h1234||ra!==16'h1234||rb!==16'h5678)$fatal(1,"cross-port reads");
  @(negedge clk);wa=1;da=16'habcd;bea=1;wb=1;db=16'hffff;beb=2;
  tick();if(qa!==16'h56cd||qb!==16'hff34)$fatal(1,"byte lanes");
  @(negedge clk);wa=0;wb=0;aa=3;ab=4;
  tick();if(qa!==16'hff34||qb!==16'h56cd)$fatal(1,"retention");
  $display("RAM PASS: zero init, both ports, synchronous reads, write-first, byte enables, extra register");$finish;
 end
endmodule
