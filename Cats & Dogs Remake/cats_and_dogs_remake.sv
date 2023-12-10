`timescale 1ns/1ns

typedef enum logic [1:0] { MOVE, THROW, SUCCESS, FAIL } GameState;
typedef enum logic [1:0] { NONE_KEY, KEY_J, KEY_K, KEY_B} KeyType;

interface Position;
    logic   [4:0]   X;
    logic   [3:0]   Y;

    modport In(input X, Y);
    modport Out(output X, Y);
endinterface

module main(VGA_R, VGA_G, VGA_B, H_Sync, V_Sync, Seg_L, Seg_R, Seg_En_L, Seg_En_R, LED, GameLevel, Wind, Weapon, S0, S3, S2, PS2_CLK, PS2_Data, FPGA_CLK, RESET);
    output  [3:0]   VGA_R, VGA_G, VGA_B;
    output          H_Sync, V_Sync;
    output  [7:0]   Seg_L, Seg_R;
    output  [3:0]   Seg_En_L, Seg_En_R;
    output  [15:0]  LED;

    input           GameLevel, Wind, Weapon; // Switch 1, 5, 8 (From Left)
    input           S0, S3, S2;
    input           PS2_CLK, PS2_Data;
    input           FPGA_CLK, RESET;

    logic           isS0, isS3, isS2;
    logic           CLK_25MHz, CLK_60Hz, CLK_5Hz, CLK_25Hz, CLK_2Hz, CLK_1Hz;

    KeyType         Key;
    GameState       gameState;

    logic           dogHide;    // 1為狗的隱身模式
    logic   [2:0]   wallHigh, wallHigh_next;   // 障礙物的最高點Y座標
    logic   [3:0]   Power;      // 力道
    logic   [3:0]   Chance;     // 玩家機會
    logic   [3:0]   Life;       // 狗的生命值
    logic   [3:0]   incident;   // 爆炸的攻擊、無爆炸的攻擊、爆炸的落空、無爆炸的落空

    Position        cat();
    Position        cat_next();
    Position        dog();
    Position        dog_next();
    Position        weapon();

    CLK_Div clk_div(.*);
    dcm_25m clk_dcm(.resetn(RESET), .*);
    LED_Display LED_display(.*);
    Seg_Display seg_display(.*);
    VGA_Display vga_display(.*);

    Weapon_Control weapon_control(.*);
    Cat_Control cat_control(.*);
    Dog_Control dog_control(.*);
    Wall_Control wall_control(.*);
    GameState_Control gameState_control(.*);
    PS2_Reader ps2_reader(.*);
    DeBounce S0_debounce(isS0, S0, CLK_25Hz, RESET);
    DeBounce S3_debounce(isS3, S3, CLK_25Hz, RESET);
    DeBounce S2_debounce(isS2, S2, CLK_25Hz, RESET);
endmodule

// 除頻器
module CLK_Div(CLK_60Hz, CLK_25Hz, CLK_5Hz, CLK_2Hz, CLK_1Hz, FPGA_CLK, RESET);
    output          CLK_60Hz, CLK_25Hz, CLK_5Hz, CLK_2Hz, CLK_1Hz;
    input           FPGA_CLK, RESET;
    logic   [25:0]  counters;

    assign CLK_60Hz = counters[18];
    assign CLK_25Hz = counters[20];
    assign CLK_5Hz = counters[23];
    assign CLK_2Hz = counters[24];
    assign CLK_1Hz = counters[25];

    always_ff@(posedge FPGA_CLK or negedge RESET) begin
        if(!RESET) counters <= 26'd0;
        else counters <= counters + 26'd1;
    end
endmodule

// 按鍵去顫
module DeBounce(isButton, Button, CLK, RESET);
    output          isButton;
    input           Button, CLK, RESET;
    logic   [2:0]   buffers;

    assign isButton = (!buffers[2]) & buffers[1] & buffers[0];

    always_ff@(posedge CLK or negedge RESET) begin
        if(!RESET) buffers <= 3'b000;
        else buffers <= {buffers[1:0], Button};
    end
endmodule

// VGA控制
module VGA_Display(VGA_R, VGA_G, VGA_B, H_Sync, V_Sync, incident, dogHide, Weapon, wallHigh, cat, dog, weapon, CLK_2Hz, CLK_25MHz, RESET);
    output  [3:0]   VGA_R, VGA_G, VGA_B;
    output          H_Sync, V_Sync;
    input   [3:0]   incident;      // 爆炸的攻擊、無爆炸的攻擊、爆炸的落空、無爆炸的落空
    input           dogHide, Weapon;
    input   [2:0]   wallHigh;
    input           CLK_2Hz, CLK_25MHz, RESET;

    input   Position.In cat;
    input   Position.In dog;
    input   Position.In weapon;

    logic           dataValid;
    logic   [9:0]   H_Cnt, V_Cnt;

    logic   [11:0]  vga_data;
    logic   [9:0]   cat_X, cat_Y, dog_X, dog_Y, weapon_X, weapon_Y;
    logic           Edge_Area, Ground_Area, Cat_Area, Dog_Area, Weapon_Area, Wall_Area, V_Line_Area, H_Line_Area, Explotion_Area;
    logic   [11:0]  catROM_addr, boomROM_addr, boneROM_addr;
    logic   [13:0]  dogROM_addr;
    logic   [11:0]  catROM_out, dogROM_out, boomROM_out, boneROM_out;

    parameter       BLOCK_HEIGTH = 10'd60;
    parameter       BLOCK_WIDTH  = 10'd40;

    SyncGeneration syncgeneration(.*);
    catROM catrom(.clka(CLK_25MHz), .addra(catROM_addr), .douta(catROM_out));
    dogROM dogrom(.clka(CLK_25MHz), .addra(dogROM_addr), .douta(dogROM_out));
    boneROM bonerom(.clka(CLK_25MHz), .addra(boneROM_addr), .douta(boneROM_out));
    boomROM boomrom(.clka(CLK_25MHz), .addra(boomROM_addr), .douta(boomROM_out));


    assign {VGA_R, VGA_G, VGA_B} = vga_data;

    assign cat_X = cat.X * BLOCK_WIDTH;
    assign cat_Y = cat.Y * BLOCK_HEIGTH;

    assign dog_X = dog.X * BLOCK_WIDTH;
    assign dog_Y = dog.Y * BLOCK_HEIGTH;

    assign weapon_X = weapon.X * BLOCK_WIDTH;
    assign weapon_Y = weapon.Y * BLOCK_HEIGTH;

    assign Edge_Area = (H_Cnt <= 10'd5 | H_Cnt >= 10'd635 | V_Cnt <= 10'd5);
    assign Ground_Area = (V_Cnt >= 10'd475);
    assign Cat_Area = (((H_Cnt + 10'd1) >= cat_X) & ((H_Cnt + 10'd1) <= cat_X + BLOCK_WIDTH) & (V_Cnt >= cat_Y) & (V_Cnt < cat_Y + BLOCK_HEIGTH)) ? 1'b1 : 1'b0;
    assign Dog_Area = (((H_Cnt + 10'd1) >= dog_X) & ((H_Cnt + 10'd1) <= dog_X + (BLOCK_WIDTH * 2)) & (V_Cnt >= dog_Y) & (V_Cnt < dog_Y + (BLOCK_HEIGTH * 2))) ? 1'b1 : 1'b0;
    assign Weapon_Area = (((H_Cnt + 10'd1) >= weapon_X) & ((H_Cnt + 10'd1) <= weapon_X + BLOCK_WIDTH) & (V_Cnt >= weapon_Y) & (V_Cnt < weapon_Y + BLOCK_HEIGTH)) ? 1'b1 : 1'b0;
    assign Wall_Area = (H_Cnt >= 10'd240 & H_Cnt <= 10'd280);

    always_comb begin
        if(weapon_Y != 4'd0) Explotion_Area = ( (H_Cnt + 10'd1) >= (weapon_X - BLOCK_WIDTH) & (H_Cnt + 10'd1) <= (weapon_X + (BLOCK_WIDTH * 2)) 
                            & (V_Cnt + 10'd1) >= (weapon_Y - BLOCK_HEIGTH) & (V_Cnt + 10'd1) <= (weapon_Y + (BLOCK_HEIGTH * 2)) );
        else Explotion_Area = ( (H_Cnt + 10'd1) >= (weapon_X - BLOCK_WIDTH) & (H_Cnt + 10'd1) <= (weapon_X + (BLOCK_WIDTH * 2)) 
                            & (V_Cnt + 10'd1) >= (weapon_Y) & (V_Cnt + 10'd1) <= (weapon_Y + (BLOCK_HEIGTH * 2)) );
    end
    
    assign V_Line_Area = (H_Cnt == (BLOCK_WIDTH *  1)) | (H_Cnt == (BLOCK_WIDTH *  2)) | (H_Cnt == (BLOCK_WIDTH *  3)) 
                       | (H_Cnt == (BLOCK_WIDTH *  4)) | (H_Cnt == (BLOCK_WIDTH *  5)) | (H_Cnt == (BLOCK_WIDTH *  6))
                       | (H_Cnt == (BLOCK_WIDTH *  7)) | (H_Cnt == (BLOCK_WIDTH *  8)) | (H_Cnt == (BLOCK_WIDTH *  9))                       
                       | (H_Cnt == (BLOCK_WIDTH * 10)) | (H_Cnt == (BLOCK_WIDTH * 11)) | (H_Cnt == (BLOCK_WIDTH * 12))
                       | (H_Cnt == (BLOCK_WIDTH * 13)) | (H_Cnt == (BLOCK_WIDTH * 14)) | (H_Cnt == (BLOCK_WIDTH * 15));
    
    assign H_Line_Area = (V_Cnt == (BLOCK_HEIGTH *  1)) | (V_Cnt == (BLOCK_HEIGTH *  2)) | (V_Cnt == (BLOCK_HEIGTH *  3)) 
                       | (V_Cnt == (BLOCK_HEIGTH *  4)) | (V_Cnt == (BLOCK_HEIGTH *  5)) | (V_Cnt == (BLOCK_HEIGTH *  6))
                       | (V_Cnt == (BLOCK_HEIGTH *  7));

    assign catROM_addr = (Cat_Area & dataValid) ? ((V_Cnt - cat_Y) * (BLOCK_WIDTH) + ((H_Cnt + 10'd1) - cat_X)) : 12'd0;
    assign dogROM_addr = (Dog_Area & dataValid) ? ((V_Cnt - dog_Y) * (BLOCK_WIDTH * 2) + ((H_Cnt + 10'd1) - dog_X)) : 14'd0;
    assign boomROM_addr = (Weapon_Area & dataValid & Weapon) ? ((V_Cnt - weapon_Y) * (BLOCK_WIDTH) + ((H_Cnt + 10'd1) - weapon_X)) : 12'd0;
    assign boneROM_addr = (Weapon_Area & dataValid & !Weapon) ? ((V_Cnt - weapon_Y) * (BLOCK_WIDTH) + ((H_Cnt + 10'd1) - weapon_X)) : 12'd0;

    always_ff@(posedge CLK_25MHz or negedge RESET) begin
        if(!RESET) vga_data <= 12'h000;
        else begin
            if(dataValid) begin
                if(Edge_Area)  vga_data <= 12'h88f;
                else if(Ground_Area) vga_data <= 12'h866;
                else if(Weapon_Area && (boomROM_out != 12'h00f || boneROM_out != 12'h00f)) begin
                    if(Weapon) vga_data <= boomROM_out;
                    else vga_data <= boneROM_out;
                end
                else if(Cat_Area && catROM_out != 12'h00f) vga_data <= catROM_out;
                else if(Dog_Area && dogROM_out != 12'h00f) begin
                    if(dogHide) vga_data <= {3{4'b1100}};
                    else vga_data <= dogROM_out;
                end
                else if(V_Line_Area) begin
                    if(V_Cnt[3:0] <= 4'd7) vga_data <= 12'hfff;
                    else vga_data <= 12'h000;
                end
                else if(H_Line_Area) begin
                    if(H_Cnt[3:0] <= 4'd7) vga_data <= 12'hfff;
                    else vga_data <= 12'h000;
                end
                else if(Explotion_Area && incident[1]) vga_data <= 12'hfa0;
                else if(Explotion_Area && incident[3]) vga_data <= 12'hfa0;
                else if(Wall_Area) begin
                    if(V_Cnt >= 10'd300) vga_data <= 12'hbbb;
                    else begin
                        case(wallHigh)
                            3'd0: vga_data <= (V_Cnt >= 10'd0  ) ? 12'hbbb : 12'hfff;
                            3'd1: vga_data <= (V_Cnt >= 10'd60 ) ? 12'hbbb : 12'hfff;
                            3'd2: vga_data <= (V_Cnt >= 10'd120) ? 12'hbbb : 12'hfff;
                            3'd3: vga_data <= (V_Cnt >= 10'd180) ? 12'hbbb : 12'hfff;
                            3'd4: vga_data <= (V_Cnt >= 10'd240) ? 12'hbbb : 12'hfff;
                            3'd5: vga_data <= (V_Cnt >= 10'd300) ? 12'hbbb : 12'hfff;
                            default: vga_data <= (V_Cnt >= 10'd300) ? 12'hbbb : 12'hfff;
                        endcase
                    end
                end
                else vga_data <= 12'hfff;
            end
            else vga_data <= 12'h000;
        end
    end
endmodule
// 七段顯示器控制
module Seg_Display(Seg_L, Seg_R, Seg_En_L, Seg_En_R, Power, Chance, Life, GameLevel, Wind, CLK_60Hz, RESET);
    output  [7:0]   Seg_L, Seg_R;
    output  [3:0]   Seg_En_L, Seg_En_R;
    input   [3:0]   Power;
    input   [3:0]   Chance;
    input   [3:0]   Life;
    input           GameLevel;
    input           Wind;
    input           CLK_60Hz, RESET;

    logic   [7:0]   Seg_L, Seg_R;
    logic   [3:0]   Seg_En_L, Seg_En_R;
    logic   [3:0]   seg_l_value, seg_r_value;

    always_ff@(posedge CLK_60Hz or negedge RESET) begin
        if(!RESET) {Seg_En_L, Seg_En_R} <= 8'b1000_1000;
        else {Seg_En_L, Seg_En_R} <= {Seg_En_R[0], Seg_En_L, Seg_En_R[3:1]};
    end

    always_comb begin
        case(Seg_En_L)
        4'b1000: seg_l_value = (GameLevel) ? 4'd2 : 4'd1;
        4'b0100: seg_l_value = Power;
        4'b0010: seg_l_value = 4'd15;
        4'b0001: seg_l_value = (Wind & GameLevel) ? 4'd1 : 4'd0;
        default: seg_l_value = 4'd15;
        endcase
    end

    always_comb begin
        case(seg_l_value)
            4'd0: Seg_L = 8'b11111100;
            4'd1: Seg_L = 8'b01100000;
            4'd2: Seg_L = 8'b11011010;
            4'd3: Seg_L = 8'b11110010;
            4'd4: Seg_L = 8'b01100110;
            4'd5: Seg_L = 8'b10110110;
            4'd6: Seg_L = 8'b10111110;
            4'd7: Seg_L = 8'b11100100;
            4'd8: Seg_L = 8'b11111110;
            4'd9: Seg_L = 8'b11110110;
            default: Seg_L = 8'b00000000; 
        endcase
    end

    always_comb begin
        case(Seg_En_L)
        4'b1000: seg_r_value = Chance;
        4'b0100: seg_r_value = 4'd15;
        4'b0010: seg_r_value = 4'd15;
        4'b0001: seg_r_value = Life;
        default: seg_r_value = 4'd15;
        endcase
    end

    always_comb begin
        case(seg_r_value)
            4'd0: Seg_R = 8'b11111100;
            4'd1: Seg_R = 8'b01100000;
            4'd2: Seg_R = 8'b11011010;
            4'd3: Seg_R = 8'b11110010;
            4'd4: Seg_R = 8'b01100110;
            4'd5: Seg_R = 8'b10110110;
            4'd6: Seg_R = 8'b10111110;
            4'd7: Seg_R = 8'b11100100;
            4'd8: Seg_R = 8'b11111110;
            4'd9: Seg_R = 8'b11110110;
            default: Seg_R = 8'b00000000; 
        endcase
    end
endmodule

// LED控制
module LED_Display(LED, gameState, incident, CLK_2Hz, RESET);
    output  logic[15:0] LED;
    input   GameState   gameState;
    input               CLK_2Hz, RESET;
    input   [3:0]       incident;       // 爆炸的攻擊、無爆炸的攻擊、爆炸的落空、無爆炸的落空
    
    always_ff@(posedge CLK_2Hz or negedge RESET) begin
        if(!RESET) LED <= 16'b0000_0000_0000_0000;
        else begin
            if(gameState == SUCCESS) begin
                if(LED == 16'b1111_1111_1111_1111) LED <= 16'b1111_1111_0000_0000;
                else LED <= ~LED;
            end
            else if(gameState == FAIL) begin
                if(LED == 16'b1001_1001_1001_1001 || LED == 16'b1111_1111_1111_1111) LED <= 16'b1000_0000_0000_0000;
                else LED <= {LED[0], LED[15:1]};
            end
            else if(incident[3] | incident[2]) LED <= 16'b1111_1111_1111_1111;
            else if(incident[1] || incident[0]) LED <= 16'b1001_1001_1001_1001;
            else LED <= LED;
        end
    end
endmodule

// 控制遊戲狀態、狗生命、貓機會
module GameState_Control(gameState, Chance, Life, GameLevel, FPGA_CLK, isS2, Weapon, incident, CLK_2Hz, RESET);
    output  GameState   gameState;
    output  [3:0]       Chance;
    output  [3:0]       Life;
    input               GameLevel;
    input               isS2;
    input               Weapon;
    input   [3:0]       incident;      // 爆炸的攻擊、無爆炸的攻擊、爆炸的落空、無爆炸的落空
    input               CLK_2Hz, FPGA_CLK, RESET;

    logic   [3:0]       Chance;
    logic   [3:0]       Life;


    logic isS2_latency;
    always_ff@(posedge FPGA_CLK or negedge RESET) begin
        if(!RESET)                                 isS2_latency<=1'b0;
        else if(|incident)                          isS2_latency<=1'b0;
        else if(isS2)                              isS2_latency<=1'b1;
        else                                      isS2_latency<=isS2_latency;
    end


    always_ff@(posedge CLK_2Hz or negedge RESET) begin
        if(!RESET) {gameState, Chance, Life} <= {MOVE, 4'd5, 4'd9};
        else begin
            case(gameState)
            MOVE: begin
                if(isS2_latency) {gameState, Chance, Life} <= {THROW, Chance - 4'd1, Life};
                else {gameState, Chance, Life} <= {gameState, Chance, Life};
            end
            THROW: begin
                if(incident[3] | incident[2]) begin
                    if(Weapon) begin
                        if(Life <= 4'd4) {gameState, Chance, Life} <= {SUCCESS, Chance, 4'd0};
                        else if(Chance == 4'd0 && Life > 4'd4) {gameState, Chance, Life} <= {FAIL, Chance, Life - 4'd4};
                        else {gameState, Chance, Life} <= {MOVE, Chance, Life - 4'd4};
                    end
                    else begin
                        if(Life <= 4'd2) {gameState, Chance, Life} <= {SUCCESS, Chance, 4'd0};
                        else if(Chance == 4'd0 && Life > 4'd2) {gameState, Chance, Life} <= {FAIL, Chance, Life - 4'd2};
                        else {gameState, Chance, Life} <= {MOVE, Chance, Life - 4'd2};
                    end
                end
                else if(incident[1] || incident[0]) begin
                    if(Chance == 4'd0) {gameState, Chance, Life} <= {FAIL, 4'd0, Life};
                    else {gameState, Chance, Life} <= {MOVE, Chance, Life};
                end
                else {gameState, Chance, Life} <= {gameState, Chance, Life};
            end
            SUCCESS: {gameState, Chance, Life} <= {gameState, Chance, Life};
            FAIL: {gameState, Chance, Life} <= {gameState, Chance, Life};
            endcase
        end
    end
endmodule
// 控制障礙物高度
module Wall_Control(wallHigh, wallHigh_next, gameState, GameLevel, CLK_1Hz, RESET);
    output  logic[2:0]  wallHigh, wallHigh_next;
    input   GameState   gameState;
    input               GameLevel;
    input               CLK_1Hz, RESET;

    logic               moveUp, moveUp_next;

    always_ff@(posedge CLK_1Hz or negedge RESET) begin
        if(!RESET) {wallHigh, moveUp} <= {3'd5, 1'b1};
        else {wallHigh, moveUp} <= {wallHigh_next, moveUp_next};
    end

    always_comb begin
        if(GameLevel) begin
            if(gameState == MOVE || gameState == THROW) begin
                if(moveUp) begin
                    if(wallHigh == 3'd0) {wallHigh_next, moveUp_next} = {3'd1, 1'b0};
                    else {wallHigh_next, moveUp_next} = {wallHigh - 3'd1, 1'b1};
                end
                else begin
                    if(wallHigh == 3'd5) {wallHigh_next, moveUp_next} = {3'd6, 1'b1};
                    else {wallHigh_next, moveUp_next} = {wallHigh + 3'd1, 1'b0};
                end
            end
            else {wallHigh_next, moveUp_next} = {wallHigh, moveUp};
        end
        else {wallHigh_next, moveUp_next} = {3'd5, 1'b1};
    end
endmodule

// 控制狗移動、隱身，狗的座標以左上角為準
module Dog_Control(dog, dog_next, dogHide, gameState, GameLevel, CLK_1Hz, CLK_2Hz, RESET);
    output  Position.Out    dog, dog_next;
    output                  dogHide;
    input   GameState       gameState;
    input                   GameLevel;
    input                   CLK_1Hz, CLK_2Hz, RESET;

    logic                   dogHide;
    logic                   moveLeft, moveLeft_next;

    always_comb begin
        if(gameState == MOVE || gameState == THROW) begin
            if(moveLeft) begin
                if(dog.X <= 5'd7) {dog_next.X, dog_next.Y, moveLeft_next} = {5'd8, 4'd6, 1'b0};
                else {dog_next.X, dog_next.Y, moveLeft_next} = {dog.X - 5'd1, 4'd6, 1'b1};
            end
            else begin
                if(dog.X >= 5'd14) {dog_next.X, dog_next.Y, moveLeft_next} = {5'd13, 4'd6, 1'b1};
                else {dog_next.X, dog_next.Y, moveLeft_next} = {dog.X + 5'd1, 4'd6, 1'b0};
            end
        end
        else {dog_next.X, dog_next.Y, moveLeft_next} = {dog.X, dog.Y, moveLeft};
    end

    always_ff@(posedge CLK_1Hz or negedge RESET) begin
        if(!RESET) {dog.X, dog.Y, moveLeft} <= {5'd14, 4'd6, 1'b1};
        else {dog.X, dog.Y, moveLeft} <= {dog_next.X, dog_next.Y, moveLeft_next};
    end

    always_ff@(posedge CLK_2Hz or negedge RESET) begin
        if(!RESET) dogHide <= 1'b0;
        else begin
            if(GameLevel && (gameState == MOVE || gameState == THROW)) dogHide <= ~dogHide;
            else dogHide <= 1'b0;
        end
    end
endmodule

// 螢幕座標同步
module SyncGeneration(H_Sync, V_Sync, dataValid, H_Cnt, V_Cnt, CLK_25MHz, RESET);
    output          H_Sync, V_Sync;
    output          dataValid;
    output  [9:0]   H_Cnt, V_Cnt;
    input           CLK_25MHz, RESET;

    parameter       H_SP_END = 96;
    parameter       H_BP_END = 144;
    parameter       H_FP_START = 785;
    parameter       H_TOTAL = 800;
   
    parameter       V_SP_END = 2;
    parameter       V_BP_END = 35;
    parameter       V_FP_START = 516;
    parameter       V_TOTAL = 525;

    logic   [9:0]   x_cnt, y_cnt;
    logic           h_valid, v_valid;
     
    assign H_Sync = ((x_cnt > H_SP_END)) ? 1'b1 : 1'b0;
    assign V_Sync = ((y_cnt > V_SP_END)) ? 1'b1 : 1'b0;
    assign h_valid = ((x_cnt > H_BP_END) & (x_cnt <= H_FP_START)) ? 1'b1 : 1'b0;
    assign v_valid = ((y_cnt > V_BP_END) & (y_cnt <= V_FP_START)) ? 1'b1 : 1'b0;
    assign dataValid = ((h_valid == 1'b1) & (v_valid == 1'b1)) ? 1'b1 :  1'b0;
    assign H_Cnt = ((h_valid == 1'b1)) ? x_cnt - H_BP_END : 10'b0;
    assign V_Cnt = ((v_valid == 1'b1)) ? y_cnt - V_BP_END : 10'b0; 
    
    always_ff@(posedge CLK_25MHz or negedge RESET) begin
        if (!RESET) x_cnt <= 10'd1;
        else begin
            if(x_cnt == H_TOTAL) x_cnt <= 10'd1;
            else x_cnt <= x_cnt + 1;
        end
    end
   
    always_ff@(posedge CLK_25MHz or negedge RESET) begin
        if(!RESET) y_cnt <= 10'd1;
        else begin
            if(y_cnt == V_TOTAL & x_cnt == H_TOTAL) y_cnt <= 1;
            else if (x_cnt == H_TOTAL) y_cnt <= y_cnt + 1;
            else y_cnt <= y_cnt;
        end
    end
endmodule

// 控制貓移動
module Cat_Control(cat, cat_next, Key, gameState, GameLevel, CLK_1Hz, FPGA_CLK, RESET);
    output  Position.Out    cat;
    output  Position.Out    cat_next;
    input   GameState       gameState;
    input                   GameLevel;
    input                   CLK_1Hz, FPGA_CLK, RESET;
    input wire [1:0] Key;
    
    always_ff@(posedge FPGA_CLK or negedge RESET) begin
        if(!RESET)  {cat_next.X, cat_next.Y} = {5'd0, 4'd7};
        else if(gameState == MOVE || gameState == THROW) begin
           case(Key)
               KEY_J: {cat_next.X, cat_next.Y}=(cat.X)?      {cat.X-5'd1, 4'd7}:{cat.X, 4'd7};
               KEY_K: {cat_next.X, cat_next.Y}=(cat.X!=4'd5)?{cat.X+5'd1, 4'd7}:{cat.X, 4'd7};
               default : {cat_next.X, cat_next.Y} = {cat_next.X, 4'd7};
           endcase           
        end
        else   {cat_next.X, cat_next.Y} = {cat.X, 4'd7};
    end
    
    always_ff@(posedge CLK_1Hz or negedge RESET) begin
        if(!RESET)              {cat.X, cat.Y} <= {5'd0, 4'd7};                //RESET
        else if(!GameLevel)      {cat.X, cat.Y} <= {5'd0, 4'd7};               // level1
        else                    {cat.X, cat.Y} <= {cat_next.X, cat_next.Y};   //level2
    end
endmodule

// 讀取鍵盤
module PS2_Reader(Key, PS2_CLK, PS2_Data, FPGA_CLK, RESET);
    output  KeyType     Key;
    input               PS2_CLK, PS2_Data;
    input               FPGA_CLK, RESET;

    logic               PS2_CLK0, PS2_CLK1, PS2_CLK2;
    logic               PS2_CLK_neg;
    logic               ps2_state;

    always @ (posedge FPGA_CLK or negedge RESET)begin
        if (!RESET)
            {PS2_CLK0, PS2_CLK1, PS2_CLK2} <= 3'd0;
        else begin
            PS2_CLK0 <= PS2_CLK;
            PS2_CLK1 <= PS2_CLK0;
            PS2_CLK2 <= PS2_CLK1;
        end
    end
    assign PS2_CLK_neg = ~PS2_CLK1 & PS2_CLK2;
    reg [3:0]num;
    reg [7:0]data_temp;
    //get the data from ps2
    always @ (posedge FPGA_CLK, negedge RESET)begin
        if (!RESET)begin
            num <= 4'd0;
            data_temp <= 8'd0;
        end
        else if (PS2_CLK_neg)begin
            if (num == 0) 
                num <= num + 1'b1;
            else if (num <= 8) begin
                num <= num + 1'b1;
                data_temp[num-1] <= PS2_Data;
            end
            else if (num == 9) 
                num <= num + 1'b1;
            else num <= 4'd0;
        end
    end
    // to avoid error for pushing the button for a long time
    reg ps2_loosen;
    reg [7:0]ps2_byte;
    always @ (posedge FPGA_CLK, negedge RESET)begin
        if (!RESET)begin
            ps2_state <= 1'b0;
            ps2_loosen<= 1'b0;
        end
        else if (num == 4'd10)begin
            if (data_temp == 8'hf0) 
                ps2_loosen <= 1'b1;
            else begin
                if (ps2_loosen) begin
                    ps2_state <= 1'b0;
                    ps2_loosen<= 1'b0;
                end
                else begin
                    ps2_state <= 1'b1;
                    ps2_byte <= data_temp;
                end
            end
        end
    end
    
    reg ps2state_reg;
    wire flag;
    always @ (posedge FPGA_CLK)
        ps2state_reg <= ps2_state;
    //after the button is released
    assign flag = (ps2state_reg) & (~ps2_state);
    
    //- NONE_KEY: 預設，沒有按下任何鍵    
    //- KEY_J: 按下J，玩家左移                     
    //- KEY_K: 按下K，玩家右移                     
    //- KEY_B: 按下B，手動引爆炸彈
    always @ (posedge FPGA_CLK or negedge RESET)begin
        if (!RESET)begin
            Key <= NONE_KEY;
        end
        else if (flag)begin
            case (ps2_byte)
                8'h3B:  Key <= KEY_J;
                8'h42:  Key <= KEY_K;
                8'h32:  Key <= KEY_B;
                default: Key <= NONE_KEY;
            endcase
        end
        else     Key <= NONE_KEY;
    end

endmodule

// 控制武器種類、移動、爆炸
module Weapon_Control(weapon, Power, incident, gameState, GameLevel, Wind, Weapon, isS0, isS3, isS2, cat_next, dog, dog_next, dogHide, wallHigh, Key, FPGA_CLK, CLK_25Hz, CLK_2Hz, CLK_1Hz, RESET);
    output  Position.Out    weapon;
    output  logic[3:0]      Power;
    output  logic[3:0]      incident; // 爆炸的攻擊、無爆炸的攻擊、爆炸的落空、無爆炸的落空
    input   GameState       gameState;
    input                   GameLevel, Wind, Weapon;
    input                   isS0, isS3, isS2;
    input   Position.In     cat_next;
    input   Position.In     dog, dog_next;
    input                   dogHide;
    input   [2:0]           wallHigh;
    input   KeyType         Key;
    input                   FPGA_CLK, CLK_25Hz, CLK_2Hz, CLK_1Hz, RESET;

    logic   [3:0]           velocity;
    logic                   keyB_latency;
    Position                weapon_next();
    Position                weapon_last();

    assign velocity = 4'd1 + Power + Wind;

    always_ff@(posedge CLK_25Hz or negedge RESET) begin
        if(!RESET) Power <= 4'd0;
        else begin
            if(isS0 && Power < 4'd4) Power <= Power + 4'd1;
            else if(isS3 && Power > 4'd0) Power <= Power - 4'd1;
            else Power <= Power;
        end
    end

    always_comb begin
        // gameState == MOVE時固定在貓頭上
        if(GameLevel && gameState == MOVE) {weapon_next.X, weapon_next.Y} = {cat_next.X, 4'd6} ;
        else if(!GameLevel && gameState == MOVE) {weapon_next.X, weapon_next.Y} = {5'd0, 4'd6} ;
        else if(gameState == THROW) begin
            // 越過牆
            if(weapon.X < 5'd6) {weapon_next.X, weapon_next.Y} = {weapon.X + velocity, weapon.Y - 4'd1};
            // 出界
            else if(weapon.X >= 5'd16) {weapon_next.X, weapon_next.Y} = {cat_next.X, 4'd6};
            // 未越過牆
            else {weapon_next.X, weapon_next.Y} = {weapon.X + velocity, weapon.Y + 4'd1};
        end
        // 僅在(gameState == SUCCESS || gameState == FAIL)觸發
        else {weapon_next.X, weapon_next.Y} = {5'd17, 4'd6};
    end

    always_ff@(posedge CLK_1Hz or negedge RESET) begin
        if(!RESET) begin
            {weapon.X, weapon.Y} <= {5'd0, 4'd6};
            {weapon_last.X, weapon_last.Y} <= {5'd0, 4'd6};
        end
        else begin
            {weapon.X, weapon.Y} <= {weapon_next.X, weapon_next.Y};
            {weapon_last.X, weapon_last.Y} <= {weapon.X, weapon.Y};
        end
    end

    always_ff @(posedge FPGA_CLK, negedge RESET) begin
        if(!RESET) keyB_latency <= 1'b0;
        else begin
            if (Key == KEY_B) keyB_latency <= 1'b1;
            else if( gameState==MOVE ) keyB_latency <= 1'b0;
            else keyB_latency <= keyB_latency;
        end
    end

    always_comb begin
        // 只在投擲狀態有效
        if(gameState == THROW) begin
            // 預判 出界
            if(weapon_next.X >= 5'd16 && weapon.Y != 4'd7) incident = 4'b0001;
            // 延判 撞到障礙物
            else if(weapon_last.X < 5'd6 && weapon.X >= 5'd6 && weapon.Y >= wallHigh) incident = 4'b0001;
            else if(GameLevel && Weapon) begin
                // 當下 武器砸到狗
                if(weapon.X == (dog.X + 5'd1) && weapon.Y == dog.Y) incident = 4'b1000;
                else if(weapon.X == (dog.X + 5'd1) && weapon.Y == (dog.Y + 4'd1)) incident = 4'b1000;
                else if((weapon.X + 5'd1) == (dog.X + 5'd1) && weapon.Y == dog.Y) incident = 4'b1000;
                else if((weapon.X + 5'd1) == (dog.X + 5'd1) && weapon.Y == (dog.Y + 4'd1)) incident = 4'b1000;
                // 延遲 主動引爆
                else if(keyB_latency) begin
                    if(weapon.X >= (dog.X - 5'd1) && weapon.X <= (dog.X + 5'd2) && weapon.Y >= (dog.Y - 5'd1)) incident = 4'b1000;
                    else incident = 4'b0010;
                end
                // 當下 武器落地
                else if(weapon.Y == 4'd7) begin
                    if(weapon.X == (dog.X - 5'd1) || weapon.X == (dog.X + 5'd2)) incident = 4'b1000;
                    else incident = 4'b0010;
                end
                else incident = 4'b0000;
            end
            else begin
                // 當下 武器砸到狗
                if(weapon.X == (dog.X + 5'd1) && weapon.Y == dog.Y) incident = 4'b0100;
                else if(weapon.X == (dog.X + 5'd1) && weapon.Y == (dog.Y + 4'd1)) incident = 4'b0100;
                else if((weapon.X + 5'd1) == (dog.X + 5'd1) && weapon.Y == dog.Y) incident = 4'b0100;
                else if((weapon.X + 5'd1) == (dog.X + 5'd1) && weapon.Y == (dog.Y + 4'd1)) incident = 4'b0100;
                // 當下 武器落地
                else if(weapon.Y == 4'd7) incident = 4'b0001;
                else incident = 4'b0000;
            end
        end
        else incident = 4'b000;
    end
endmodule