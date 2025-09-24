/*
* TinyTapeout Blackjack Wrapper
* SPDX-License-Identifier: Apache-2.0
*/
`default_nettype none
module tt_um_blackjack (
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

  // VGA (dummy for now — replace later if you connect real VGA generator)
  wire hsync, vsync;
  wire [1:0] red, green, blue;
  assign hsync = 1'b0;
  assign vsync = 1'b0;
  assign red   = 2'b00;
  assign green = 2'b00;
  assign blue  = 2'b00;

  // Buttons
  wire start, hit, stand, double_bet;
  assign hit        = ui_in[0];
  assign stand      = ui_in[1];
  assign double_bet = ui_in[2];
  assign start      = ui_in[4];

  // Outputs mapping (still mapped to VGA pins just for testing visuals)
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
    .clk        (clk),
    .rst_n      (clk_in_rst_n_sync),
    .btn_hit    (hit),
    .btn_stand  (stand),
    .btn_double (double_bet),
    .btn_start  (start)
    // RNG load/seed left unconnected here — can tie off or expose via uio if needed
  );

  // Power-up synchronizer
  pwrup_synchronizer pwrup_sync_inst (
      .clk_in            (clk),
      .rst_n             (rst_n),
      .clk_in_rst_n_sync (clk_in_rst_n_sync)
  );

endmodule
