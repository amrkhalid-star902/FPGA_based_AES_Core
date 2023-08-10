`timescale 1ns / 1ps

`default_nettype none


module aes_decode_block(
    input wire clk,
    input wire reset,
    input wire next,
    
    input wire keylen,
    output wire [3:0] round_no,
    input wire [127:0] round_key,
    
    input wire [127:0] block,
    output wire [127:0] new_block,
    output wire ready
    );
    
    
    
    //Some constants and parameter defination
    localparam AES_128_BIT_KEY = 1'h0;
    localparam AES_256_BIT_KEY = 1'h1;
    
    localparam AES_128_ROUNDS = 4'ha;
    localparam AES_256_ROUNDS = 4'he;
    
    localparam NO_UPDATE = 3'h0;
    localparam INIT_UPDATE = 3'h1;
    localparam SBOX_UPDATE = 3'h2;
    localparam MAIN_UPDATE = 3'h3;
    localparam FINAL_UPDATE = 3'h4;
    
    localparam CTRL_IDLE = 2'h0;
    localparam CTRL_INIT = 2'h1;
    localparam CTRL_SBOX = 2'h2;
    localparam CTRL_MAIN = 2'h3;
    
    
    //Multplication functions for Inverse MixColumns
    
    
    //Multply by two function
    function [7:0] gm2(input [7:0] op);
        begin
            
            //xor by 1b if number exceed 0x80 to prevent overflow
            gm2 = {op[6:0] , 1'b0} ^ (8'h1b & {8{op[7]}});
        
        end
    endfunction
    
    
    
    //multplication by three function
    function [7:0] gm3(input [7:0] op);
        begin
            
            gm3 = gm2(op) ^ op;
            
        end
    endfunction
    
    
    //multplication by four function
    function [7:0] gm4(input [7:0] op);
        begin
            
            gm4 = gm2(gm2(op));
            
        end
    endfunction
    
    
    //multplication by eight function
    function [7:0] gm8(input [7:0] op);
        begin
            
            gm8 = gm2(gm4(op));
            
        end
    endfunction
    
    
    //multplication by nine function
    function [7:0] gm9(input [7:0] op);
        begin
            
            gm9 = gm8(op) ^ op;
            
        end
    endfunction
    
    
    //multplication by eleven function
    function [7:0] gm11(input [7:0] op);
        begin
            
            gm11 = gm8(op) ^ gm3(op);
            
        end
    endfunction
    
    
    //multplication by threeteen function
    function [7:0] gm13(input [7:0] op);
        begin
            
            gm13 = gm9(op) ^ gm4(op);
            
        end
    endfunction
    
    
    //multplication by fourteen function
    function [7:0] gm14(input [7:0] op);
        begin
            
            gm14 = gm8(op) ^ gm4(op) ^ gm2(op);
            
        end
    endfunction
    
    
    //mix words function
    function [31:0] mixw(input [31:0] w);
        
        reg[7:0] b0 , b1 , b2 , b3; 
        //mixed words
        reg[7:0] mb0 , mb1 , mb2 , mb3;
        begin
            
            b0 = w[31:24];
            b1 = w[23:16];
            b2 = w[15:8];
            b3 = w[7:0];
            
            mb0 = gm14(b0) ^ gm11(b1) ^ gm13(b2) ^ gm9(b3);
            mb1 = gm9(b0)  ^ gm14(b1) ^ gm11(b2) ^ gm13(b3);
            mb2 = gm13(b0) ^  gm9(b1) ^ gm14(b2) ^ gm11(b3);
            mb3 = gm11(b0) ^ gm13(b1) ^  gm9(b2) ^ gm14(b3);
            
            mixw = {mb0 , mb1 , mb2 , mb3};
            
        end
    endfunction
    
    
    //mix columns function
    function [127:0] inv_mixcolumns(input [127:0] data);
    
        reg[31:0] w0 , w1 , w2 , w3; 
        //invrse mixed columns
        reg[31:0] mw0 , mw1 , mw2 , mw3;
        
        begin
        
            w0 = data[127:96];
            w1 = data[95:64];
            w2 = data[63:32];
            w3 = data[31:0];
            
            mw0 = mixw(w0);
            mw1 = mixw(w1);
            mw2 = mixw(w2);
            mw3 = mixw(w3);
            
            inv_mixcolumns = {mw0 , mw1 , mw2 , mw3};
            
        end
    endfunction
    
    
    
    //inverse shift rows function
    function [127:0] inv_shiftrows(input [127:0] data);
        
        reg[31:0] w0 , w1 , w2 , w3; 
        reg[31:0] mw0 , mw1 , mw2 , mw3;
        begin
            
            w0 = data[127:96];
            w1 = data[95:64];
            w2 = data[63:32];
            w3 = data[31:0];
            
            mw0 = {w0[31:24] , w3[23:16] , w2[15:8] , w1[7:0]};
            mw1 = {w1[31:24] , w0[23:16] , w3[15:8] , w2[7:0]};
            mw2 = {w2[31:24] , w1[23:16] , w0[15:8] , w3[7:0]};
            mw3 = {w3[31:24] , w2[23:16] , w1[15:8] , w0[7:0]};
            
            inv_shiftrows = {mw0 , mw1 , mw2 , mw3};
            
        end
    endfunction
    
    
    
    function [127:0] addroundkey(input [127:0] data , input [127:0] roundkey);
        begin
            
            addroundkey= data ^ roundkey;
            
        end
    endfunction
    
    
    //Update variables registers
    
    
    //Subbyte network registers
    reg [1:0]   sword_ctr_reg;
    reg [1:0]   sword_ctr_new;
    reg         sword_ctr_we;
    reg         sword_ctr_rst;
    reg         sword_ctr_inc;
    
    
    //roundkey network registers
    reg [3:0]   round_ctr_reg;
    reg [3:0]   round_ctr_new;
    reg         round_ctr_we;
    reg         round_ctr_set;
    reg         round_ctr_dec;
    
    
    
    reg [127:0]   block_new;
    reg [31:0]    block_w0_reg;
    reg [31:0]    block_w1_reg;
    reg [31:0]    block_w2_reg;
    reg [31:0]    block_w3_reg;
    reg           block_w0_we;
    reg           block_w1_we;
    reg           block_w2_we;
    reg           block_w3_we;
    
    
    reg           ready_reg;
    reg           ready_new;
    reg           ready_we;
    
    
    reg [1:0]     dec_ctrl_reg;
    reg [1:0]     dec_ctrl_new;
    reg           dec_ctrl_we;
    
    
    //wires
    reg [31:0]    tmp_sboxw;
    wire [31:0]    new_sboxw;
    reg [2:0]     update_type;
    
    
    // Instantiations
    aes_inv_sbox   inv_sbox_inst(.sboxw(tmp_sboxw) , .new_sboxw(new_sboxw));
    
    
    //Connection of some output ports   
    assign round_no = round_ctr_reg;
    assign new_block = {block_w0_reg , block_w1_reg , block_w2_reg , block_w3_reg};
    assign ready = ready_reg;
    
    
    //Update functionallity of all registers in decryption core
    always@(posedge clk or negedge reset)
    begin
        if(reset == 0)
            begin
                
                block_w0_reg <= 32'h0;
                block_w1_reg <= 32'h0;
                block_w2_reg <= 32'h0;
                block_w3_reg <= 32'h0;
                sword_ctr_reg <= 4'h0;
                round_ctr_reg <= 4'h0;
                ready_reg <= 1'b1;
                dec_ctrl_reg <= CTRL_IDLE;
            
            end
        else
            begin
                
                if(block_w0_we)
                    block_w0_reg <= block_new[127:96];
                
                if(block_w1_we)
                    block_w1_reg <= block_new[95:64];            
     
                if(block_w2_we)
                    block_w2_reg <= block_new[63:32];   
                        
                if(block_w3_we)
                    block_w1_reg <= block_new[31:0];  
                        
                if(sword_ctr_we)
                    sword_ctr_reg <= sword_ctr_new;   
    
                if(round_ctr_we)
                    round_ctr_reg <= round_ctr_new;
                        
                if(ready_reg)
                    ready_reg <= ready_new;                                               
                    
                if(dec_ctrl_we)
                    dec_ctrl_reg <= dec_ctrl_new;
                        
            end  
    end
    
    //round key generator logic
    always@(*)
        begin : round_logic
            
            reg [127:0] old_block , inv_shiftrows_block , inv_mixcolumns_block;
            reg [127:0] addkey_block;
            
            inv_shiftrows_block = 128'h0;
            inv_mixcolumns_block = 128'h0;
            addkey_block = 128'h0;
            block_new = 128'h0;
            tmp_sboxw = 32'h0;
            block_w0_we = 1'b0;
            block_w1_we = 1'b0;
            block_w2_we = 1'b0;
            block_w3_we = 1'b0;
            
            old_block = {block_w0_reg , block_w2_reg , block_w2_reg , block_w3_reg};
            
            case(update_type)
                
                //Init Round
                INIT_UPDATE:
                    begin
                        
                        old_block = block;
                        addkey_block = addroundkey(old_block , round_key);
                        inv_shiftrows_block = inv_shiftrows(addkey_block);
                        block_new = inv_shiftrows_block;
                        block_w0_we = 1'b1;
                        block_w1_we = 1'b1;
                        block_w2_we = 1'b1;
                        block_w3_we = 1'b1;
                                                
                    end
                    
              SBOX_UPDATE:
                begin
                    
                    block_new = {new_sboxw , new_sboxw , new_sboxw , new_sboxw};
                    
                    case(sword_ctr_reg)
                        
                        2'h0:
                            begin
                                
                                tmp_sboxw = block_w0_reg;
                                block_w0_reg = 1'b1;
                                
                            end

                        2'h1:
                            begin
                                
                                tmp_sboxw = block_w1_reg;
                                block_w1_reg = 1'b1;
                                
                            end         
                            
                        2'h2:
                            begin
                                    
                                tmp_sboxw = block_w2_reg;
                                block_w2_reg = 1'b1;
                                    
                           end          
                        2'h3:
                            begin
                                   
                                tmp_sboxw = block_w3_reg;
                                block_w3_reg = 1'b1;
                                   
                            end                                                        
                    endcase
                   
                end
                
                MAIN_UPDATE:
                    begin
                        addkey_block = addroundkey(old_block , round_key);
                        inv_mixcolumns_block = inv_mixcolumns(addkey_block);
                        inv_shiftrows_block = inv_shiftrows(inv_mixcolumns_block);
                        block_new = inv_shiftrows_block;
                        block_w0_we = 1'b1;
                        block_w1_we = 1'b1;
                        block_w2_we = 1'b1;
                        block_w3_we = 1'b1;
                                          
                    end
                    
               
                FINAL_UPDATE:
                    begin
                        
                        block_new = addroundkey(old_block , round_key);
                        block_w0_we = 1'b1;
                        block_w1_we = 1'b1;
                        block_w2_we = 1'b1;
                        block_w3_we = 1'b1;
                        
                    end
                    
               default:
                begin
                
                end
                
            endcase
            
        end
    
    //subbyte counter with reset logic
    always@(*)
        begin
            
             sword_ctr_new = 2'h0;
             sword_ctr_we = 1'b0;
             
             if(sword_ctr_rst)
                begin
                    sword_ctr_new = 2'h0;
                    sword_ctr_we = 1'b1;           
                
                end
             else if(sword_ctr_inc)
                begin
                    
                    sword_ctr_new = sword_ctr_reg + 1;
                    sword_ctr_we = 1'b1;
                
                end
        end
        
        
        //roundkey counter with reset logic
        always@(*)
        begin
            
             round_ctr_new = 4'h0;
             round_ctr_we = 1'b0;
             
             if(round_ctr_set)
                begin
                    
                    if(keylen == AES_256_BIT_KEY)
                        begin
                            
                            round_ctr_new = AES_256_ROUNDS;
                            
                        end
                    else
                        begin
                        
                            round_ctr_new = AES_128_ROUNDS;
                            
                        end
                        
                   round_ctr_we = 1'b1;
                   
                end
             else if(round_ctr_dec)
                begin
                        
                    round_ctr_new = round_ctr_reg - 1'b1;
                    round_ctr_we = 1'b1;
                        
                end
        end
    //Finite State Machine that controls decode operation        
    always@(*)
        begin
            
            sword_ctr_inc = 1'b0;
            sword_ctr_rst = 1'b0;
            round_ctr_dec = 1'b0;
            round_ctr_set = 1'b0;
            ready_new = 1'b0;
            ready_we = 1'b0;
            update_type = NO_UPDATE;
            dec_ctrl_new = CTRL_IDLE;
            dec_ctrl_we = 1'b0;
            
            case(dec_ctrl_reg)
            
                CTRL_IDLE:
                    begin
                    
                        if(next)
                            begin
                                
                                round_ctr_set = 1'b1;
                                ready_new = 1'b0;
                                ready_we = 1'b1;
                                dec_ctrl_new = CTRL_INIT;
                                dec_ctrl_we = 1'b1;
                                
                            end
                    end
                    
                CTRL_INIT:
                    begin
                        
                        sword_ctr_rst = 1'b1;
                        update_type = INIT_UPDATE;
                        dec_ctrl_new = CTRL_SBOX;
                        dec_ctrl_we = 1'b1;
                        
                    end
                    
                CTRL_SBOX:
                    begin
                        
                        sword_ctr_inc = 1'b1;
                        update_type = SBOX_UPDATE;
                        if(sword_ctr_reg == 2'h3)
                            begin
                                
                                round_ctr_dec = 1'b1;
                                dec_ctrl_new = CTRL_MAIN;
                                dec_ctrl_we = 1'b1;
                                
                            end
                    end
                    
                CTRL_MAIN:
                    begin
                        
                        sword_ctr_rst = 1'b1;
                        if(sword_ctr_rst > 0)
                            begin
                                
                                update_type = MAIN_UPDATE;
                                dec_ctrl_new = CTRL_SBOX;
                                dec_ctrl_we = 1'b1;
                                
                            end
                            
                        else
                            begin
                                
                                update_type = FINAL_UPDATE;
                                ready_new = 1'b1;
                                ready_we = 1'b1;
                                dec_ctrl_new = CTRL_IDLE;
                                dec_ctrl_we = 1'b1;
                            end
                    end
                    
                default:
                    begin    
                    
                    end
                    
            endcase
            
        end
    
endmodule
