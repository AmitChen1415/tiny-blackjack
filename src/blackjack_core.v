`default_nettype none

module blackjack_core (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        btn_hit,
    input  wire        btn_stand,
    input  wire        btn_double,
    input  wire        btn_start,

    input  wire        rng_load,
    input  wire [15:0] rng_seed,

    output reg  [5:0]  user_total,
    output reg  [5:0]  dealer_total,
    output reg  [9:0]  balance,

    // VALUES to table: 0=empty, 2..11 (11=Ace), 10 means 10/J/Q/K
    output reg  [3:0]  dealer_card1_o,
    output reg  [3:0]  dealer_card2_o,
    output reg  [3:0]  dealer_card3_o,
    output reg  [3:0]  dealer_card4_o,
    output reg  [3:0]  dealer_card5_o,

    output reg  [3:0]  player_card1_o,
    output reg  [3:0]  player_card2_o,
    output reg  [3:0]  player_card3_o,
    output reg  [3:0]  player_card4_o,
    output reg  [3:0]  player_card5_o,

    // Balance as BCD digits (saves gates in table)
    output reg  [3:0]  bal_d3,
    output reg  [3:0]  bal_d2,
    output reg  [3:0]  bal_d1,
    output reg  [3:0]  bal_d0,
    
    // DEBUG outputs for testing/verification
    output wire [2:0]  state_dbg,
    output wire [2:0]  p_cards_dbg,
    output wire [2:0]  d_cards_dbg,
    output wire        doubled_dbg
);

    // ----------------------------
    // Button synchronize + edge detect
    // ----------------------------
    reg hit_meta, stand_meta, double_meta, start_meta;
    reg hit_sync, stand_sync, double_sync, start_sync;
    reg hit_d, stand_d, double_d, start_d;
    wire hit_p    = hit_sync    & ~hit_d;
    wire stand_p  = stand_sync  & ~stand_d;
    wire double_p = double_sync & ~double_d;
    wire start_p  = start_sync  & ~start_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hit_meta <= 1'b0;
            stand_meta <= 1'b0;
            double_meta <= 1'b0;
            start_meta <= 1'b0;

            hit_sync  <= 1'b0;
            stand_sync <= 1'b0;
            double_sync <= 1'b0;
            start_sync <= 1'b0;

            hit_d    <= 1'b0;
            stand_d  <= 1'b0;
            double_d <= 1'b0;
            start_d  <= 1'b0;
        end else begin
            hit_meta    <= btn_hit;
            stand_meta  <= btn_stand;
            double_meta <= btn_double;
            start_meta  <= btn_start;

            hit_sync    <= hit_meta;
            stand_sync  <= stand_meta;
            double_sync <= double_meta;
            start_sync  <= start_meta;

            hit_d    <= hit_sync;
            stand_d  <= stand_sync;
            double_d <= double_sync;
            start_d  <= start_sync;
        end
    end

    // ----------------------------
    // Internal LFSR RNG
    // ----------------------------
    reg [15:0] lfsr;
    wire fb = lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr <= 16'hACE1;
        end else if (rng_load) begin
            lfsr <= rng_seed;
        end else begin
            lfsr <= {lfsr[14:0], fb};
        end
    end

    // ----------------------------
    // Next card VALUE (2..11)
    // 11 = Ace, 10 includes 10/J/Q/K
    // ----------------------------
    reg [3:0] next_rank_int; // 1..13 internal only
    reg [3:0] next_value;    // 2..11 output to game logic
    wire [5:0] next_value6 = {2'b00, next_value};

    always @(*) begin
        // fold lfsr[3:0] into a pseudo-rank 1..13
        case (lfsr[3:0])
            4'd0:  next_rank_int = 4'd1;
            4'd1:  next_rank_int = 4'd2;
            4'd2:  next_rank_int = 4'd3;
            4'd3:  next_rank_int = 4'd4;
            4'd4:  next_rank_int = 4'd5;
            4'd5:  next_rank_int = 4'd6;
            4'd6:  next_rank_int = 4'd7;
            4'd7:  next_rank_int = 4'd8;
            4'd8:  next_rank_int = 4'd9;
            4'd9:  next_rank_int = 4'd10;
            4'd10: next_rank_int = 4'd11; // J
            4'd11: next_rank_int = 4'd12; // Q
            4'd12: next_rank_int = 4'd13; // K
            4'd13: next_rank_int = 4'd1;  // A
            4'd14: next_rank_int = 4'd10;
            default: next_rank_int = 4'd9;
        endcase

        // rank -> blackjack value
        if (next_rank_int == 4'd1)
            next_value = 4'd11;       // Ace
        else if (next_rank_int >= 4'd11)
            next_value = 4'd10;       // J/Q/K
        else
            next_value = next_rank_int; // 2..10
    end

    // ----------------------------
    // FSM
    // ----------------------------
    localparam S_IDLE      = 3'd0;
    localparam S_INIT_DEAL = 3'd1;
    localparam S_PLAYER    = 3'd2;
    localparam S_DEALER    = 3'd3;
    localparam S_SETTLE    = 3'd4;

    reg [2:0] state, nstate;

    reg [1:0] deal_count, deal_count_n;   // 0:P1, 1:P2, 2:D1
    reg [2:0] p_cards, p_cards_n;
    reg [2:0] d_cards, d_cards_n;
    reg       doubled, doubled_n;
    reg [2:0] p_soft, p_soft_n; // number of aces counted as 11
    reg [2:0] d_soft, d_soft_n;

    reg [5:0] user_total_n, dealer_total_n;
    reg [9:0] balance_n;

    localparam [9:0] BET       = 10'd50;
    localparam [9:0] START_BAL = 10'd500;
    localparam [9:0] MAX_BAL   = 10'd999;

    // blackjack only when player has exactly 2 cards and total==21
    wire is_natural_blackjack = (p_cards == 3'd2) && (user_total == 6'd21);

    // Assign debug outputs (after register declarations)
    assign state_dbg = state;
    assign p_cards_dbg = p_cards;
    assign d_cards_dbg = d_cards;
    assign doubled_dbg = doubled;

    // ----------------------------
    // Next-state / next-values
    // ----------------------------
    reg [9:0] bet_amt;

    always @(*) begin
        nstate         = state;

        deal_count_n   = deal_count;
        p_cards_n      = p_cards;
        d_cards_n      = d_cards;
        doubled_n      = doubled;

        p_soft_n       = p_soft;
        d_soft_n       = d_soft;

        user_total_n   = user_total;
        dealer_total_n = dealer_total;
        balance_n      = balance;

        bet_amt        = BET + (doubled ? BET : 10'd0);

        case (state)
            S_IDLE: begin
                if (start_p) begin
                    nstate         = S_INIT_DEAL;
                    deal_count_n   = 2'd0;

                    user_total_n   = 6'd0;
                    dealer_total_n = 6'd0;

                    p_cards_n      = 3'd0;
                    d_cards_n      = 3'd0;

                    doubled_n      = 1'b0;
                    p_soft_n       = 3'd0;
                    d_soft_n       = 3'd0;
                end
            end

            S_INIT_DEAL: begin
                if (deal_count == 2'd0) begin
                    // P1
                    user_total_n = user_total + next_value6;
                    p_cards_n    = 3'd1;
                    if (next_value == 4'd11) p_soft_n = p_soft + 3'd1;
                    deal_count_n = 2'd1;

                end else if (deal_count == 2'd1) begin
                    // P2
                    user_total_n = user_total + next_value6;
                    p_cards_n    = 3'd2;
                    if (next_value == 4'd11) p_soft_n = p_soft + 3'd1;

                    // soft ace adjust if bust
                    if ((user_total + next_value6) > 6'd21) begin
                        user_total_n = (user_total + next_value6) - 6'd10;
                        p_soft_n     = p_soft_n - 3'd1;
                    end

                    deal_count_n = 2'd2;

                end else begin
                    // D1
                    dealer_total_n = dealer_total + next_value6;
                    d_cards_n      = 3'd1;
                    if (next_value == 4'd11) d_soft_n = d_soft + 3'd1;

                    deal_count_n = 2'd0;

                    // after init deal: if natural blackjack -> settle, else player
                    if (((p_cards_n == 3'd2) && (user_total_n == 6'd21)))
                        nstate = S_SETTLE;
                    else
                        nstate = S_PLAYER;
                end
            end

            S_PLAYER: begin
                //double
                if (double_p && (p_cards == 3'd2)) begin
                    doubled_n    = 1'b1;

                    user_total_n = user_total + next_value6;
                    p_cards_n = p_cards + 3'd1;
                    if (next_value == 4'd11) p_soft_n = p_soft + 3'd1;

                    if (user_total_n > 6'd21 && p_soft_n != 3'd0) begin
                        user_total_n = user_total_n - 6'd10;
                        p_soft_n     = p_soft_n - 3'd1;
                    end

                    if (user_total_n > 6'd21) nstate = S_SETTLE;
                    else nstate = S_DEALER;

                end else if (hit_p) begin
                    user_total_n = user_total + next_value6;
                    if (p_cards < 3'd5) p_cards_n = p_cards + 3'd1;
                    if (next_value == 4'd11) p_soft_n = p_soft + 3'd1;

                    // multiple soft ace reductions (max 3 needed)
                    if (user_total_n > 6'd21 && p_soft_n != 3'd0) begin
                        user_total_n = user_total_n - 6'd10;
                        p_soft_n     = p_soft_n - 3'd1;
                    end
                    if (user_total_n > 6'd21 && p_soft_n != 3'd0) begin
                        user_total_n = user_total_n - 6'd10;
                        p_soft_n     = p_soft_n - 3'd1;
                    end
                    if (user_total_n > 6'd21 && p_soft_n != 3'd0) begin
                        user_total_n = user_total_n - 6'd10;
                        p_soft_n     = p_soft_n - 3'd1;
                    end

                    // if (p_soft_n >= 3'd1) begin
                    //     user_total_n = user_total_n - ((p_soft_n - 1) * 6'd10);
                    //     p_soft_n     = 3'd1;
                    // end

                    // if (user_total_n > 6'd21 && p_soft_n != 3'd0) begin
                    //     user_total_n = user_total_n - 6'd10;
                    //     p_soft_n     = p_soft_n - 3'd1;
                    // end


                    if (user_total_n > 6'd21) nstate = S_SETTLE;
                    else if (user_total_n == 6'd21) nstate = S_DEALER;
                    else nstate = S_PLAYER;

                end else if (stand_p) begin
                    nstate = S_DEALER;
                end
            end

            S_DEALER: begin
                if (dealer_total >= 6'd17) begin
                    nstate = S_SETTLE;
                end else begin
                    dealer_total_n = dealer_total + next_value6;
                    if (d_cards < 3'd5) d_cards_n = d_cards + 3'd1;
                    if (next_value == 4'd11) d_soft_n = d_soft + 3'd1;

                    if (dealer_total_n > 6'd21 && d_soft_n != 3'd0) begin
                        dealer_total_n = dealer_total_n - 6'd10;
                        d_soft_n       = d_soft_n - 3'd1;
                    end
                    if (dealer_total_n > 6'd21 && d_soft_n != 3'd0) begin
                        dealer_total_n = dealer_total_n - 6'd10;
                        d_soft_n       = d_soft_n - 3'd1;
                    end

                    if (dealer_total_n >= 6'd17) nstate = S_SETTLE;
                    else nstate = S_DEALER;
                end
            end

            S_SETTLE: begin
                // settle once, then return idle
                if (is_natural_blackjack) begin
                    if (balance > (MAX_BAL - 10'd75))
                        balance_n = START_BAL;
                    else
                        balance_n = balance + 10'd75; // 1.5*50
                end else if (user_total > 6'd21) begin
                    if (balance < bet_amt)
                        balance_n = START_BAL;
                    else
                        balance_n = balance - bet_amt;
                end else if (dealer_total > 6'd21) begin
                    if (balance > (MAX_BAL - bet_amt))
                        balance_n = START_BAL;
                    else
                        balance_n = balance + bet_amt;
                end else if (user_total > dealer_total) begin
                    if (balance > (MAX_BAL - bet_amt))
                        balance_n = START_BAL;
                    else
                        balance_n = balance + bet_amt;
                end else if (user_total < dealer_total) begin
                    if (balance < bet_amt)
                        balance_n = START_BAL;
                    else
                        balance_n = balance - bet_amt;
                end else begin
                    balance_n = balance; // push
                end

                nstate = S_IDLE;
            end

            default: nstate = S_IDLE;
        endcase
    end

    // ----------------------------
    // Sequential update + card outputs (VALUES only)
    // ----------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            deal_count   <= 2'd0;

            user_total   <= 6'd0;
            dealer_total <= 6'd0;
            balance      <= START_BAL;

            p_cards      <= 3'd0;
            d_cards      <= 3'd0;
            doubled      <= 1'b0;
            p_soft       <= 3'd0;
            d_soft       <= 3'd0;

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
            state        <= nstate;
            deal_count   <= deal_count_n;

            user_total   <= user_total_n;
            dealer_total <= dealer_total_n;
            balance      <= balance_n;

            p_cards      <= p_cards_n;
            d_cards      <= d_cards_n;
            doubled      <= doubled_n;
            p_soft       <= p_soft_n;
            d_soft       <= d_soft_n;

            // clear cards when new round starts
            if (state == S_IDLE && start_p) begin
                dealer_card1_o <= 4'd0; dealer_card2_o <= 4'd0; dealer_card3_o <= 4'd0; dealer_card4_o <= 4'd0; dealer_card5_o <= 4'd0;
                player_card1_o <= 4'd0; player_card2_o <= 4'd0; player_card3_o <= 4'd0; player_card4_o <= 4'd0; player_card5_o <= 4'd0;
            end

            // init deal card placements
            if (state == S_INIT_DEAL) begin
                if (deal_count == 2'd0) player_card1_o <= next_value;
                else if (deal_count == 2'd1) player_card2_o <= next_value;
                else dealer_card1_o <= next_value;
            end

            // player draws (hit or double)
            if (state == S_PLAYER) begin
                if (hit_p || (double_p && (p_cards == 3'd2))) begin
                    if (player_card3_o == 4'd0) player_card3_o <= next_value;
                    else if (player_card4_o == 4'd0) player_card4_o <= next_value;
                    else if (player_card5_o == 4'd0) player_card5_o <= next_value;
                end
            end

            // dealer draws
            if (state == S_DEALER) begin
                if (dealer_total < 6'd17) begin
                    if (dealer_card2_o == 4'd0) dealer_card2_o <= next_value;
                    else if (dealer_card3_o == 4'd0) dealer_card3_o <= next_value;
                    else if (dealer_card4_o == 4'd0) dealer_card4_o <= next_value;
                    else if (dealer_card5_o == 4'd0) dealer_card5_o <= next_value;
                end
            end
        end
    end

    // ----------------------------
    // Balance to BCD (Double Dabble)
    // ----------------------------
    integer i;
    reg [25:0] shift;

    always @(*) begin
        shift = 26'd0;
        shift[9:0] = balance;

        for (i = 0; i < 10; i = i + 1) begin
            if (shift[13:10] >= 4'd5) shift[13:10] = shift[13:10] + 4'd3;
            if (shift[17:14] >= 4'd5) shift[17:14] = shift[17:14] + 4'd3;
            if (shift[21:18] >= 4'd5) shift[21:18] = shift[21:18] + 4'd3;
            if (shift[25:22] >= 4'd5) shift[25:22] = shift[25:22] + 4'd3;
            shift = shift << 1;
        end

        bal_d0 = shift[13:10];
        bal_d1 = shift[17:14];
        bal_d2 = shift[21:18];
        bal_d3 = shift[25:22];
    end

endmodule
