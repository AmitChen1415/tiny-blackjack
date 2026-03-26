/*
* TinyTapeout Blackjack Wrapper
* SPDX-License-Identifier: Apache-2.0
*/
`default_nettype none
`timescale 1ns/1ps
module tt_um_AmitChen1415 (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
  // For now: uio outputs unused
  assign uio_out = 8'b0;
  assign uio_oe  = 8'b0;
  wire clk_in_rst_n_sync;

  // VGA (dummy for now — replace later if you connect real VGA generator - blackjack_table module)
  wire hsync, vsync;
  wire [1:0] red, green, blue;
  // assign hsync = 1'b0;
  // assign vsync = 1'b0;
  // assign red   = 2'b00;
  // assign green = 2'b00;
  // assign blue  = 2'b00;
  wire [3:0] dealer_card1;
  wire [3:0] dealer_card2;
  wire [3:0] dealer_card3;
  wire [3:0] dealer_card4;
  wire [3:0] dealer_card5;
  wire [3:0] player_card1;
  wire [3:0] player_card2;
  wire [3:0] player_card3;
  wire [3:0] player_card4;
  wire [3:0] player_card5; 

    // Buttons
  wire start, hit, stand, double_bet;
  assign hit        = ui_in[0];
  assign stand      = ui_in[1];
  assign double_bet = ui_in[2];
  assign start      = ui_in[4];

  wire [4:0] next_card_val_o;
  wire [9:0] user_balance;
  wire [5:0] game_user_total;
  wire [5:0] game_dealer_total;
  wire [3:0] bal_d3, bal_d2, bal_d1, bal_d0;

  // Internal debug signal wires (for RTL testing via hierarchy)
  wire [2:0] game_state;
  wire [2:0] game_p_cards;
  wire [2:0] game_d_cards;
  wire       game_doubled;


  
//Instantiate the table renderer
blackjack_table gfx (
   .clk_25MHz    (clk_pix    ),  // your 25 MHz pixel clock
  .rst_n        (rst_pix_n   ),
   .vga_hsync    (hsync       ),
   .vga_vsync    (vsync       ),
   .vga_r        (red         ),
   .vga_g        (green       ),
   .vga_b        (blue        ),
   .dealer_card1 (dealer_card1),
   .dealer_card2 (dealer_card2),
   .dealer_card3 (dealer_card3),
   .dealer_card4 (dealer_card4),
   .dealer_card5 (dealer_card5),
   .player_card1 (player_card1),
   .player_card2 (player_card2),
   .player_card3 (player_card3),
   .player_card4 (player_card4),
   .player_card5 (player_card5),
   .bal_d3       (bal_d3),
   .bal_d2       (bal_d2),
   .bal_d1       (bal_d1),
   .bal_d0       (bal_d0)
);



// Tapeout/RTL: normal VGA mapping
assign uo_out[0] = red[1];
assign uo_out[1] = green[1];
assign uo_out[2] = blue[1];
assign uo_out[3] = vsync;
assign uo_out[4] = red[0];
assign uo_out[5] = green[0];
assign uo_out[6] = blue[0];
assign uo_out[7] = hsync;
  
  // Connect to Blackjack core
  blackjack_core game_inst (
    .clk            (clk              ),
    .rst_n          (clk_in_rst_n_sync),
    .btn_hit        (hit              ),
    .btn_stand      (stand            ),
    .btn_double     (double_bet       ),
    .btn_start      (start            ),
    .user_total     (game_user_total  ),
    .dealer_total   (game_dealer_total),
    .balance        (user_balance     ),
    .bal_d3         (bal_d3           ),
    .bal_d2         (bal_d2           ),
    .bal_d1         (bal_d1           ),
    .bal_d0         (bal_d0           ),
    .dealer_card1_o (dealer_card1     ),
    .dealer_card2_o (dealer_card2     ),
    .dealer_card3_o (dealer_card3     ),
    .dealer_card4_o (dealer_card4     ),
    .dealer_card5_o (dealer_card5     ),
    .player_card1_o (player_card1     ),  
    .player_card2_o (player_card2     ),  
    .player_card3_o (player_card3     ),
    .player_card4_o (player_card4     ),
    .player_card5_o (player_card5     ),
    .state_dbg      (game_state       ),
    .p_cards_dbg    (game_p_cards     ),
    .d_cards_dbg    (game_d_cards     ),
    .doubled_dbg    (game_doubled     ),
    .rng_load       (1'b0             ), // Always load seed at startup
    .rng_seed       (16'hACE1         )  // Constant seed for deterministic RNG
  );

  // Power-up synchronizer
  pwrup_synchronizer pwrup_sync_inst (
      .clk_in            (clk              ),
      .rst_n             (rst_n            ),
      .clk_in_rst_n_sync (clk_in_rst_n_sync)
  );

  //PLL clock for table 

  // // --- Pixel clock from PLL (25.175 MHz) ---
  wire clk_pix;          // 25.175 MHz
  wire pll_locked;

  vga_pll u_pll (
    .inclk0 (clk),       // 50 MHz board clock
    .c0     (clk_pix),   // 25.175 MHz
    .locked (pll_locked)
  );


// Hold the video path in reset until the PLL locks
wire rst_pix_n;
assign rst_pix_n = rst_n & pll_locked;
endmodule
