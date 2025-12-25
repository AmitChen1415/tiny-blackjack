`default_nettype none
`timescale 1ns/1ps


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
    output reg  [9:0] balance,       // Player's balance (chips)
    output wire [4:0] dbg_last_card,
    output wire [1:0] dbg_deal_count,
    output wire       dbg_blackjack,
    
    output reg [3:0] dealer_card1_o,
    output reg [3:0] dealer_card2_o,
    output reg [3:0] dealer_card3_o, 
    output reg [3:0] dealer_card4_o,
    output reg [3:0] dealer_card5_o,     
    output reg [3:0] player_card1_o,
    output reg [3:0] player_card2_o,  
    output reg [3:0] player_card3_o,
    output reg [3:0] player_card4_o,
    output reg [3:0] player_card5_o
    
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
  reg  [1:0] deal_count;
  wire [1:0] deal_count_ps;

  wire is_doubled; // flag to indicate if the player has doubled this round
  wire blackjack;  // flag: player has a natural blackjack (21 with 2 cards)
  wire player_win;

  reg [5:0] user_total_ps;
  reg [5:0] dealer_total_ps;
  reg [9:0] balance_ps;

  wire player_finish_turn = btn_double || btn_stand || user_total == 21;

  // ------------------------------------------------------------
  // RNG instance (rng_card wrapper around lfsr16)
  // ------------------------------------------------------------
  reg [3:0] next_card_val; // Random card in range [2..11]
  wire [3:0] next_card_va; // Random card in range [2..11]

  rng_card card_rng (
    .clk     (clk),
    .rst_n   (rst_n),
    .load    (rng_load),
    .seed    (rng_seed),
    .card_val(next_card_va)
  );

  
  assign deal_count_ps = state == S_INIT_DEAL && deal_count == 2'd0 ? deal_count + 2'd1 :
                         state == S_INIT_DEAL && deal_count == 2'd1 ? deal_count + 2'd1 :
                         state == S_INIT_DEAL && deal_count == 2'd2 ? deal_count + 2'd1 : 2'd0;

  assign blackjack = (state == S_INIT_DEAL) && ((user_total + next_card_val) == 6'd21) ? 1'b1 : 1'b0;
  assign is_doubled = (state == S_PLAYER_TURN) && btn_double ? 1'b1 : 1'b0;

  assign player_win = (dealer_total > 21 || user_total > dealer_total) ? 1'b1 : 1'b0;

  // Pulse detectors for button inputs
  reg btn_hit_n, btn_double_n, btn_stand_n, btn_start_n;
  wire btn_hit_p, btn_double_p, btn_stand_p, btn_start_p;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      btn_hit_n    <= 1'b0;
      btn_double_n <= 1'b0;
      btn_stand_n  <= 1'b0;
      btn_start_n  <= 1'b0;
    end else begin
      btn_hit_n    <= btn_hit;
      btn_double_n <= btn_double;
      btn_stand_n  <= btn_stand;
      btn_start_n  <= btn_start;
    end
  end

  assign btn_hit_p    = ~btn_hit    & btn_hit_n;
  assign btn_double_p = ~btn_double & btn_double_n;
  assign btn_stand_p  = ~btn_stand  & btn_stand_n;
  assign btn_start_p  = ~btn_start  & btn_start_n;

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
    end else begin
      state        <= next_state;
      deal_count   <= deal_count_ps;
      user_total   <= user_total_ps;
      dealer_total <= dealer_total_ps;
      balance      <= balance_ps;
      next_card_val <= next_card_va;
    end
  end

  // ------------------------------------------------------------
  // Combinational next-state logic
  // ------------------------------------------------------------
  always @(*) begin
    next_state      = state;
    dealer_total_ps = dealer_total;
    user_total_ps   = user_total;
    balance_ps      = balance;

    case (state)
      // Wait for "start" button to begin round
      S_IDLE: begin     
        if (btn_start_p)  next_state = S_INIT_DEAL; 
      end

    // After initial deal, go to player's turn only once the three card
    // draws have completed (deal_count == 3). If the player hit a natural
    // blackjack on the initial two cards, go straight to settlement.
    S_INIT_DEAL: begin 
      if (deal_count == 2'd3) begin
        if (blackjack) next_state = S_UPDATE_BAL;
        else next_state = S_PLAYER_TURN;
      end else if (deal_count == 2'd2) begin 
        dealer_total_ps = next_card_val; 
      end else if (deal_count == 2'd1) begin 
        user_total_ps = user_total + next_card_val;
      end else if (deal_count == 2'd0) begin 
        user_total_ps = next_card_val;
      end
    end

    // Player turn logic
    S_PLAYER_TURN: begin
        if (btn_double_p || btn_hit_p) user_total_ps = user_total + next_card_val;

        if (player_finish_turn)   next_state = S_DEALER_TURN;  // Double ends turn
        else if (user_total > 21) next_state = S_UPDATE_BAL;   // Auto evaluate if bust
        else                      next_state = S_PLAYER_TURN;     
      end

    // Dealer turn ends once >= 17 (go straight to balance update)
    S_DEALER_TURN: if (dealer_total >= 17) next_state = S_UPDATE_BAL;
                  else dealer_total_ps = dealer_total + next_card_val;

      // After updating balance, return to IDLE (auto new round possible)
    S_UPDATE_BAL: begin  
      if (blackjack) begin 
        balance_ps = balance + 10'd75;
      end else if (user_total > 21) begin
        balance_ps = balance - 10'd50;
      end else if (player_win) begin
        balance_ps = balance + 10'd50 + (10'd50 *is_doubled);
      end else if (user_total < dealer_total) begin
        balance_ps = balance - 10'd50 - (10'd50 *is_doubled);
      end
      next_state = S_IDLE; 
    end
    endcase
  end


  // ------------------------------------------------------------
  // Current card outputs counters
  // ------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dealer_card1_o <= 4'd0;
      dealer_card2_o <= 4'd0;
      dealer_card3_o <= 4'd0;
      dealer_card4_o <= 4'd0;
      dealer_card5_o <= 4'd0;     
      player_card1_o <= 4'd0;
      player_card2_o <= 4'd0;  
      player_card3_o <= 4'd0;
      player_card4_o <= 4'd0;
      player_card5_o <= 4'd0; 
    end else begin
    case (state)
      S_IDLE: begin
        if (btn_start) begin
          // Clear all card outputs at the start of a new round
          dealer_card1_o <= 4'd0;
          dealer_card2_o <= 4'd0;
          dealer_card3_o <= 4'd0;
          dealer_card4_o <= 4'd0;
          dealer_card5_o <= 4'd0;     
          player_card1_o <= 4'd0;
          player_card2_o <= 4'd0;  
          player_card3_o <= 4'd0;
          player_card4_o <= 4'd0;
          player_card5_o <= 4'd0;     
        end     
      end
      S_INIT_DEAL: begin
        case (deal_count)
          2'd0: player_card1_o <= next_card_val; // first card to user
          2'd1: player_card2_o <= next_card_val; // second card to user
          2'd2: dealer_card1_o <= next_card_val; // dealer's single card
        default: ;
        endcase
      end
      S_PLAYER_TURN: begin
        if (btn_hit_p) begin
          if (player_card3_o == 4'd0)
            player_card3_o <= next_card_val;
          else if (player_card4_o == 4'd0)
            player_card4_o <= next_card_val;
          else if (player_card5_o == 4'd0)
              player_card5_o <= next_card_val;
          end
        end
        S_DEALER_TURN: begin
          if (dealer_total < 17) begin
            if (dealer_card2_o == 4'd0)
              dealer_card2_o <= next_card_val;
            else if (dealer_card3_o == 4'd0)
              dealer_card3_o <= next_card_val;
            else if (dealer_card4_o == 4'd0)
              dealer_card4_o <= next_card_val;
            else if (dealer_card5_o == 4'd0)
              dealer_card5_o <= next_card_val;          
          end
        end
        default: ;
      endcase
    end
  end
  

    // expose the current RNG/card value and deal counter for debugging and testing
    assign dbg_last_card  = next_card_val;
    assign dbg_deal_count = deal_count;
    // expose blackjack detection for testbench
    assign dbg_blackjack  = blackjack;

endmodule
