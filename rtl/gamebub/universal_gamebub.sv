// Universal Lady Bug baseline for Game Bub rev 4.
module universal_gamebub (
	input  wire         clock,
	input  wire         reset,
	input  wire         clocks_clockIn50M,
	output logic        clocks_clockOutSystem,
	output logic        clocks_clockOutDisplay,
	output logic        clocks_clockOutSpi,
	output logic        clocks_locked,
	output logic [1:0]  videoTransform_rotation,
	output logic [2:0]  video_data_r,
	output logic [2:0]  video_data_g,
	output logic [2:0]  video_data_b,
	output logic        video_dataEnable,
	output logic        video_vblank,
	output logic        video_hblank,
	output logic [15:0] audio_left,
	output logic [15:0] audio_right,
	input  wire         host_mem_enable,
	input  wire         host_mem_write,
	output logic        host_mem_done,
	input  wire  [31:0] host_mem_address,
	output logic [31:0] host_mem_dataRead,
	input  wire  [31:0] host_mem_dataWrite,
	input  wire         host_commandHost_request,
	output logic        host_commandHost_busy,
	output logic        host_commandHost_done,
	output logic        host_commandHost_error,
	output logic        host_commandCore_request,
	input  wire         host_commandCore_busy,
	input  wire         host_commandCore_done,
	input  wire         host_commandCore_error,
	input  wire         input_buttons_a,
	input  wire         input_buttons_b,
	input  wire         input_buttons_x,
	input  wire         input_buttons_y,
	input  wire         input_buttons_up,
	input  wire         input_buttons_down,
	input  wire         input_buttons_left,
	input  wire         input_buttons_right,
	input  wire         input_buttons_l,
	input  wire         input_buttons_r,
	input  wire         input_buttons_start,
	input  wire         input_buttons_select
);
    import universal_catalog::*;
    wire clk;
    gb_clocks clocks(.clk_in_50mhz(clocks_clockIn50M),.clk_sys(clk),
        .clk_spi(clocks_clockOutSpi),.clk_display(clocks_clockOutDisplay),.locked(clocks_locked));
    assign clocks_clockOutSystem=clk;
    assign host_commandCore_request=0;
    wire core_reset,act_reset,focus,wr_req;
    wire [18:0] wr_addr;
    wire [7:0] wr_data;
    wire [1:0] portrait_mode,volume;
    wire [7:0] game_id;
    wire [7:0] flags=config_byte(game_id,1);
    wire [1:0] upright_rotation=flags[7]?2'd1:2'd3;
    wire [31:0] debug_status;
    wire platform_reset=reset || !clocks_locked;
    gb_universal_host host(.clk(clk),.reset(platform_reset),
        .mem_enable(host_mem_enable),.mem_write(host_mem_write),
        .mem_address(host_mem_address),.mem_dataWrite(host_mem_dataWrite),
        .mem_dataRead(host_mem_dataRead),.mem_done(host_mem_done),
        .cmd_request(host_commandHost_request),.cmd_busy(host_commandHost_busy),
        .cmd_done(host_commandHost_done),.cmd_error(host_commandHost_error),
        .wr_req(wr_req),.wr_addr(wr_addr),.wr_data(wr_data),
        .core_reset(core_reset),.act_reset(act_reset),.focus(focus),
        .game_id(game_id),.portrait_mode(portrait_mode),.volume(volume),.debug_status(debug_status));
    // MRA flags bit7 clear is ROT270: 270 degrees clockwise / CCW.
    assign videoTransform_rotation=!flags[4]?2'd0:portrait_mode==1?upright_rotation-2'd1:portrait_mode==2?upright_rotation+2'd1:upright_rotation;
    wire machine_reset=platform_reset || core_reset || act_reset;
    wire [7:0] ports[0:5];
    gb_universal_inputs inputs(.clk(clk),.reset(machine_reset),.focus(focus),
        .game_id(game_id),.vblank(vb),.portrait_mode(portrait_mode),.up(input_buttons_up),.down(input_buttons_down),
        .left(input_buttons_left),.right(input_buttons_right),.a(input_buttons_a),
        .b(input_buttons_b),.x(input_buttons_x),.y(input_buttons_y),
        .start(input_buttons_start),.select_button(input_buttons_select),.l(input_buttons_l),.r(input_buttons_r),.ports(ports));
    wire [7:0] red,green,blue;
    wire ce,hb,vb;
    wire signed [15:0] sample;
    universal_board machine(
        .clk(clk),.reset(machine_reset),.pause(!focus),
        .variant(config_byte(game_id,0)),.rom_dec(4'(config_byte(game_id,2))),
        .game_flags2(config_byte(game_id,3)),.ce_pix(ce),
        .in0(ports[0]),.in1(ports[1]),.in2(ports[2]),.dsw0(ports[3]),.dsw1(ports[4]),.coin(ports[5]),
        .ioctl_addr({6'd0,wr_addr}),.ioctl_dout(wr_data),.ioctl_wr0(wr_req&&core_reset),
        .crt_flip(1'b0),.h_adj(4'd0),.v_adj(4'd0),
        .video_r(red),.video_g(green),.video_b(blue),.video_hs(),.video_vs(),
        .video_hblank(hb),.video_vblank(vb),.audio(sample),
        .hs_address(16'd0),.hs_data_in(8'd0),.hs_data_out(),.hs_write(1'b0));
    wire [7:0] variant=config_byte(game_id,0);
    gb_universal_video video(.clk(clk),.reset(machine_reset),.ce(ce),
        .red(red),.green(green),.blue(blue),.hb(hb),.vb(vb),.wide(variant>=12),
        .out_r(video_data_r),.out_g(video_data_g),.out_b(video_data_b),
        .de(video_dataEnable),.out_hb(video_hblank),.out_vb(video_vblank));
    wire signed [18:0] amplified=$signed({{3{sample[15]}},sample}) <<< volume;
    always @(posedge clk)begin
        audio_left<=machine_reset || !focus ? 16'd0 : amplified>32767 ? 16'h7fff : amplified< -32768 ? 16'h8000 : amplified[15:0];
        audio_right<=audio_left;
    end
endmodule
