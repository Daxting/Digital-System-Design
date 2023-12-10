module incident_detector(
input wire rst,
input wire signed [10:0]  bigtruck_x,
input wire signed [10:0]  truck_x,
input wire signed [10:0]  car_x,   
input wire signed [10:0]   player_x,
input wire signed [10:0]   player_y,
input wire [1:0]    state,
output reg [1:0]    next_state
);
    parameter signed [10:0] bigtruck_length=11'd192;
    parameter signed [10:0] truck_length=11'd128;                    
    parameter signed [10:0] car_length=11'd64;                                     
    parameter signed [10:0] player_length=11'd60;
    parameter signed [10:0] bigtruck_gap = 11'd400;  // x+=400 another
    parameter signed [10:0] truck_gap = 11'd240;  // x+=240 another
    parameter signed [10:0] car_gap = 11'd240; // x+=240 another 
    
    always @(*)begin
        if(!rst)
            next_state = MOVEMENT;
        else begin
            case (player_y)
                11'd8:begin
                    case(player_x)
                        11'd8, 11'd168,11'd248,11'd408,11'd488:
                            next_state = LOSE;
                        default:
                            next_state = WIN;
                    endcase 
                end
                11'd88:begin//bigtruck_y
                    if(((player_x>=bigtruck_x)&&(player_x<=bigtruck_x+bigtruck_length-$signed(11'd1)))||((player_x>=bigtruck_x+bigtruck_gap)&&(player_x<=bigtruck_x+bigtruck_gap+bigtruck_length-$signed(1))))
                        next_state = LOSE;
                    else
                        next_state = MOVEMENT;
                end
                11'd248:begin//truck_y
                    if(((player_x>=truck_x)&&(player_x<=truck_x+truck_length-$signed(1)))||((player_x>=truck_x+truck_gap)&&(player_x<=truck_x+truck_gap+truck_length-$signed(1)))||((player_x>=truck_x+$signed(2)*truck_gap)&&(player_x<=truck_x+$signed(2)*truck_gap+truck_length-$signed(1))))
                        next_state = LOSE;
                    else
                        next_state = MOVEMENT;
                end
                11'd328:begin//car_y
                    if(player_x == car_x || player_x == car_x+240 || player_x == car_x+480)
                        next_state = LOSE;
                    else
                        next_state = MOVEMENT;
                end
                default: 
                    next_state = MOVEMENT;
            endcase
        end
    end
endmodule

module movement(
input wire reset,
input wire clk,
input wire [2:0] button, //s4 s3 s0
input wire [1:0] state,
output reg signed [11:0]  bigtruck_x,
output reg signed [11:0]  truck_x,
output reg signed [11:0]  car_x,   
output reg signed [11:0]  player_x,
output reg signed [11:0]  player_y,
output reg [6:0]   step
);

    reg signed [11:0]player_x_next;
    reg signed [11:0]player_y_next;
    
    always @(*)begin //player control
        if(!reset)begin
            player_x_next <= 11'd88;
            player_y_next <= 11'd408;
        end
        else if(button[2] && player_y == 11'd8)begin
            player_x_next <= player_x;
            player_y_next <= player_y;
        end
        else if(button[2])begin
            player_x_next <= player_x;
            player_y_next <= player_y-11'd80;
        end
        else if(button[1] && player_x == 11'd8)begin
            player_x_next <= player_x;
            player_y_next <= player_y;
        end
        else if(button[1])begin
            player_x_next <= player_x - 11'd80;
            player_y_next <= player_y;
        end
        else if(button && player_x == 11'd568)begin
            player_x_next <= player_x;
            player_y_next <= player_y;
        end
        else if(button[0]) begin
            player_x_next <= player_x + 11'd80;
            player_y_next <= player_y;
        end
        else begin
            player_x_next <= player_x;
            player_y_next <= player_y;
        end
    end
    
    
    reg stabler;
    always @(posedge clk, negedge reset)begin // player position follower
        if(!reset)begin
            player_x <= 11'd88;
            player_y <= 11'd408;
            stabler <=1'b0;
            step = 0;
        end
        else if(state!=MOVEMENT)begin
            player_x <= player_x;
            player_y <= player_y;
        end
        else if(player_x==player_x_next && player_y== player_y_next)begin
            player_x <= player_x;
            player_y <= player_y;
            stabler <= 1'b0;
        end
        else if(!stabler && (player_x!=player_x_next || player_y!= player_y_next) )begin
            player_x <= player_x_next;
            player_y <= player_y_next;
            step <= step + 1;
            stabler <= 1'b1;
        end
        else begin
            player_x <= player_x;
            player_y <= player_y;
        end
    end
    
    wire clk_1hz, clk_05hz;
    reg [27:0]counter;
    always @(posedge clk, negedge reset)begin//clk divider
        if(!reset)
            counter=27'b0;
        else
            counter<=counter+1'b1;
    end
    assign clk_1hz=counter[26];
    assign clk_05hz=counter[27];


    reg [9:0]car_x_next;
    reg signed [9:0]truck_x_next;
    reg signed [9:0]bigtruck_x_next;
    
    always @(posedge clk_1hz, negedge reset)begin // car position follower
        if(!reset)
            car_x<=10'd8;
        else if(state!=MOVEMENT)
            car_x <= car_x;
        else
            car_x<=car_x_next;
    end
    
    always @(posedge clk_05hz, negedge reset)begin // truck, bigturck position follower
        if(!reset)begin
            truck_x<=11'd8;
            bigtruck_x<=11'd8;
        end
        else if(state!=MOVEMENT)begin
            truck_x<=truck_x;
            bigtruck_x<=bigtruck_x;
        end
        else begin
            truck_x<=truck_x_next;
            bigtruck_x<=bigtruck_x_next;
        end
    end
    
    always @(*)begin // vehicle position controller
        if(!reset)begin
            bigtruck_x_next = 11'd8;
            truck_x_next    = 11'd8;
            car_x_next      = 11'd8;
        end
        else begin            
            case(car_x)
                11'd8: car_x_next<=11'd88;
                11'd88: car_x_next<=11'd168;
                11'd168: car_x_next<=11'd8;
                default: car_x_next<=11'd0;
            endcase
            
            case(truck_x)
                11'd8: truck_x_next<=11'd88;
                11'd88: truck_x_next<=-11'd72;
                -11'd72: truck_x_next<=11'd8;
                default: truck_x_next<=11'd0;
            endcase
            
            case(bigtruck_x)
                11'd8: bigtruck_x_next<=-11'd72;
                -11'd72: bigtruck_x_next<=-11'd152;
                -11'd152: bigtruck_x_next<=11'd168;
                11'd168: bigtruck_x_next<=11'd88;
                11'd88: bigtruck_x_next<=11'd8;
                default: bigtruck_x_next<=11'd0;
            endcase
        end
    end

endmodule 

module main(
input wire clk,
input wire rst,
input wire [2:0]button, //s4 s3 s0
output wire hsync,
output wire vsync,
output wire [3:0] vga_r,
output wire [3:0] vga_g,
output wire [3:0] vga_b,
output wire [7:0] sevenseg,
output reg [3:0] seg_enable,
output reg [15:0] light
);

    wire [2:0] button_fine;
    signal_process s1(.clk(clk), .Reset(rst), .origin(button[2]),.outcome(button_fine[2]));
    signal_process s2(.clk(clk), .Reset(rst), .origin(button[1]),.outcome(button_fine[1]));
    signal_process s3(.clk(clk), .Reset(rst), .origin(button[0]),.outcome(button_fine[0]));
    //fundamental information
    parameter [10:0] height=7'd64;
    parameter signed [10:0] bigtruck_length=11'd192;
    parameter signed [10:0] truck_length=11'd128;                    
    parameter signed [10:0] car_length=11'd64;                    
    parameter signed [10:0] brick_length=11'd64;                   
    parameter signed [10:0] player_length=11'd60;
    parameter signed [10:0] player_height=11'd60;
            
    state_t state;
    state_t next_state;
    always @(posedge clk, negedge rst)begin // state follower
        if(!rst)
            state <= MOVEMENT;
        else
            state <= next_state;
    end
    wire [6:0]step; // demo in the 7 seg
    wire [3:0] segvalue;
    output_interface o1(.clk(clk),.reset(rst),.step(step),.state(state),.sevenseg(sevenseg),.segvalue(segvalue),.seg_enable(seg_enable),.light(light));
    //time wizard
    wire            pclk;
    dcm_25M u0(.clk_in1(clk),.clk_out1(pclk),.reset(!rst));
    //sync process
    wire            valid;
    wire [9:0]      uh_cnt, uv_cnt;
    SyncGeneration u6(.pclk(pclk),.reset(rst),.hSync(hsync),.vSync(vsync),.dataValid(valid),.hDataCnt(uh_cnt),.vDataCnt(uv_cnt));
    wire signed [10:0] h_cnt;
    wire signed [10:0] v_cnt;
    assign h_cnt={1'b0, uh_cnt};
    assign v_cnt={1'b0, uv_cnt};
    
    reg [11:0]      vga_data;
    assign {vga_r,vga_g,vga_b} = vga_data;
    // rom setting of objects
    wire [11:0]     rom_dout[4:0];
    reg [13:0]      rom_addr[4:0];  //2^14=16384
    bigtruck_rom u1(.clka(pclk),.addra(rom_addr[4]),.douta(rom_dout[4]));
    truck_rom u2(.clka(pclk),.addra(rom_addr[3]),.douta(rom_dout[3]));
    car_rom u3(.clka(pclk),.addra(rom_addr[2]),.douta(rom_dout[2]));
    brick_rom u4(.clka(pclk),.addra(rom_addr[1]),.douta(rom_dout[1]));
    player_rom u5(.clka(pclk),.addra(rom_addr[0]),.douta(rom_dout[0]));
    //position of objects
    parameter[10:0]  brick_y =11'd8;
    wire signed [10:0]  brick_x[4:0];
    assign brick_x[0] = 11'd8;
    assign brick_x[1] = 11'd168;
    assign brick_x[2] = 11'd248;
    assign brick_x[3] = 11'd408;
    assign brick_x[4] = 11'd488;
    wire signed [10:0]       bigtruck_x;
    parameter signed [10:0]  bigtruck_y = 11'd88;
    parameter signed [10:0]  bigtruck_gap = 11'd400;  // x+=400 another
    wire signed [10:0]       truck_x;  
    parameter signed [10:0]  truck_y = 11'd248; 
    parameter signed [10:0]  truck_gap = 11'd240;  // x+=240 another
    wire signed [10:0]       car_x;     
    parameter signed [10:0]  car_y = 11'd328;
    parameter signed [10:0]  car_gap = 11'd240; // x+=240 another 
    wire signed [10:0]        player_x;
    wire signed [10:0]        player_y;
    movement(.reset(rst),.clk(clk),.button(button_fine),.state(state),.bigtruck_x(bigtruck_x),.truck_x(truck_x),.car_x(car_x),
            .player_x(player_x),.player_y(player_y),.step(step));
    incident_detector i0(.rst(rst),.bigtruck_x(bigtruck_x),.truck_x(truck_x),.car_x(car_x),.player_x(player_x),.player_y(player_y),.state(state),.next_state(next_state));
    //if the position is on certain object
    wire            area[4:0];
    reg             truck_area, bigtruck_area;
    assign area[4]=bigtruck_area;
    assign area[3]=(v_cnt>=truck_y)&&(v_cnt<=truck_y+(height-$signed(11'd1)))&&truck_area;
    always @(*)begin //bigtruck
        if(bigtruck_x<$signed(11'd0))
            bigtruck_area=(((h_cnt>=0)&&(h_cnt<=bigtruck_length-$signed(1)-($signed(-11'd1)*bigtruck_x)))||
            ((h_cnt>=bigtruck_gap-(~bigtruck_x+$signed(11'd1)))&&(h_cnt<=bigtruck_gap+bigtruck_length-$signed(11'd1)-(~bigtruck_x+$signed(11'd1)))))
            &&(v_cnt>=bigtruck_y)&&(v_cnt<=bigtruck_y+height-$signed(11'd1));
        else
            bigtruck_area=(((h_cnt>=bigtruck_x)&&(h_cnt<=bigtruck_x+bigtruck_length-$signed(11'd1)))||
            ((h_cnt>=bigtruck_x+bigtruck_gap)&&(h_cnt<=bigtruck_x+bigtruck_gap+bigtruck_length-$signed(11'd1))))
            &&(v_cnt>=bigtruck_y)&&(v_cnt<=bigtruck_y+height-$signed(11'd1));
    end
    
    always @(*)begin //truck
        if(truck_x==$signed(-11'd72))  
            truck_area=((h_cnt<=$signed(11'd55)))|| ((h_cnt>=11'd167)&&(h_cnt<=11'd295))||((h_cnt>=$signed(11'd407)) &&(h_cnt<=$signed(11'd533)));
        else 
            truck_area=(((h_cnt>=truck_x)&&(h_cnt<=(truck_x+truck_length)-$signed(11'd1)))||
                        ((h_cnt>=truck_x+truck_gap)&&(h_cnt<=(truck_x+truck_gap)+(truck_length-$signed(11'd1))))||
                        ((h_cnt>=truck_x+$signed(11'd2)*truck_gap)&&(h_cnt<=truck_x+(($signed(11'd2)*truck_gap)+(truck_length-$signed(11'd1))))));
    end
    assign area[2] = ((((h_cnt>=car_x)&&(h_cnt<=car_x+car_length-$signed(11'd1)))||((h_cnt>=car_x+car_gap)&&(h_cnt<=car_x+car_gap+car_length-$signed(11'd1)))||((h_cnt>=car_x+$signed(11'd2)*car_gap)&&(h_cnt<=car_x+$signed(11'd2)*car_gap+car_length-$signed(11'd1))))&&(v_cnt>=car_y)&&(v_cnt<=car_y+height-$signed(11'd1)))?1'b1:1'b0;
    wire [4:0] brick_area;
    for (genvar i = 0; i < 5; i = i + 1) begin
        assign brick_area[i]= ((h_cnt>=brick_x[i])&(h_cnt<=brick_x[i]+brick_length-1)&(v_cnt>=brick_y)&(v_cnt<=brick_y+height-1))?1'b1:1'b0;
    end
    assign area[1] = brick_area[4] || brick_area[3] || brick_area[2] || brick_area[1]|| brick_area[0];
    assign area[0] = ((h_cnt>=player_x)&(h_cnt<=player_x+player_length-1)&(v_cnt>=player_y)&(v_cnt<=player_y+player_height-1))?1'b1:1'b0;
    //build the environment
    reg[4:0] env;
    parameter [2:0] solidline_width = 3'd5;
    parameter [1:0] dottedline_width = 2'd3;
    // 0 for solid line
    //1 for dottedline black
    //2 for dottedline white
    //3 for blue background
    //4 for orrange background
    reg [6:0] counter80;
    reg [1:0] counter3;
    always @(posedge pclk, negedge rst)begin //create the vertical dotted line
        if(!rst)begin
            counter80<=7'b0;
            counter3<=2'd0;
        end
        else if(valid)begin
            if(counter80<dottedline_width)begin
                counter80<=counter80+1'b1;
                counter3<=counter3+1'b1;
            end
            else if (dottedline_width<=counter80 && counter80<79)begin
                counter80<=counter80+1'b1;
                counter3<=counter3+1'b1;
            end
            else if(counter80==7'd79)
                counter80<=7'd0;
        end
        else begin
            counter80<=0;
            counter3<=0;
        end
    end
    always @(*)begin//set the env
        if((v_cnt<solidline_width || v_cnt>=480-solidline_width) || (h_cnt<solidline_width || h_cnt>=640-solidline_width))  env=5'b00001;
        else if(counter80<dottedline_width)begin //vertical line
            if(v_cnt[1:0] == 2'b00 || v_cnt[1:0] == 2'b01)    env=5'b00010;
            else    env=5'b00100;
        end
        else if(($signed(11'd79)<v_cnt && v_cnt<$signed(11'd83)) || ($signed(11'd159)<v_cnt && v_cnt<$signed(11'd163)) 
                    || ($signed(11'd239)<v_cnt && v_cnt<$signed(11'd243))
                || ($signed(11'd319)<v_cnt && v_cnt<$signed(11'd323)) || ($signed(11'd399)<v_cnt && v_cnt<$signed(11'd403)) )begin
            if(counter3==2'd0 || counter3==2'd1) env=5'b00010;
            else env=5'b00100;
        end
        else if(v_cnt>$signed(11'd82) && v_cnt<$signed(11'd160))    env=5'b01000;
        else if(v_cnt>$signed(11'd242) && v_cnt<(11'd400))   env=5'b10000;
        else env=5'b00000;
    end


    always @(posedge pclk or negedge rst)begin: logo_display
      if (!rst) begin
         rom_addr[4]<=14'd0;
         rom_addr[3]<=14'd0;
         rom_addr[2]<=14'd0;
         rom_addr[1]<=14'd0;
         rom_addr[0]<=14'd0;
         vga_data <= 12'd0;      
      end
      else begin
          if (valid)begin
             if(env[0]) begin
                vga_data <= 12'h00f;    // 0 for solid line
                //bigtruck
                if(bigtruck_x<$signed(11'd0) && h_cnt == $signed(11'd2) && area[4])
                    rom_addr[4] <= $signed(rom_addr[4]) + ($signed(11'd5)-bigtruck_x);
                else
                    rom_addr[4] <= rom_addr[4];
                //truck
                if(truck_x==$signed(-11'd72) && h_cnt == $signed(11'd2) && area[3])
                    rom_addr[3] <= $signed(rom_addr[3]) + $signed(11'd77);
                else 
                    rom_addr[3] <= rom_addr[3];
             end
             else if(area[0])begin // player
                vga_data <= rom_dout[0];
                rom_addr[0] <= rom_addr[0] + 14'd1;
                if(area[4])
                    rom_addr[4] <= rom_addr[4] + 14'd1;
                else if(area[3])begin
                    if(h_cnt==truck_x+truck_length-$signed(11'd1))begin //first normal
                        rom_addr[3] <= $signed(rom_addr[3]) - truck_length +$signed(11'd1) ;
                    end
                    else if(h_cnt==truck_x+truck_gap+truck_length-$signed(11'd1))begin //secon normal
                        rom_addr[3] <= $signed(rom_addr[3]) - truck_length +$signed(11'd1) ;
                    end
                    else
                        rom_addr[3] <= rom_addr[3] + 14'd1;
                end
                else if(area[2])
                    rom_addr[2] <= rom_addr[2] + 14'd1;
                else if(area[1])
                    rom_addr[1] <= rom_addr[1] + 14'd1;
                else begin
                    rom_addr[4] <= rom_addr[4];
                    rom_addr[3] <= rom_addr[3];
                    rom_addr[2] <= rom_addr[2];
                    rom_addr[1] <= rom_addr[1];
                end
             end
             else if (area[4])begin //bigturck
                if(bigtruck_x>$signed(11'd8) && h_cnt == $signed(11'd634))begin//last half
                    vga_data <= rom_dout[4];
                    rom_addr[4] <= $signed(rom_addr[4]) + bigtruck_x+bigtruck_gap+bigtruck_length-$signed(11'd634);
                end
                else if($signed(h_cnt)==$signed(bigtruck_x)+$signed(bigtruck_length)-$signed(1))begin //first normal
                    vga_data <= rom_dout[4];
                    rom_addr[4] <= $signed(rom_addr[4]) - bigtruck_length + $signed(11'd1) ; 
                end
                else begin
                    vga_data <= rom_dout[4];
                    rom_addr[4] <= rom_addr[4] + 14'd1;
                end
             end
             else if (area[3])begin //truck
                if(truck_x==$signed(11'd88) && h_cnt == $signed(11'd634))begin//last half
                    vga_data <= rom_dout[3];
                    rom_addr[3] <= $signed(rom_addr[3]) + (truck_x+$signed(11'd2)*truck_gap+truck_length-$signed(11'd634));
                end
                else if(h_cnt==truck_x+truck_length-$signed(11'd1))begin //first normal
                    vga_data <= rom_dout[3];
                    rom_addr[3] <= $signed(rom_addr[3]) - truck_length +$signed(11'd1) ;
                end
                else if(h_cnt==truck_x+truck_gap+truck_length-$signed(11'd1))begin //secon normal
                    vga_data <= rom_dout[3];
                    rom_addr[3] <= $signed(rom_addr[3]) - truck_length +$signed(11'd1) ;
                end
                else begin
                    vga_data <= rom_dout[3];
                    rom_addr[3] <= rom_addr[3] + 14'd1;
                end
             end
             else if (area[2])begin //car
                if(h_cnt==car_x+car_length-$signed(11'd1))begin
                    vga_data <= rom_dout[2];
                    rom_addr[2] <= rom_addr[2] - car_length +$signed(11'd1) ; 
                end
                else if(h_cnt!=$signed(11'd471) && h_cnt==car_x+car_gap+car_length-$signed(11'd1))begin
                    vga_data <= rom_dout[2];
                    rom_addr[2] <= rom_addr[2] - car_length +$signed(11'd1) ; 
                end
                else begin
                    vga_data <= rom_dout[2];
                    rom_addr[2] <= rom_addr[2] + 14'd1;
                end
             end
             else if (area[1])begin
                vga_data <= rom_dout[1];
                rom_addr[1] <= rom_addr[1] + 14'd1;
                if(h_cnt==$signed(11'd71) || h_cnt==$signed(11'd231) || h_cnt==$signed(11'd311) || h_cnt==$signed(11'd471))
                    rom_addr[1] <= rom_addr[1] - brick_length + 1;
             end
             else begin
                 rom_addr[4]<=rom_addr[4];
                 rom_addr[3]<=rom_addr[3];
                 rom_addr[2]<=rom_addr[2];
                 rom_addr[1]<=rom_addr[1];
                 rom_addr[0]<=rom_addr[0];
                 //special environment
                 if(env[1])     vga_data <= 12'h000;    //1 for dottedline black   
                 else if(env[2])     vga_data <= 12'hfff;    //2 for dottedline white   
                 else if(env[3])     vga_data <= 12'h029;    //3 for blue background    
                 else if(env[4])     vga_data <= 12'he70;    //4 for orrange background 
                 else                vga_data <= 12'hfff;    
             end
          end
          else begin
              vga_data <= 12'h000;
              if (v_cnt == 0)begin
                   rom_addr[4]<=14'd0;
                   rom_addr[3]<=14'd0;
                   rom_addr[2]<=14'd0;
                   rom_addr[1]<=14'd0;
                   rom_addr[0]<=14'd0;
              end
              else begin
                  rom_addr[4]<=rom_addr[4];
                  rom_addr[3]<=rom_addr[3];
                  rom_addr[2]<=rom_addr[2];
                  rom_addr[1]<=rom_addr[1];
                  rom_addr[0]<=rom_addr[0];
              end  
          end
      end
   end    
   
endmodule

module SyncGeneration(pclk, reset, hSync, vSync, dataValid, hDataCnt, vDataCnt);
  
   input        pclk;
   input        reset;
   output       hSync;
   output       vSync;
   output       dataValid;
   output [9:0] hDataCnt;
   output [9:0] vDataCnt ;
 

   parameter    H_SP_END = 96;
   parameter    H_BP_END = 144;
   parameter    H_FP_START = 785;
   parameter    H_TOTAL = 800;
   
   parameter    V_SP_END = 2;
   parameter    V_BP_END = 35;
   parameter    V_FP_START = 516;
   parameter    V_TOTAL = 525;

   reg [9:0]    x_cnt,y_cnt;
   wire         h_valid,v_valid;
     
   always @(negedge reset or posedge pclk) begin
      if (!reset)
         x_cnt <= 10'd1;
      else begin
         if (x_cnt == H_TOTAL)
            x_cnt <= 10'd1;
         else
            x_cnt <= x_cnt + 1;
      end
   end
   
   always @(posedge pclk or negedge reset) begin
      if (!reset)
         y_cnt <= 10'd1;
      else begin
         if (y_cnt == V_TOTAL & x_cnt == H_TOTAL)
            y_cnt <= 1;
         else if (x_cnt == H_TOTAL)
            y_cnt <= y_cnt + 1;
         else y_cnt<=y_cnt;
      end
   end
   
   assign hSync = ((x_cnt > H_SP_END)) ? 1'b1 : 1'b0;
   assign vSync = ((y_cnt > V_SP_END)) ? 1'b1 : 1'b0;
   
   // Check P7 for horizontal timing   
   assign h_valid = ((x_cnt > H_BP_END) & (x_cnt <= H_FP_START)) ? 1'b1 : 1'b0;
   // Check P9 for vertical timing
   assign v_valid = ((y_cnt > V_BP_END) & (y_cnt <= V_FP_START)) ? 1'b1 : 1'b0;
   
   assign dataValid = ((h_valid == 1'b1) & (v_valid == 1'b1)) ? 1'b1 :  1'b0;
   
   // hDataCnt from 1 if h_valid==1
   assign hDataCnt = ((h_valid == 1'b1)) ? x_cnt - H_BP_END : 10'b0;
   // vDataCnt from 1 if v_valid==1
   assign vDataCnt = ((v_valid == 1'b1)) ? y_cnt - V_BP_END : 10'b0; 
            
   
endmodule

typedef enum logic[1:0]{
    MOVEMENT, WIN, LOSE 
}state_t;

module seven_seg_display( 
    input wire [3:0]seg, 
    output reg [7:0]seg_position
);
    always @(seg) begin
        case(seg)
            4'd0 : seg_position=8'b00111111;
            4'd1 : seg_position=8'b00000110;
            4'd2 : seg_position=8'b01011011;
            4'd3 : seg_position=8'b01001111;
            4'd4 : seg_position=8'b01100110;
            4'd5 : seg_position=8'b01101101;
            4'd6 : seg_position=8'b01111101;
            4'd7 : seg_position=8'b00000111;
            4'd8 : seg_position=8'b01111111;
            4'd9 : seg_position=8'b01101111;
            4'd10: seg_position=8'b00000000;
            default:seg_position=8'b01111111;
        endcase
    end
endmodule 

module signal_process(//make the signal stable
input wire clk,
input wire Reset,
input wire origin,
output wire outcome
);
    //for FPGA
    reg [20:0]debouser;
    always @(posedge clk, negedge  Reset)begin
        if(!Reset)
            debouser<={1'b1,20'b0};
        else if(origin)
            debouser<=21'b0;
        else if(debouser<{1'b1,20'b0})
            debouser<=debouser+21'b1;    
    end
    assign outcome=!debouser[20];
    
endmodule 


module output_interface(
input clk,
input reset,
input wire [6:0] step,
input wire [1:0] state,
output wire [7:0] sevenseg,
output reg [3:0] segvalue,
output reg [3:0] seg_enable,
output reg [15:0] light
);
    
    wire clk_4hz, clk_400hz;
    reg [24:0]counter;
    always @(posedge clk, negedge reset)begin//clk divider
        if(!reset)
            counter=24'b0;
        else
            counter<=counter+1'b1;
    end
    assign clk_4hz=counter[24];
    assign clk_400hz=counter[17];
    
    reg [1:0] counter4;
    always @(posedge clk_400hz, negedge reset)begin
        if(!reset)
            counter4<=2'b0;
        else
            counter4<=counter4+2'b1;    
    end
    
    always @(posedge clk_400hz, negedge reset)begin // seg_enable controler
        if(!reset)
            seg_enable <= 4'b0000;
        else begin
            case (counter4)
                2'd0: begin 
                    if(state != WIN)
                        seg_enable <= 4'b0000;
                    else
                        seg_enable <= 4'b1000;
                end
                2'd1: begin 
                    if(state != WIN)
                        seg_enable <= 4'b0000;
                    else
                        seg_enable <= 4'b0100;
                end
                2'd2:
                    seg_enable <= 4'b0010;
                2'd3:
                    seg_enable <= 4'b0001;
                default : 
                    seg_enable <= 4'b0000;
            endcase
        end
    end
    
    always @(posedge clk_400hz, negedge reset)begin //segvalue controler
        if(!reset)begin
            segvalue <= 4'd0;
        end
        else begin
            case(counter4)
                2'd0:begin
                    if(state!=WIN)
                        segvalue <= 4'd0;
                    else
                        segvalue <= 4'd9;
                end
                2'd1:begin
                    if(state!=WIN)
                        segvalue <= 4'd0;
                    else
                        segvalue <= 4'd9;
                end
                2'd2: begin
                    if(step >= 7'd90)
                        segvalue <= 4'd9;
                    else if(step >= 7'd80)
                        segvalue <= 4'd8;
                    else if(step >= 7'd70)
                        segvalue <= 4'd7;
                    else if(step >= 7'd60)
                        segvalue <= 4'd6;
                    else if(step >= 7'd50)
                        segvalue <= 4'd5;
                    else if(step >= 7'd40)
                        segvalue <= 4'd4;
                    else if(step >= 7'd30)
                        segvalue <= 4'd3;
                    else if(step >= 7'd20)
                        segvalue <= 4'd2;
                    else if(step >= 7'd10)
                        segvalue <= 4'd1;
                    else
                        segvalue <= 4'd0;
                end
                2'd3:begin
                    if(step >= 7'd90)
                        segvalue <= step-7'd90;
                    else if(step >= 7'd80)
                        segvalue <= step-7'd80;
                    else if(step >= 7'd70)
                        segvalue <= step-7'd70;
                    else if(step >= 7'd60)
                        segvalue <= step-7'd60;
                    else if(step >= 7'd50)
                        segvalue <= step-7'd50;
                    else if(step >= 7'd40)
                        segvalue <= step-7'd40;
                    else if(step >= 7'd30)
                        segvalue <= step-7'd30;
                    else if(step >= 7'd20)
                        segvalue <= step-7'd20;
                    else if(step >= 7'd10)
                        segvalue <= step-7'd10;
                    else
                        segvalue <= step;
                end
                default :begin
                    segvalue <= 4'd0;
                end
            endcase 
        end
    end
    seven_seg_display s0(.seg(segvalue),.seg_position(sevenseg));
    
    always @(posedge clk_4hz, negedge reset)begin //light controler
        if(!reset)
            light <= 16'b0000000000000000;
        else if(state==LOSE) begin
            case(light)
                16'b0000000000000000:   light<=16'b0000000110000000;
                16'b0000000110000000:   light<=16'b0000001001000000;
                16'b0000001001000000:   light<=16'b0000010000100000;
                16'b0000010000100000:   light<=16'b0000100000010000;
                16'b0000100000010000:   light<=16'b0001000000001000;
                16'b0001000000001000:   light<=16'b0010000000000100;
                16'b0010000000000100:   light<=16'b0100000000000010;
                16'b0100000000000010:   light<=16'b1000000000000001;
                16'b1000000000000001:   light<=16'b0000000110000000;
                default:                 light<=16'b1111111111111111;
            endcase 
        end 
        else
            light <= 16'b0000000000000000;
    end
    
endmodule 