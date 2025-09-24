// ============================================================================
// lfsr16.v
// 16-bit Linear Feedback Shift Register (LFSR) for pseudo-random number generation
// Suitable for games (e.g., Blackjack RNG), lightweight and FPGA-friendly.
// ----------------------------------------------------------------------------
// Features:
// - Produces a repeating pseudo-random sequence of length up to 65,535 states.
// - Can be reseeded with a custom seed value using the "load" signal.
// - Deterministic: same seed produces the same sequence (useful for debugging).
// - Not cryptographically secure (intended for simple randomness).
// ============================================================================

`default_nettype none

module lfsr16 (
  input  wire        clk,   // Clock input
  input  wire        rst,   // Active-high reset (initializes to default value)
  input  wire        load,  // Load a custom seed into the register
  input  wire [15:0] seed,  // Seed value for reproducible sequences
  output reg  [15:0] rnd    // Current pseudo-random value
);

  // Feedback taps: XOR of bits 0, 2, 3, 5
  // This is one of the maximal-length feedback polynomials for 16-bit LFSRs
  wire feedback = rnd[0] ^ rnd[2] ^ rnd[3] ^ rnd[5];

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      // Initialize to a non-zero state (cannot be all zeros in an LFSR)
      rnd <= 16'h1ACE;
    end else if (load) begin
      // Load custom seed
      // (If seed is 0, the LFSR will lock up; user must avoid seed=0)
      rnd <= seed;
    end else begin
      // Shift right, insert feedback into MSB
      rnd <= {feedback, rnd[15:1]};
    end
  end

endmodule
