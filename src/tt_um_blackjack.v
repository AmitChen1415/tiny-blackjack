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

  // VGA
  wire hsync, vsync;
  wire [1:0] red, green, blue;

  // Buttons
  wire hit, stand, double_bet, finish;
  assign hit        = ui_in[0];
  assign stand      = ui_in[1];
  assign double_bet = ui_in[2];
  assign finish     = ui_in[3];

  // Outputs mapping 
  assign uo_out[0] = red[1];
  assign uo_out[1] = green[1];
  assign uo_out[2] = blue[1];
  assign uo_out[3] = vsync;
  assign uo_out[4] = red[0];
  assign uo_out[5] = green[0];
  assign uo_out[6] = blue[0];
  assign uo_out[7] = hsync;
  
  // Connect to top game module
  blackjack_core game_inst (
    .clk_25MHz(clk),
    .rst_n(clk_in_rst_n_sync),
    .btn_hit(hit),
    .btn_stand(stand),
    .btn_double(double_bet),
    .btn_finish(finish),
    .vga_hsync(hsync),
    .vga_vsync(vsync),
    .vga_r(red),
    .vga_g(green),
    .vga_b(blue)
  );

  // Power-up synchronizer
  pwrup_synchronizer pwrup_sync_inst (
      .clk_in(clk),
      .rst_n(rst_n),
      .clk_in_rst_n_sync(clk_in_rst_n_sync)
  );

  // Red Square
  // red_square red_sq_inst (
  // .clk_25MHz (clk),
  // .rst_n     (clk_in_rst_n_sync),
  // .vga_hsync (hsync),
  // .vga_vsync (vsync),
  // .vga_r     (red),
  // .vga_g     (green),
  // .vga_b     (blue)
  // );

endmodule
