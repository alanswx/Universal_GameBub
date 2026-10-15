// Portable replacement for Universal's Intel altsyncram wrapper.
// Synchronous input address, write-first on the writing port; optional extra
// output register. Independent ports must not write the same address together.
// Mixed-port same-address read/write is intentionally unspecified, as in source.
module dpram_dc #(
    parameter init_file=" ", parameter widthad_a=10, parameter width_a=8,
    parameter outdata_reg_a="UNREGISTERED", parameter outdata_reg_b="UNREGISTERED"
)(
    input wire [widthad_a-1:0] address_a, address_b = '0,
    input wire clock_a, clock_b,
    input wire [width_a-1:0] data_a = '0, data_b = '0,
    input wire wren_a = 1'b0, wren_b = 1'b0,
    input wire [width_a/8-1:0] byteena_a = '1, byteena_b = '1,
    output wire [width_a-1:0] q_a, q_b
);
    // Tiny palette PROMs/line stores waste half a BRAM each. Keep them in
    // LUT RAM so the dual-clock framework menu remains in block RAM.
    localparam RAM_STYLE = widthad_a<=9 ? "distributed" : "block";
    (* ram_style=RAM_STYLE *) reg [width_a-1:0] mem [0:(1<<widthad_a)-1];
    reg [width_a-1:0] a, b, ar, br;
    initial begin
        if (init_file != " ") $fatal(1,"Unsupported RAM initialization file");
        for(integer i=0;i<(1<<widthad_a);i=i+1) mem[i]='0;
    end
    always @(posedge clock_a) begin
        for(integer j=0;j<width_a/8;j=j+1) begin
            if(wren_a && byteena_a[j]) begin
                mem[address_a][j*8+:8] <= data_a[j*8+:8];
                a[j*8+:8] <= data_a[j*8+:8];
            end else a[j*8+:8] <= mem[address_a][j*8+:8];
        end
        ar <= a;
    end
    always @(posedge clock_b) begin
        for(integer j=0;j<width_a/8;j=j+1) begin
            if(wren_b && byteena_b[j]) begin
                mem[address_b][j*8+:8] <= data_b[j*8+:8];
                b[j*8+:8] <= data_b[j*8+:8];
            end else b[j*8+:8] <= mem[address_b][j*8+:8];
        end
        br <= b;
    end
    assign q_a = outdata_reg_a == "UNREGISTERED" ? a : ar;
    // Upstream wired outdata_reg_a to BOTH ports. Preserve actual behavior.
    assign q_b = outdata_reg_a == "UNREGISTERED" ? b : br;
endmodule
