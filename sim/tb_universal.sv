`timescale 1ns/1ps
module tb_universal;
    reg reset=1,clk50=0;

    wire clk;
    reg enable=0,write=0,request=0;
    reg [31:0] addr=0,data=0;
    wire [31:0] read_data;
    wire done,cmd_done,cmd_error;
    reg coin=0,start=0,up=0,down=0,left=0,right=0;
    wire de,hb,vb;
    wire [2:0] red,green,blue;
    wire [1:0] rotation;
    wire [15:0] audio;
    universal_gamebub dut(
        .clock(clk),.reset(reset),.clocks_clockIn50M(clk50),.clocks_clockOutSystem(clk),
        .clocks_clockOutDisplay(),.clocks_clockOutSpi(),.clocks_locked(),
        .videoTransform_rotation(rotation),.video_data_r(red),.video_data_g(green),.video_data_b(blue),
        .video_dataEnable(de),.video_hblank(hb),.video_vblank(vb),.audio_left(audio),.audio_right(),
        .host_mem_enable(enable),.host_mem_write(write),.host_mem_address(addr),.host_mem_dataWrite(data),
        .host_mem_dataRead(read_data),.host_mem_done(done),.host_commandHost_request(request),
        .host_commandHost_busy(),.host_commandHost_done(cmd_done),.host_commandHost_error(cmd_error),
        .host_commandCore_request(),.host_commandCore_busy(1'b0),.host_commandCore_done(1'b0),.host_commandCore_error(1'b0),
        .input_buttons_a(1'b0),.input_buttons_b(1'b0),.input_buttons_x(1'b0),.input_buttons_y(1'b0),
        .input_buttons_up(up),.input_buttons_down(down),.input_buttons_left(left),.input_buttons_right(right),
        .input_buttons_l(1'b0),.input_buttons_r(1'b0),.input_buttons_start(start),.input_buttons_select(coin));
    task automatic transaction(input bit w,input [31:0] a,input [31:0] d);
        @(negedge clk);enable=1;write=w;addr=a;data=d;
        do @(negedge clk);while(!done);
        enable=0;@(negedge clk);
    endtask
    task automatic command(input [15:0] op,input [31:0] arg1,arg2,input bit error_expected=0);
        transaction(1,32'hf0000000,{16'd0,op});
        transaction(1,32'hf0000004,arg1);transaction(1,32'hf0000008,arg2);
        @(negedge clk);request=1;
        do @(negedge clk);while(!cmd_done && !cmd_error);
        if(cmd_error!=error_expected)$fatal(1,"command %h unexpected error=%b",op,cmd_error);
        request=0;repeat(3)@(negedge clk);
    endtask

    import universal_catalog::*;
    reg [7:0] rom[0:GAME_MAX_SIZE-1];
    integer rom_size,expected_id,target_frames=120,fd,n;
    string rom_path,key;
    bit require_audio=0;
    task automatic load_rom(input bit corrupt=0);
        command(16'h0300,0,0);
        for(integer i=0;i<rom_size;i=i+4)
            transaction(1,32'h10000000+i,{rom[i+3],rom[i+2],rom[i+1],rom[i]} ^ ((corrupt&&i==100)?32'd1:32'd0));
        command(16'h0301,0,32'(rom_size),corrupt);
    endtask
    integer frames=0,pixels=0,line_pixels=0,lines=0,nonblack=0,audio_seen=0,cpu_writes=0,fetches=0,total_colored=0;
    reg vbq=1,hbq=1;
    reg [8:0] picture[0:49151];
    reg [15:0] last_pc;
    always @(posedge clk)begin
        vbq<=vb;hbq<=hb;
        if(!dut.core_reset)begin
            if(audio!=0)audio_seen=audio_seen+1;
            if(!dut.machine.zm_from[25])cpu_writes=cpu_writes+1;
            if(!dut.machine.zm_from[29] && dut.machine.zm_from[23:8]!=last_pc)begin
                fetches=fetches+1;last_pc=dut.machine.zm_from[23:8];
            end
        end
        if(de)begin
            if(pixels<49152)picture[pixels]={red,green,blue};
            pixels=pixels+1;line_pixels=line_pixels+1;
            if({red,green,blue}!=0)begin nonblack=nonblack+1;total_colored=total_colored+1;end
        end
        if(hb&&!hbq&&!vb)begin
            if(line_pixels!=256 && frames>2)$fatal(1,"line width %0d",line_pixels);
            if(line_pixels!=0)lines=lines+1;
            line_pixels=0;
        end
        if(vb&&!vbq)begin
            if(frames>2 && !dut.core_reset)begin
                if(pixels!=49152)$fatal(1,"%s: frame pixels=%0d lines=%0d",key,pixels,lines);
                if(frames==target_frames-1 || frames%120==0)begin
                    fd=$fopen($sformatf("%s-frame-%0d.ppm",key,frames),"wb");
                    $fwrite(fd,"P6\n256 192\n255\n");
                    for(integer i=0;i<49152;i=i+1)$fwrite(fd,"%c%c%c",8'(picture[i][8:6]*255/7),8'(picture[i][5:3]*255/7),8'(picture[i][2:0]*255/7));
                    $fclose(fd);
                    $display("%s frame %0d: pixels=%0d lines=%0d colored=%0d PC=%h audio=%0d fetches=%0d",key,frames,pixels,lines,nonblack,dut.machine.zm_from[23:8],audio_seen,fetches);$fflush();
                end
            end
            frames=frames+1;pixels=0;lines=0;line_pixels=0;nonblack=0;
        end
    end
    initial begin #30_000_000_000;$fatal(1,"timeout");end
    initial begin
        if(!$value$plusargs("rom=%s",rom_path)||!$value$plusargs("key=%s",key)||!$value$plusargs("id=%d",expected_id))$fatal(1,"Missing ROM/id/key");
        n=$value$plusargs("frames=%d",target_frames);require_audio=$test$plusargs("require_audio");
        fd=$fopen(rom_path,"rb");if(!fd)$fatal(1,"ROM missing");rom_size=$fread(rom,fd);$fclose(fd);
        $display("Loading %s id %0d size %0d",key,expected_id,rom_size);$fflush();
        repeat(30)@(negedge clk);reset=0;repeat(30)@(negedge clk);
        load_rom(1);if(!dut.core_reset)$fatal(1,"Corrupt image ran");
        load_rom(0);
        if(dut.game_id!=expected_id)$fatal(1,"Wrong selected config: %d",dut.game_id);
        command(16'h0102,0,0);command(16'h0200,1,0);command(16'h0100,0,0);
        if(dut.core_reset)$fatal(1,"Valid image did not run");
        for(integer mode=0;mode<3;mode=mode+1)begin
            transaction(1,32'h210,32'(mode));repeat(4)@(negedge clk);
            if(rotation!=(!dut.flags[4]?0:mode==0?(dut.flags[7]?1:3):mode==1?(dut.flags[7]?0:2):(dut.flags[7]?2:0)))$fatal(1,"Rotation map");
        end
        transaction(1,32'h210,0);
        // Full Lady Bug regression retains the hardware-confirmed startup wait.
        if(target_frames>=360)begin
            wait(frames>=240);coin=1;repeat(1000000)@(negedge clk);coin=0;
            wait(frames>=260);start=1;repeat(1000000)@(negedge clk);start=0;
            wait(frames>=280);right=1;wait(frames>=310);right=0;
        end else begin
            // Coin/start hold is long enough for the 24 ms Lady Bug chute and
            // for the two-frame coin impulse mapper used by Cosmic boards.
            wait(frames>=5);coin=1;repeat(1000000)@(negedge clk);coin=0;
            wait(frames>=10);start=1;repeat(1000000)@(negedge clk);start=0;
        end
        wait(frames>=target_frames);
        if(fetches<10)$fatal(1,"CPU did not fetch instructions");
        if(require_audio && audio_seen==0)$fatal(1,"No audio");
        $display("GAME PASS %s variant=%0d frames=%0d writes=%0d fetches=%0d colored=%0d audio=%0d",key,dut.variant,frames,cpu_writes,fetches,total_colored,audio_seen);$fflush();
        command(16'h0101,0,0);if(!dut.core_reset)$fatal(1,"Halt failed");
        load_rom(0);command(16'h0102,0,0);command(16'h0100,0,0);
        if(dut.core_reset)$fatal(1,"Reload failed");
        $display("UNIVERSAL PASS %s: identity, corrupted image, raster, CPU, grips, halt/reload",key);$finish;
    end
endmodule
