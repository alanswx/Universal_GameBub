// HostV0 command and posted-write pattern adapted from MCR/ColecoVision
// Game Bub ports (GPL-3.0-or-later). File bytes are little endian.
module gb_universal_host (
    input wire clk, reset,
    input wire mem_enable, mem_write,
    input wire [31:0] mem_address, mem_dataWrite,
    output reg [31:0] mem_dataRead,
    output reg mem_done,
    input wire cmd_request,
    output wire cmd_busy, cmd_done, cmd_error,
    output reg wr_req,
    output reg [18:0] wr_addr,
    output reg [7:0] wr_data,
    output wire core_reset,
    output reg act_reset, focus,
    output reg [7:0] game_id,
    output reg [1:0] portrait_mode, volume,
    output wire [31:0] debug_status
);
    import universal_catalog::*;
    reg [31:0] command [0:7];
    reg [1:0] command_state;
    reg setup_done, run, present, load_error, loading;
    reg [31:0] crc_state, rom_bytes;
    wire [31:0] rom_crc = ~crc_state;
    reg response_pending;
    wire is_file = mem_address[31:19] == 13'h200;
    wire is_command = mem_address[31:5] == (32'hf0000000 >> 5);
    wire is_local = mem_address[31:12] == 0;
    assign cmd_busy = 0;
    assign cmd_done = command_state == 1;
    assign cmd_error = command_state == 2;
    assign core_reset = !(setup_done && run && present) || load_error || loading;
    function automatic [31:0] crc_byte(input [31:0] previous,input [7:0] data);
        reg [31:0] value;
        value = previous ^ {24'd0,data};
        for(integer b=0;b<8;b=b+1) value=(value>>1) ^ (value[0]?32'hedb88320:0);
        crc_byte=value;
    endfunction
    reg [48:0] queue [0:511];
    reg [48:0] head;
    reg [9:0] wp,rp;
    wire empty=wp==rp;
    wire full=wp[8:0]==rp[8:0] && wp[9]!=rp[9];
    wire accept=mem_enable && !mem_done && !response_pending;
    wire push=accept && is_file && mem_write && !full && !reset;
    always @(posedge clk) begin
        if(push) queue[wp[8:0]] <= {mem_address[18:2],mem_dataWrite};
        head <= queue[rp[8:0]];
    end
    reg [2:0] engine;
    reg [1:0] lane;
    reg [31:0] word_data;
    wire drained=empty && engine==0;
    assign debug_status={24'd0,load_error,present,focus,drained,run,setup_done,loading,core_reset};
    always @(posedge clk) begin
        mem_done<=0;act_reset<=0;
        if(reset) begin
            mem_dataRead<=0;response_pending<=0;
            wp<=0;rp<=0;engine<=0;wr_req<=0;wr_addr<=0;wr_data<=0;
            lane<=0;word_data<=0;command_state<=0;
            setup_done<=0;run<=0;present<=0;load_error<=0;focus<=0;
            crc_state<=32'hffffffff;rom_bytes<=0;loading<=0;
            portrait_mode<=0;volume<=0;game_id<=0;
            for(integer i=0;i<8;i=i+1) command[i]<=0;
        end else begin
            if(response_pending) begin mem_done<=1;response_pending<=0;end
            else if(accept) begin
                if(is_file && mem_write) begin
                    if(!full) begin wp<=wp+1'b1;response_pending<=1;end
                end else begin
                    response_pending<=1;
                    if(mem_write) begin
                        if(is_command) command[mem_address[4:2]]<=mem_dataWrite;
                        else if(is_local) case(mem_address[11:0])
                            12'h100: if(!core_reset && mem_dataWrite!=0) act_reset<=1;
                            12'h204: volume<=mem_dataWrite[1:0];
                            12'h210: portrait_mode<=mem_dataWrite<3?mem_dataWrite[1:0]:2'd0;
                            default: ;
                        endcase
                        else if(mem_address[31:28]==1) load_error<=1;
                    end else begin
                        mem_dataRead<=0;
                        if(is_command)mem_dataRead<=command[mem_address[4:2]];
                        else if(is_local)case(mem_address[11:0])
                            12'h204:mem_dataRead<={30'd0,volume};
                            12'h210:mem_dataRead<={30'd0,portrait_mode};
                            12'h800:mem_dataRead<=32'h554e4956;
                            12'h804:mem_dataRead<=debug_status;
                            12'h810:mem_dataRead<=rom_bytes;
                            12'h818:mem_dataRead<=rom_crc;
                            default: ;
                        endcase
                    end
                end
            end
            // Outputs are consumed by the synchronous ROM write ports on
            // the edge in state 2. State 3 drops wr_req before the next byte.
            case(engine)
                0:if(!empty)engine<=1;
                1:begin
                    wr_addr<={head[48:32],2'b00};word_data<=head[31:0];
                    wr_data<=head[7:0];wr_req<=1;lane<=0;engine<=2;
                end
                2:begin
                    wr_req<=0;engine<=3;
                    if(!loading || {13'd0,wr_addr}!=rom_bytes || rom_bytes>=GAME_MAX_SIZE) load_error<=1;
                    else begin crc_state<=crc_byte(crc_state,wr_data);rom_bytes<=rom_bytes+1'b1;end
                end
                3:begin
                    if(lane==3)begin rp<=rp+1'b1;engine<=0;end
                    else begin
                        lane<=lane+1'b1;wr_addr<=wr_addr+1'b1;
                        word_data<={8'd0,word_data[31:8]};wr_data<=word_data[15:8];
                        wr_req<=1;engine<=2;
                    end
                end
                default:engine<=0;
            endcase
            if(!cmd_request)command_state<=0;
            else if(command_state==0 && drained && !push)begin
                command_state<=1;command[0]<=0;
                case(command[0][15:0])
                    16'h0000:command[0]<=!setup_done?2:run?4:3;
                    16'h0100:if(setup_done && present && !load_error)run<=1;else command_state<=2;
                    16'h0101:run<=0;
                    16'h0102:if(present && !load_error)setup_done<=1;else command_state<=2;
                    16'h0200:focus<=command[1][0];
                    16'h0300:if(command[1]!=0)command_state<=2;
                        else begin
                            run<=0;setup_done<=0;present<=0;load_error<=0;
                            crc_state<=32'hffffffff;rom_bytes<=0;loading<=1;
                        end
                    16'h0301:begin
                        loading<=0;
                        if(command[1]!=0 || load_error || !loading || command[2]!=rom_bytes || identify_game(rom_crc,rom_bytes)==8'hff)begin
                            command_state<=2;present<=0;load_error<=1;
                        end else begin present<=1;game_id<=identify_game(rom_crc,rom_bytes);end
                    end
                    default:command_state<=2;
                endcase
            end
        end
    end
endmodule
