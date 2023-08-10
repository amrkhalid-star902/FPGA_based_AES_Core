`timescale 1ns / 1ps

`default_nettype none


module aes_core(
    
    input wire clk,
    input wire reset,
    
    input wire enc_dec,
    input wire init,
    input wire next,
    output wire ready,
    
    input wire [255:0] key,
    input wire keylen,
    
    input wire [127:0] block,
    output wire [127:0] result,
    output wire result_valid
    
    );
    
    //-------------------------------------------------------------
    // Some constants defination.
    //-------------------------------------------------------------
    localparam CTRL_IDLE  = 2'h0;
    localparam CTRL_INIT  = 2'h1;
    localparam CTRL_NEXT  = 2'h2;    
    
    
    //------------------------------------------------------------
    // Some Registers definations
    //------------------------------------------------------------
    reg [1:0] aes_core_ctrl_reg;
    reg [1:0] aes_core_ctrl_new;
    reg       aes_core_ctrl_we;
    
    
    reg      result_valid_reg;
    reg      result_valid_new;
    reg      result_valid_we;
    
    reg      ready_reg;
    reg      ready_new;
    reg      ready_we;
    
    
    
    //------------------------------------------------------------
    // Some wires declartion
    //------------------------------------------------------------
    reg          init_state;
    
    wire [127:0] round_key;
    wire         key_ready;
    
    reg          enc_next;
    wire [3:0]   enc_round_num;
    wire [127:0] enc_new_block;
    wire         enc_ready;
    wire [31:0]  enc_sboxw;
    
    reg          dec_next;
    wire [3:0]   dec_round_num;
    wire [127:0] dec_new_block;
    wire         dec_ready;
    
    
    reg [127:0]  muxed_new_block;
    reg [3:0]    muxed_round_num;
    reg          muxed_ready;
    
    wire [31:0] keymem_sboxw;
    
    //-----------------------------------------------------------
    //S-Box parameters
    //-----------------------------------------------------------
    reg [31:0]  muxed_sboxw;
    wire [31:0]  new_sboxw;
    
    //-----------------------------------------------------------
    //Model Instantiations
    //-----------------------------------------------------------
    
    aes_encode_block enc_block(
    
        .clk(clk),
        .reset(reset),
        .next(enc_next),
        .keylen(keylen),
        
        .round_no(enc_round_num),
        .round_key(round_key),
        
        .sbox_word(enc_sboxw),
        .new_sbox_word(new_sboxw),
        
        .block(block),
        .new_block(enc_new_block),
        .ready(enc_ready)
        
        );
        
        
    
    aes_decode_block dec_block(
    
        .clk(clk),
        .reset(reset),
        .next(dec_next),
        
        .keylen(keylen),
        .round_no(dec_round_num),
        .round_key(round_key),

        .block(block),
        .new_block(dec_new_block),
        .ready(dec_ready)        
      
        );
        
    
        
    aes_key_schedule key_schedule(
    
        .clk(clk),
        .reset(reset),    
        
        .key(key),
        .keylen(keylen),
        .init(init),
        
        .round(muxed_round_num),
        .round_key(round_key),
        .ready(key_ready),
        
        .sboxw(keymem_sboxw),
        .new_sboxw(new_sboxw) 
        
        );    
    
    aes_sbox s1(
    
        .input_sbox(muxed_sboxw),
        .new_sbox(new_sboxw)
        
        );
        
   assign ready = ready_reg;
   assign result = muxed_new_block;
   assign result_valid = result_valid_reg;
   
   
   always@(posedge clk or negedge reset)
   begin
   
     if(!reset)
        begin
        
            result_valid_reg   <= 1'b0;
            ready_reg          <= 1'b1;
            aes_core_ctrl_reg  <= CTRL_IDLE;
        
        end     
   
      else
        begin
        
            if(result_valid_we)
                result_valid_reg <= result_valid_new;
                
            if(ready_we)
                ready_reg <= ready_new;
                
            if(aes_core_ctrl_reg)
                aes_core_ctrl_reg <= aes_core_ctrl_new;
        
        end
    
   end
   
   // Determine which of encipher block or 
   // keygenerator will gain access to 
   //SBOX network
   
   always@(*)
   begin
   
     if(init_state)
        muxed_sboxw = keymem_sboxw;
        
     else
        muxed_sboxw = enc_sboxw;  
        
   end
   
   // Determine which of encipher or decode
   // core which will be processed
   always@(*)
   begin
     enc_next = 1'b0;
     dec_next = 1'b0;
     
     if(enc_dec)
        begin
        
            enc_next = next;
            muxed_round_num = enc_round_num;
            muxed_new_block = enc_new_block;
            muxed_ready = enc_ready;
        
        end
        
     else
        begin
        
            dec_next = next;
            muxed_round_num = dec_round_num;
            muxed_new_block = dec_new_block;
            muxed_ready = dec_ready;     
        
        end   
   
   end 
    
   // FSM to control aes_core module
   // it connect different submodules 
   // to the shared resources
   always@(*)
   begin
   
     init_state = 1'b0;
     ready_new = 1'b0;
     ready_we  = 1'b0;
     result_valid_new = 1'b0;
     result_valid_we  = 1'b0;
     aes_core_ctrl_new = CTRL_IDLE;
     aes_core_ctrl_we  = 1'b0;
   
   
     case(aes_core_ctrl_reg)

          CTRL_IDLE :
            begin
            
                if(init)
                    begin
                        
                        init_state = 1'b1;
                        ready_new = 1'b0;
                        ready_we = 1'b1;
                        result_valid_new = 1'b0;
                        result_valid_we = 1'b1;
                        aes_core_ctrl_new = CTRL_INIT;
                        aes_core_ctrl_we = 1'b1;
                        
                    end
                    
                else if(next)
                    begin
                                            
                        init_state = 1'b0;
                        ready_new = 1'b0;
                        ready_we = 1'b1;
                        result_valid_new = 1'b0;
                        result_valid_we = 1'b1;
                        aes_core_ctrl_new = CTRL_NEXT;
                        aes_core_ctrl_we = 1'b1;
                        
                    
                    end    
            
            end 
        
        
          CTRL_INIT :   
            begin
                
                init_state = 1'b1;
                
                if(key_ready)
                    begin
                        
                        ready_new = 1'b1;
                        ready_we = 1'b1;
                        aes_core_ctrl_new = CTRL_IDLE;
                        aes_core_ctrl_we = 1'b1;
                        
                    end
            
            
            end
            
            
        CTRL_NEXT :
            begin
                
                init_state = 1'b0;
                if(muxed_ready)
                    begin
                        
                        ready_new = 1'b1;
                        ready_we = 1'b1;
                        result_valid_new = 1'b1;
                        result_valid_we  = 1'b1;
                        aes_core_ctrl_new = CTRL_IDLE;
                        aes_core_ctrl_we = 1'b1;
                        
                    end
            
            
            end
            
            
        default:
            begin
            
            end    
        
        
     endcase
   
   
   end  
   
    
endmodule
