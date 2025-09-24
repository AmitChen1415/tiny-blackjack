// ============================================================================
// blackjack_core.v
// Blackjack finite state machine with integrated LFSR-based RNG
// ----------------------------------------------------------------------------
// Features:
// - User starts with 2 cards, dealer with 1 card
// - Player actions: Hit, Stand, Double
// - Dealer draws until reaching 17 or higher
// - Balance updates automatically after each round (+/- 50)
// - Uses LFSR-based RNG (via rng_card wrapper) to generate card values [2..11]
// - Game starts when btn_start is pressed, then auto-resets to IDLE after round
// ============================================================================

`default_nettype none

module blackjack_core (
    input  wire       clk,          // System clock (e.g., 25MHz from PLL)
    input  wire       rst_n,        // Active-low reset

    // Player buttons
    input  wire       btn_hit,      // Player requests an extra card
    input  wire       btn_stand,    // Player ends their turn
    input  wire       btn_double,   // Player doubles bet (and takes one card only)
    input  wire       btn_start,    // Start round

    // RNG seeding
    input  wire       rng_load,     // Load new seed into RNG
    input  wire [15:0] rng_seed,    // Seed value for RNG

    // Game outputs
    output reg  [5:0] user_total,   // Player's current card total
    output reg  [5:0] dealer_total, // Dealer's current card total
    output reg  [9:0] balance       // Player's balance (chips)
);

  // ------------------------------------------------------------
  // RNG instance (rng_card wrapper around lfsr16)
  // ------------------------------------------------------------
  wire [4:0] next_card_val; // Random card in range [2..11]

  rng_card card_rng (
    .clk     (clk),
    .rst_n   (rst_n),
    .load    (rng_load),
    .seed    (rng_seed),
    .card_val(next_card_val)
  );

  // ------------------------------------------------------------
  // FSM State Encoding
  // ------------------------------------------------------------
  localparam S_IDLE        = 3'd0;
  localparam S_INIT_DEAL   = 3'd1;
  localparam S_PLAYER_TURN = 3'd2;
  localparam S_DEALER_TURN = 3'd3;
  localparam S_EVALUATE    = 3'd4;
  localparam S_UPDATE_BAL  = 3'd5;

  reg [2:0] state, next_state;

  // ------------------------------------------------------------
  // Sequential logic (state + game registers)
  // ------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset state and game variables
      state        <= S_IDLE;
      user_total   <= 0;
      dealer_total <= 0;
      balance      <= 10'd500;  // Starting balance
    end else begin
      state <= next_state;

      case (state)
        // Initial deal: user gets 2 cards, dealer gets 1
        S_INIT_DEAL: begin
          user_total   <= next_card_val + next_card_val;  
          dealer_total <= next_card_val; 
        end

        // Player's turn: can Hit or Double
        S_PLAYER_TURN: begin
          if (btn_hit) begin
            user_total <= user_total + next_card_val;
          end
          if (btn_double) begin
            user_total <= user_total + next_card_val;
            balance    <= balance - 10'd50; // Deduct bet immediately
            // State machine will move directly to dealer's turn
          end
        end

        // Dealer draws until reaching 17
        S_DEALER_TURN: begin
          if (dealer_total < 17)
            dealer_total <= dealer_total + next_card_val;
        end

        // Evaluate results and update balance
        S_UPDATE_BAL: begin
          if (user_total > 21) begin
            balance <= balance - 10'd50; // Player bust
          end else if (dealer_total > 21 || user_total > dealer_total) begin
            balance <= balance + 10'd50; // Player wins
          end else if (user_total < dealer_total) begin
            balance <= balance - 10'd50; // Dealer wins
          end
          // Equal totals => no change (push)
        end
      endcase
    end
  end

  // ------------------------------------------------------------
  // Combinational next-state logic
  // ------------------------------------------------------------
  always @(*) begin
    next_state = state;
    case (state)
      // Wait for "start" button to begin round
      S_IDLE:       if (btn_start)  next_state = S_INIT_DEAL;

      // After initial deal, go to player’s turn
      S_INIT_DEAL:  next_state = S_PLAYER_TURN;

      // Player turn logic
      S_PLAYER_TURN: begin
        if (btn_double)         next_state = S_DEALER_TURN;   // Double ends turn
        else if (btn_stand)     next_state = S_DEALER_TURN;   // Stand ends turn
        else if (user_total >= 21) next_state = S_EVALUATE;   // Auto evaluate if 21/bust
      end

      // Dealer turn ends once >= 17
      S_DEALER_TURN: if (dealer_total >= 17) next_state = S_EVALUATE;

      // Always proceed to balance update
      S_EVALUATE:    next_state = S_UPDATE_BAL;

      // After updating balance, return to IDLE (auto new round possible)
      S_UPDATE_BAL:  next_state = S_IDLE;
    endcase
  end

endmodule
