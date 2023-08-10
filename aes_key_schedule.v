`timescale 1ns / 1ps

`default_nettype none



module aes_key_schedule(
    input wire clk,
    input wire reset,
    
    input wire [255:0] key,
    input wire keylen,
    input wire init,
    
    input wire [3:0] round,
    output wire [127:0] round_key,    
    output wire ready,
    
    output wire [31:0] sboxw,
    input wire [31:0] new_sboxw
    );
    
    
   /*
    *  Parameters
   */
    localparam AES_128_BIT_KEY = 1'h0;
    localparam AES_256_BIT_KEY = 1'h1;
    
    localparam AES_128_ROUNDS = 4'ha;
    localparam AES_256_ROUNDS = 4'he;
    
    localparam CTRL_IDLE = 2'h0;
    localparam CTRL_INIT = 2'h1;
    localparam CTRL_GENERATE = 2'h2;
    localparam CTRL_DONE = 2'h3;
    
   /*
    *  registers
   */
    reg [127:0] key_mem [0:14];
    reg [127:0] key_mem_new;
    reg         key_mem_we;
    
    reg [127:0] prev_key0_reg;
    reg [127:0] prev_key0_new;
    reg         prev_key0_we;
    
    reg [127:0] prev_key1_reg;
    reg [127:0] prev_key1_new;
    reg         prev_key1_we;
    
    
    //roundkey network registers
    reg [3:0]   round_ctr_reg;
    reg [3:0]   round_ctr_new;
    reg         round_ctr_we;
    reg         round_ctr_rst;
    reg         round_ctr_inc;
    
    reg [2:0]   key_mem_ctrl_reg;
    reg [2:0]   key_mem_ctrl_new;
    reg         key_mem_ctrl_we;
    
    
    reg         ready_reg;
    reg         ready_new;
    reg         ready_we;
    
    reg [7:0]   rcon_reg;
    reg [7:0]   rcon_new;
    reg         rcon_we;
    reg         rcon_set;
    reg         rcon_next;
    
    
    //Wires
    reg [31:0]  tmp_sboxw;
    reg         round_key_update;
    reg [127:0] tmp_round_key;
    
    
    //Connection of some output ports 
    assign round_key = tmp_round_key;
    assign ready = ready_reg;
    assign sboxw = tmp_sboxw;
    
    
   //Update functionallity of all registers 
   always@(posedge clk or negedge reset)
   begin : reg_update
   
    integer i;
    if(!reset)
        begin
        
            for(i = 0 ; i <= AES_256_ROUNDS ; i = i + 1)
                key_mem[i] <= 128'h0;
                
            ready_reg <= 1'b0;
            rcon_reg <= 8'h0;
            round_ctr_reg <= 4'h0;
            prev_key0_reg <= 128'h0;
            prev_key1_reg <= 128'h0;
            key_mem_ctrl_reg <= CTRL_IDLE;
            
        end
   
    else
        begin
        
            if(ready_we)
                ready_reg <= ready_new;
            
            if(rcon_we)
                rcon_reg <= rcon_new;
                
            if(round_ctr_we)
                round_ctr_reg <= round_ctr_new;
                
            if(key_mem_we)
                key_mem[round_ctr_reg] <= key_mem_new;
                
            if(prev_key0_we)
                prev_key0_reg <= prev_key0_new;    
                
            if(prev_key1_we)
                prev_key1_reg <= prev_key1_new; 
                    
            if(key_mem_ctrl_we)
                key_mem_ctrl_reg <= key_mem_ctrl_new;          
        end
   
   end

   always@(*)
   begin
   
    tmp_round_key = key_mem[round];
    
   end
   
   
   // The round key generator logic for AES-128 and AES-256.
   always@(*)
   begin : round_key_gen
   
     reg [31:0] w0 , w1 , w2 , w3 , w4 , w5 , w6 , w7;
     reg [31:0] k0 , k1 , k2 , k3;
     reg [31:0] rconw , rotword , kw , krw;
     
     //Default values
     key_mem_new = 128'h0;
     key_mem_we = 1'b0;
     prev_key0_new = 128'h0;
     prev_key0_we = 1'b0;
     prev_key1_new = 128'h0;
     prev_key1_we = 1'b0;
     
     k0 = 31'h0;
     k1 = 31'h0;
     k2 = 31'h0;
     k3 = 31'h0;
     
     rcon_set = 1'b1;
     rcon_next = 1'b0;
     
     //Perform Key schedule operations
     
     w0 = prev_key0_reg[127:96];
     w1 = prev_key0_reg[95:64];
     w2 = prev_key0_reg[63:32];
     w3 = prev_key0_reg[31:0];

     w4 = prev_key1_reg[127:96];
     w5 = prev_key1_reg[95:64];
     w6 = prev_key1_reg[63:32];
     w7 = prev_key1_reg[31:0];
     
     rconw = {rcon_reg , 24'h0};
     tmp_sboxw = w7;
     //ROTWORD([w0 w1 w3 w4]) = [w1 w2 w3 w0]
     rotword = {new_sboxw[23:0] , new_sboxw[31:24]};
     krw = rotword ^ rconw;
     kw = new_sboxw;
     
     //Generate Round Key
     if(round_key_update)
        begin
            rcon_set = 1'b0;
            key_mem_we = 1'b1;
            case(keylen)
                
                AES_128_BIT_KEY:
                    begin
                    
                        if(round_ctr_reg == 0)
                            begin
                            
                                key_mem_new = key[255:128];
                                prev_key1_new = key[255:128];
                                prev_key1_we = 1'b1;
                                rcon_next = 1'b1;
                                
                            end
                            
                        else
                            begin
                                
                                k0 = w4 ^ krw;
                                k1 = w5 ^ w4 ^ krw;
                                k2 = w6 ^ w5 ^ w4 ^ krw;
                                k3 = w7 ^ w6 ^ w5 ^ w4 ^ krw;
                                
                                key_mem_new = {k0 , k1 , k2 , k3};
                                prev_key1_new = {k0 , k1 , k2 , k3};
                                prev_key1_we = 1'b1;
                                rcon_next = 1'b1;
                            
                            end    
                    end
                
                AES_256_BIT_KEY:
                    begin
                        if(round_ctr_reg == 0)
                            begin
                        
                                key_mem_new = key[255:128];
                                prev_key0_new = key[255:128];
                                prev_key0_we = 1'b1;
                            
                            end 
                            
                        else if (round_ctr_reg == 1)
                            begin
                            
                                key_mem_new = key[127:0];
                                prev_key1_new = key[127:0];
                                prev_key1_we = 1'b1;
                                rcon_next = 1'b1;   
                                                 
                            end
                            
                        else
                            begin
                                
                                if (round_ctr_reg[0] == 0)
                                    begin
                                    
                                        k0 = w4 ^ krw;
                                        k1 = w5 ^ w4 ^ krw;
                                        k2 = w6 ^ w5 ^ w4 ^ krw;
                                        k3 = w7 ^ w6 ^ w5 ^ w4 ^ krw;                              
                                            
                                    end
                                    
                                else
                                    begin
                                    
                                        k0 = w4 ^ kw;
                                        k1 = w5 ^ w4 ^ kw;
                                        k2 = w6 ^ w5 ^ w4 ^ kw;
                                        k3 = w7 ^ w6 ^ w5 ^ w4 ^ kw;                                                                          
                                    
                                    end   
                                    
                                key_mem_new = {k0 , k1 , k2 , k3};
                                prev_key1_new = {k0 , k1 , k2 , k3};
                                prev_key1_we = 1'b1;
                                prev_key0_new = prev_key1_reg;
                                prev_key0_we = 1'b1;    
                            end
                            
                    end
                default:
                    begin
                    
                    end        
                    
            endcase
                
        
        end
   
   end
   
   
   // Caclulates the rcon value for the different key expansion
   always@(*)
   begin : rcon_logic
   
     reg [7:0] tmp_rcon;
     rcon_new = 8'h00;
     rcon_we = 1'b0;
     
     tmp_rcon = {rcon_reg[6:0] , 1'b0} ^ (8'h1b & {8{rcon_reg[7]}});  
     
     if(rcon_set)
        begin
            
            rcon_new = 8'h8d;
            rcon_we = 1'b1;
            
        end
     if(rcon_next)
        begin
            
            rcon_new = tmp_rcon;
            rcon_we = 1'b1;
        
        end   
        
   end
   
   // The round counter logic with increase and reset.
   always@(*)
   begin
     round_ctr_new = 4'h0;
     round_ctr_we = 1'b0;
     
     if(round_ctr_rst)
        begin
            
           round_ctr_new = 4'h0;
           round_ctr_we = 1'b1;
               
        end   
     else if (round_ctr_inc)
        begin
            
            round_ctr_new = round_ctr_reg + 1'b1;
            round_ctr_we = 1'b1;
            
        end
        
   end
   
   
   // The FSM that controls the round key generation.
   always@(*)
   begin : key_mem_ctrl
   
     reg [3:0] num_rounds;
     
     //Default values
     ready_new = 1'b0;
     ready_we = 1'b0;
     round_key_update = 1'b0;
     round_ctr_rst = 1'b0;
     round_ctr_inc = 1'b0;
     key_mem_ctrl_new = CTRL_IDLE;
     key_mem_ctrl_we = 1'b0;
     
     if(keylen == AES_256_BIT_KEY)
        begin
             
             num_rounds = AES_256_ROUNDS;
             
        end
         
     else if(keylen == AES_128_BIT_KEY)
         begin
                 
             num_rounds = AES_128_ROUNDS;
                 
         end
          
     case(key_mem_ctrl_reg)
        
        CTRL_IDLE:
            begin
                
                if(init)
                    begin
                        
                        ready_new = 1'b0;
                        ready_we = 1'b1;
                        key_mem_ctrl_new = CTRL_INIT;
                        key_mem_ctrl_we = 1'b1;
                        
                    end
            
            end
        
        CTRL_INIT:
            begin
                
                round_ctr_rst = 1'b1;
                key_mem_ctrl_new = CTRL_GENERATE;
                key_mem_ctrl_we = 1'b1;
                
            end  
        
        CTRL_GENERATE:
            begin
                
                round_ctr_inc = 1'b1;
                round_key_update = 1'b1;
                if(round_ctr_reg == num_rounds)
                    begin
                        
                        key_mem_ctrl_new = CTRL_DONE;
                        key_mem_ctrl_we = 1'b1;
                        
                    end 
            end
            
        CTRL_DONE:
            begin
            
                ready_new = 1'b1;
                ready_we = 1'b1;
                key_mem_ctrl_new = CTRL_IDLE;
                key_mem_ctrl_we = 1'b1;             
            
            end
        
        default:
            begin
            
            end
            
     endcase
     
   end
endmodule
