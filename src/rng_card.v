// rng_card.v
// Wrapper around lfsr16 to produce card values in range [2..11]

`default_nettype none

module rng_card (
  input  wire        clk,      // Clock
  input  wire        rst_n,    // Active-low reset
  input  wire        load,     // Load custom seed
  input  wire [15:0] seed,     // Seed value
  output wire [4:0]  card_val  // Card value (2–11)
);

  wire [15:0] rnd;

  // Instantiate the 16-bit LFSR
  lfsr16 lfsr_inst (
    .clk  (clk),
    .rst  (~rst_n),   // active-high reset inside LFSR
    .load (load),
    .seed (seed),
    .rnd  (rnd)
  );

  // Take the lowest 4 bits for simplicity
  wire [3:0] raw = rnd[3:0];

  // Map into the range [2..11]
  assign card_val = (raw > 4'd9) ? (raw - 4'd10 + 5'd2) : (raw + 5'd2);

endmodule
