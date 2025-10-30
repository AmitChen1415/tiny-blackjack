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
    input  wire        rng_load,     // Load new seed into RNG
    input  wire [15:0] rng_seed,    // Seed value for RNG

    // Game outputs
    output reg  [5:0] user_total,   // Player's current card total
    output reg  [5:0] dealer_total, // Dealer's current card total
    output reg  [9:0] balance       // Player's balance (chips)
  , output wire [4:0] dbg_last_card
  , output wire [1:0] dbg_deal_count
  , output wire       dbg_blackjack
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
  localparam S_UPDATE_BAL  = 3'd4;

  reg [2:0] state, next_state;
  // small counter to sequence the initial deal across multiple clocks so
  // each card consumes a fresh RNG output instead of reusing the same value
  reg [1:0] deal_count;

  reg is_doubled; // flag to indicate if the player has doubled this round
  reg blackjack;  // flag: player has a natural blackjack (21 with 2 cards)

  wire player_finish_turn = btn_double || btn_stand || user_total == 21;

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
      deal_count   <= 2'd0;
      is_doubled   <= 1'b0;
      blackjack    <= 1'b0;
    end else begin
      state <= next_state;

      // Reset deal_count when not in the initial-deal state so new rounds
      // will re-sequence the three card draws.
      if (state != S_INIT_DEAL)
        deal_count <= 2'd0;

      case (state)
        // Initial deal: user gets 2 cards, dealer gets 1
        // We sequence the three card draws over three consecutive clocks
        // so the LFSR produces a new value for each card.
        S_INIT_DEAL: begin
          is_doubled <= 1'b0; // reset double flag at start of round
          blackjack  <= 1'b0; // reset blackjack flag at start of round
          case (deal_count)
            2'd0: begin
              // first card to user (also clear totals first)
              user_total   <= next_card_val;
              dealer_total <= 0;
              deal_count   <= deal_count + 1'b1;
            end
            2'd1: begin
              // second card to user
              // detect natural blackjack: first_card + second_card == 21
              if (user_total + next_card_val == 6'd21)
                blackjack <= 1'b1;
              user_total   <= user_total + next_card_val;
              deal_count   <= deal_count + 1'b1;
            end
            2'd2: begin
              // dealer's single card
              dealer_total <= next_card_val;
              deal_count   <= deal_count + 1'b1; // becomes 3 (done)
            end
            default: begin
              // keep values until state machine advances
            end
          endcase
        end

        // Player's turn: can Hit or Double
        S_PLAYER_TURN: begin
          if (btn_hit) begin
            user_total <= user_total + next_card_val;
          end
          if (btn_double) begin
            user_total <= user_total + next_card_val;
            is_doubled <= 1'b1; // Deduct if doubled
          end
        end

        // Dealer draws until reaching 17
        S_DEALER_TURN: begin
          if (dealer_total < 17)
            dealer_total <= dealer_total + next_card_val;
        end

        // Evaluate results and update balance
        S_UPDATE_BAL: begin
          // Natural blackjack pays a special reward
          if (blackjack) begin
            // User requested: give the player +150 on a 2-card 21
              //need to change to 75
            balance <= balance + 10'd150;
          end else begin
            if (user_total > 21) begin
              balance <= balance - 10'd50; // Player bust
            end else if (dealer_total > 21 || user_total > dealer_total) begin
              balance <= balance + 10'd50 + 10'd50*is_doubled; // Player wins
            end else if (user_total < dealer_total) begin
              balance <= balance - 10'd50 - 10'd50*is_doubled; // Dealer wins
            end
            // Equal totals => no change (push)
          end
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

    // After initial deal, go to player's turn only once the three card
    // draws have completed (deal_count == 3). If the player hit a natural
    // blackjack on the initial two cards, go straight to settlement.
    S_INIT_DEAL:  if (deal_count == 2'd3) begin
            if (blackjack) next_state = S_UPDATE_BAL; else next_state = S_PLAYER_TURN;
          end else next_state = S_INIT_DEAL;

      // Player turn logic
      S_PLAYER_TURN: begin
        if (player_finish_turn)   next_state = S_DEALER_TURN;  // Double ends turn
        else if (user_total > 21) next_state = S_UPDATE_BAL;   // Auto evaluate if bust
        else                      next_state = S_PLAYER_TURN;     
      end

      // Dealer turn ends once >= 17 (go straight to balance update)
      S_DEALER_TURN: if (dealer_total >= 17) next_state = S_UPDATE_BAL;

      // After updating balance, return to IDLE (auto new round possible)
      S_UPDATE_BAL:  next_state = S_IDLE;
    endcase
  end

    // expose the current RNG/card value and deal counter for debugging and testing
    assign dbg_last_card  = next_card_val;
    assign dbg_deal_count = deal_count;
    // expose blackjack detection for testbench
    assign dbg_blackjack  = blackjack;

endmodule
