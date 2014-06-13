//======================================================================
//
// aes_key_mem.v
// -------------
// The AES key memort including round key generator.
//
//
// Author: Joachim Strombergson
// Copyright (c) 2013 Secworks Sweden AB
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or 
// without modification, are permitted provided that the following 
// conditions are met: 
// 
// 1. Redistributions of source code must retain the above copyright 
//    notice, this list of conditions and the following disclaimer. 
// 
// 2. Redistributions in binary form must reproduce the above copyright 
//    notice, this list of conditions and the following disclaimer in 
//    the documentation and/or other materials provided with the 
//    distribution. 
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE 
// COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, 
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF 
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================

module aes_key_mem(
                   input wire            clk,
                   input wire            reset_n,

                   input wire [255 : 0]  key,
                   input wire [1   : 0]  keylen,
                   input wire            init,

                   input wire    [3 : 0] round,
                   output wire [127 : 0] round_key,
                   output wire           ready
                  );

  
  //----------------------------------------------------------------
  // Parameters.
  //----------------------------------------------------------------
  parameter AES_128_BIT_KEY = 0;
  parameter AES_192_BIT_KEY = 1;
  parameter AES_256_BIT_KEY = 2;

  parameter AES_128_NUM_ROUNDS = 10;
  parameter AES_192_NUM_ROUNDS = 12;
  parameter AES_256_NUM_ROUNDS = 14;
  
  parameter CTRL_IDLE     = 0;
  parameter CTRL_INIT     = 1;
  parameter CTRL_GENERATE = 2;
  parameter CTRL_DONE     = 3;

  
  //----------------------------------------------------------------
  // Registers.
  //----------------------------------------------------------------
  reg [127 : 0] key_mem [0 : 13];
  reg [127 : 0] key_mem_new;
  reg           key_mem_we;

  reg [127 : 0] prev_key_reg;
  
  reg [3 : 0] round_ctr_reg;
  reg [3 : 0] round_ctr_new;
  reg         round_ctr_rst;
  reg         round_ctr_inc;
  reg         round_ctr_we;
  
  reg [1 : 0] word_ctr_reg;
  reg [1 : 0] word_ctr_new;
  reg         word_ctr_rst;
  reg         word_ctr_inc;
  reg         word_ctr_we;

  reg [2 : 0] key_mem_ctrl_reg;
  reg [2 : 0] key_mem_ctrl_new;
  reg         key_mem_ctrl_we;

  reg         ready_reg;
  reg         ready_new;
  reg         ready_we;

  reg [7 : 0] rcon_reg;
  reg [7 : 0] rcon_new;
  reg         rcon_we;
  reg         rcon_set;
  reg         rcon_next;
  

  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg [7 : 0] sbox0_addr;
  reg [7 : 0] sbox1_addr;
  reg [7 : 0] sbox2_addr;
  reg [7 : 0] sbox3_addr;

  wire [7 : 0] sbox0_data;
  wire [7 : 0] sbox1_data;
  wire [7 : 0] sbox2_data;
  wire [7 : 0] sbox3_data;

  reg           round_key_update;
  reg [3 : 0]   num_rounds;

  reg [127 : 0] tmp_round_key;
  reg           tmp_ready;
  

  //----------------------------------------------------------------
  // Instantiations.
  //----------------------------------------------------------------
  aes_sbox sbox0(.addr(prev_key_reg[127 : 120]), .data(sbox0_data));
  aes_sbox sbox1(.addr(prev_key_reg[119 : 112]), .data(sbox1_data));
  aes_sbox sbox2(.addr(prev_key_reg[111 : 104]), .data(sbox2_data));
  aes_sbox sbox3(.addr(prev_key_reg[103 : 096]), .data(sbox3_data));

  
  //----------------------------------------------------------------
  // Concurrent assignments for ports.
  //----------------------------------------------------------------
  assign round_key = tmp_round_key;
  assign ready     = ready_reg;
  
    
  //----------------------------------------------------------------
  // reg_update
  //
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with synchronous
  // active low reset. All registers have write enable.
  //----------------------------------------------------------------
  always @ (posedge clk)
    begin: reg_update
      if (!reset_n)
        begin
          key_mem [0]     <= 128'h00000000000000000000000000000000;
          key_mem [1]     <= 128'h00000000000000000000000000000000;
          key_mem [2]     <= 128'h00000000000000000000000000000000;
          key_mem [3]     <= 128'h00000000000000000000000000000000;
          key_mem [4]     <= 128'h00000000000000000000000000000000;
          key_mem [5]     <= 128'h00000000000000000000000000000000;
          key_mem [6]     <= 128'h00000000000000000000000000000000;
          key_mem [7]     <= 128'h00000000000000000000000000000000;
          key_mem [8]     <= 128'h00000000000000000000000000000000;
          key_mem [9]     <= 128'h00000000000000000000000000000000;
          key_mem [10]    <= 128'h00000000000000000000000000000000;
          key_mem [11]    <= 128'h00000000000000000000000000000000;
          key_mem [12]    <= 128'h00000000000000000000000000000000;
          key_mem [13]    <= 128'h00000000000000000000000000000000;
          prev_key_reg    <= 128'h00000000000000000000000000000000;
          rcon_reg        <= 8'h00;
          ready_reg       <= 0;
          round_ctr_reg   <= 4'h0;
          word_ctr_reg    <= 2'h0;
          key_mem_ctrl_reg <= CTRL_IDLE;
        end
      else
        begin
          if (round_ctr_we)
            begin
              round_ctr_reg <= round_ctr_new;
            end

          if (word_ctr_we)
            begin
              word_ctr_reg <= word_ctr_new;
            end

          if (ready_we)
            begin
              ready_reg <= ready_new;
            end

          if (rcon_we)
            begin
              rcon_reg <= rcon_new;
            end
          
          if (key_mem_we)
            begin
              key_mem[round_ctr_reg] <= key_mem_new;
              prev_key_reg           <= key_mem_new;
            end

          if (key_mem_ctrl_we)
            begin
              key_mem_ctrl_reg <= key_mem_ctrl_new;
            end
        end
    end // reg_update


  //----------------------------------------------------------------
  // key_mem_read
  //
  // Combinational read port for the key memory.
  //----------------------------------------------------------------
  always @*
    begin : key_mem_read
      tmp_round_key = key_mem[round];
    end // key_mem_read

  
  //----------------------------------------------------------------
  // round_key_gen
  //
  //
  // The round key generator logic
  //----------------------------------------------------------------
  always @*
    begin: round_key_gen
      reg [31 : 0] w0, w1, w2, w3, subw, rconw;
      w3 = prev_key_reg[127 : 096];
      w2 = prev_key_reg[095 : 064];
      w1 = prev_key_reg[063 : 032];
      w0 = prev_key_reg[031 : 000];

      // Note: This is where we do column rotation.
      subw = {sbox0_data, sbox1_data, sbox2_data, sbox3_data};
      rconw = {rcon_reg, 24'h000000};
      
      // Default assignments.
      key_mem_new = 128'h00000000000000000000000000000000;
      key_mem_we  = 0;

      if (round_key_update)
        key_mem_we  = 1;
        begin
          case (keylen)
            AES_128_BIT_KEY:
              begin
                if (round_ctr_reg == 0)
                  begin
                    key_mem_new = key;
                  end
                else
                  begin
                    w0 = prev_key_reg[127 : 096] ^ subw ^ rconw;
                    w1 = prev_key_reg[063 : 032] ^ w0;
                    w2 = prev_key_reg[095 : 064] ^ w0;
                    w3 = prev_key_reg[031 : 000] ^ w0;
                    key_mem_new = {w0, w1, w2, w3};
                  end
              end

            AES_192_BIT_KEY:
              begin
                if (round_ctr_reg == 0)
                  begin
                    key_mem_new = key[191 : 64];
                  end
                
                if (round_ctr_reg == 1)
                  begin
                    key_mem_new = {key[63 : 0], prev_key_reg[127 : 64]};
                  end
              end


            AES_256_BIT_KEY:
              begin
                if (round_ctr_reg == 0)
                  begin
                    key_mem_new = key[255 : 128];
                  end

                if (round_ctr_reg == 1)
                  begin
                    key_mem_new = key[127 : 0];
                  end
              end

            default:
              begin
                num_rounds = 4'h0;
              end
          endcase // case (keylen)
        end
    end // round_key_gen


  //----------------------------------------------------------------
  // rcon_logic
  //
  // Caclulates the rcon value for the different key expansion
  // iterations.
  //----------------------------------------------------------------
  always @*
    begin : rcon_logic
      rcon_new = 8'h00;
      rcon_we  = 0;

      if (rcon_set)
        begin
          rcon_new = 8'h8d;
          rcon_we  = 1;
        end

      if (rcon_next)
        begin
          rcon_new  = {rcon_reg[7 : 0], 1'b0} ^ (9'h11b & {9{rcon_reg[7]}});
          rcon_we  = 1;
        end
    end


  //----------------------------------------------------------------
  // round_ctr
  //
  // The round counter logic with increase and reset.
  //----------------------------------------------------------------
  always @*
    begin : round_ctr
      round_ctr_new = 4'h0;
      round_ctr_we  = 0;

      if (round_ctr_rst)
        begin
          round_ctr_new = 4'h0;
          round_ctr_we  = 1;
        end
      else if (round_ctr_inc)
        begin
          round_ctr_new = round_ctr_reg + 1'b1;
          round_ctr_we  = 1;
        end
    end


  //----------------------------------------------------------------
  // word_ctr
  //
  // The word counter logic with increase and reset.
  //----------------------------------------------------------------
  always @*
    begin : word_ctr
      word_ctr_new = 2'h0;
      word_ctr_we  = 0;

      if (word_ctr_rst)
        begin
          word_ctr_new = 2'h0;
          word_ctr_we  = 1;
        end
      else if (word_ctr_inc)
        begin
          word_ctr_new = word_ctr_reg + 1'b1;
          word_ctr_we  = 1;
        end
    end


  //----------------------------------------------------------------
  // num_rounds_logic
  //
  // Logic to select the number of rounds to generate keys for
  //----------------------------------------------------------------
  always @*
    begin : num_rounds_logic
      case (keylen)
        AES_128_BIT_KEY:
          begin
            num_rounds = AES_128_NUM_ROUNDS;
          end

        AES_192_BIT_KEY:
          begin
            num_rounds = AES_192_NUM_ROUNDS;
          end

        AES_256_BIT_KEY:
          begin
            num_rounds = AES_256_NUM_ROUNDS;
          end

        default:
          begin
            num_rounds = 4'h0;
          end
      endcase // case (keylen)
    end


  //----------------------------------------------------------------
  // key_mem_ctrl
  //
  //
  // The FSM that controls the round key generation.
  //----------------------------------------------------------------
  always @*
    begin: key_mem_ctrl
      // Default assignments.
      rcon_set         = 0;
      rcon_next        = 0;
      ready_new        = 0;
      ready_we         = 0;
      round_key_update = 0;
      round_ctr_rst    = 0;
      round_ctr_inc    = 0;
      key_mem_ctrl_new = CTRL_IDLE;
      key_mem_ctrl_we  = 0;

      case(key_mem_ctrl_reg)
        CTRL_IDLE:
          begin
            if (init)
              begin
                rcon_set         = 1;
                ready_new        = 0;
                ready_we         = 1;
                key_mem_ctrl_new = CTRL_INIT;
                key_mem_ctrl_we  = 1;
              end
          end

        CTRL_INIT:
          begin
            round_ctr_rst    = 1;
            key_mem_ctrl_new = CTRL_GENERATE;
            key_mem_ctrl_we  = 1;
          end

        CTRL_GENERATE:
          begin
            round_ctr_inc    = 1;
            round_key_update = 1;
            rcon_next        = 1;
            if (round_ctr_reg == num_rounds)
              begin
                key_mem_ctrl_new = CTRL_DONE;
                key_mem_ctrl_we  = 1;
              end
          end

        CTRL_DONE:
          begin
            ready_new        = 1;
            ready_we         = 1;
            key_mem_ctrl_new = CTRL_IDLE;
            key_mem_ctrl_we  = 1;
          end

        default:
          begin
          end
      endcase // case (key_mem_ctrl_reg)

    end // key_mem_ctrl
endmodule // aes_key_mem

//======================================================================
// EOF aes_key_mem.v
//======================================================================