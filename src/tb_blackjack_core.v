`timescale 1ns/1ps
`default_nettype none

module tb_blackjack_core;

  // -------------------------
  // Clock / Reset
  // -------------------------
  logic clk;
  logic rst_n;

  initial clk = 1'b0;
  always #10 clk = ~clk;   // 50 MHz (period=20ns)

  // -------------------------
  // Inputs (buttons + RNG seed)
  // -------------------------
  logic btn_hit, btn_stand, btn_double, btn_start;
  logic rng_load;
  logic [15:0] rng_seed;

  // -------------------------
  // Outputs
  // -------------------------
  wire [5:0] user_total;
  wire [5:0] dealer_total;
  wire [9:0] balance;

  wire [4:0] dbg_last_card;
  wire [1:0] dbg_deal_count;
  wire       dbg_blackjack;

  wire [3:0] dealer_card1_o, dealer_card2_o, dealer_card3_o, dealer_card4_o, dealer_card5_o;
  wire [3:0] player_card1_o, player_card2_o, player_card3_o, player_card4_o, player_card5_o;

  // -------------------------
  // DUT
  // -------------------------
  blackjack_core dut (
    .clk(clk),
    .rst_n(rst_n),

    .btn_hit(btn_hit),
    .btn_stand(btn_stand),
    .btn_double(btn_double),
    .btn_start(btn_start),

    .rng_load(rng_load),
    .rng_seed(rng_seed),

    .user_total(user_total),
    .dealer_total(dealer_total),
    .balance(balance),

    .dbg_last_card(dbg_last_card),
    .dbg_deal_count(dbg_deal_count),
    .dbg_blackjack(dbg_blackjack),

    .dealer_card1_o(dealer_card1_o),
    .dealer_card2_o(dealer_card2_o),
    .dealer_card3_o(dealer_card3_o),
    .dealer_card4_o(dealer_card4_o),
    .dealer_card5_o(dealer_card5_o),

    .player_card1_o(player_card1_o),
    .player_card2_o(player_card2_o),
    .player_card3_o(player_card3_o),
    .player_card4_o(player_card4_o),
    .player_card5_o(player_card5_o)
  );

  // -------------------------
  // Helpers
  // -------------------------
  task automatic wait_cycles(input int n);
    repeat (n) @(posedge clk);
  endtask

  task automatic pulse_start();
    btn_start <= 1'b1;
    @(posedge clk);
    btn_start <= 1'b0;
  endtask

  task automatic pulse_hit();
    btn_hit <= 1'b1;
    @(posedge clk);
    btn_hit <= 1'b0;
  endtask

  task automatic pulse_stand();
    btn_stand <= 1'b1;
    @(posedge clk);
    btn_stand <= 1'b0;
  endtask

  task automatic pulse_double();
    btn_double <= 1'b1;
    @(posedge clk);
    btn_double <= 1'b0;
  endtask

  function automatic int count_player_cards();
    int c;
    begin
      c = 0;
      if (player_card1_o != 0) c++;
      if (player_card2_o != 0) c++;
      if (player_card3_o != 0) c++;
      if (player_card4_o != 0) c++;
      if (player_card5_o != 0) c++;
      return c;
    end
  endfunction

  function automatic int count_dealer_cards();
    int c;
    begin
      c = 0;
      if (dealer_card1_o != 0) c++;
      if (dealer_card2_o != 0) c++;
      if (dealer_card3_o != 0) c++;
      if (dealer_card4_o != 0) c++;
      if (dealer_card5_o != 0) c++;
      return c;
    end
  endfunction

  task automatic print_round_state(string tag);
    $display("---- %s ----", tag);
    $display("Balance=%0d  user_total=%0d  dealer_total=%0d  blackjack=%0b  deal_count=%0d last_card=%0d",
             balance, user_total, dealer_total, dbg_blackjack, dbg_deal_count, dbg_last_card);
    $display("Player cards: %0d %0d %0d %0d %0d",
             player_card1_o, player_card2_o, player_card3_o, player_card4_o, player_card5_o);
    $display("Dealer cards: %0d %0d %0d %0d %0d",
             dealer_card1_o, dealer_card2_o, dealer_card3_o, dealer_card4_o, dealer_card5_o);
  endtask

  // Wait until initial deal finished (deal_count == 3)
  task automatic wait_init_deal_done();
    int timeout;
    begin
      timeout = 0;
      while (dbg_deal_count != 2'd3) begin
        @(posedge clk);
        timeout++;
        if (timeout > 2000) begin
          $fatal(1, "Timeout waiting for initial deal to complete (dbg_deal_count never reached 3)");
        end
      end
    end
  endtask

  // Wait until round finishes: detect balance change OR return-to-idle behavior
  // Since state isn't exposed, simplest reliable signal is: balance changes after settlement.
  task automatic wait_round_done(input int old_balance);
    int timeout;
    begin
      timeout = 0;
      while (balance == old_balance) begin
        @(posedge clk);
        timeout++;
        if (timeout > 5000) begin
          print_round_state("TIMEOUT SNAPSHOT");
          $fatal(1, "Timeout waiting for round to settle (balance did not change)");
        end
      end
    end
  endtask

  // Compute expected delta using the SAME policy as core:
  // - natural blackjack: +75
  // - bust: -50 (or -100 if doubled)
  // - win: +50 (+50 extra if doubled)
  // - lose: -50 (-50 extra if doubled)
  // - push: 0
  function automatic int expected_delta(input int u, input int d, input bit doubled, input bit blackjack);
    if (blackjack) begin
      return 75;
    end
    if (u > 21) begin
      return doubled ? -100 : -50;
    end
    if ((d > 21) || (u > d)) begin
      return doubled ? +100 : +50;
    end
    if (u < d) begin
      return doubled ? -100 : -50;
    end
    return 0;
  endfunction

  // One full round that "plays like a human"
  // policy:
  //   - optionally double if user_total is 9/10/11 on first decision
  //   - hit until user_total >= 17, then stand
  task automatic play_one_round(input int round_idx, input bit allow_double);
    int old_bal;
    bit doubled_this_round;
    int u_final, d_final;
    int exp_d, got_d;

    begin
      doubled_this_round = 0;

      $display("\n==============================");
      $display("ROUND %0d", round_idx);
      $display("==============================");

      old_bal = balance;

      // Press START
      pulse_start();

      // Wait for the 3-step deal to finish
      wait_init_deal_done();
      print_round_state("AFTER INIT DEAL");

      // If blackjack, core will go straight to settlement
      if (dbg_blackjack) begin
        $display("Natural blackjack detected -> no user actions.");
      end else begin
        // Decision loop: act once per clock like a real button press
        // First decision: optionally DOUBLE if favorable and allowed
        if (allow_double) begin
          if ((user_total == 9) || (user_total == 10) || (user_total == 11)) begin
            $display("User decision: DOUBLE (user_total=%0d)", user_total);
            doubled_this_round = 1;
            pulse_double();
          end
        end

        // If we didn't double: hit until 17, then stand
        if (!doubled_this_round) begin
          while ((user_total < 17) && (user_total <= 21)) begin
            $display("User decision: HIT (user_total=%0d)", user_total);
            pulse_hit();
            // give one cycle for totals/cards to update cleanly
            @(posedge clk);
          end
          $display("User decision: STAND (user_total=%0d)", user_total);
          pulse_stand();
        end
      end

      // Wait until balance changes => settlement done
      wait_round_done(old_bal);

      // Snapshot at end
      print_round_state("AFTER SETTLEMENT");

      // Check expected balance delta
      u_final = user_total;
      d_final = dealer_total;
      exp_d   = expected_delta(u_final, d_final, doubled_this_round, dbg_blackjack);
      got_d   = $signed(balance) - $signed(old_bal);

      $display("Expected delta=%0d  Got delta=%0d", exp_d, got_d);

      if (exp_d !== got_d) begin
        $display("!! MISMATCH in balance update");
        $display("   (u=%0d d=%0d doubled=%0b blackjack=%0b)", u_final, d_final, doubled_this_round, dbg_blackjack);
        $fatal(1, "Balance delta mismatch");
      end

      // Wait a little so core returns to IDLE before next round
      wait_cycles(5);
    end
  endtask

  // -------------------------
  // Test sequence
  // -------------------------
  initial begin
    // init inputs
    btn_hit    = 0;
    btn_stand  = 0;
    btn_double = 0;
    btn_start  = 0;
    rng_load   = 0;
    rng_seed   = 16'h0000;

    // reset
    rst_n = 0;
    wait_cycles(5);
    rst_n = 1;
    wait_cycles(2);

    // Seed RNG deterministically
    // (Change seed to see different games, but keep reproducible)
    rng_seed = 16'hACE1;
    rng_load = 1'b1;
    @(posedge clk);
    rng_load = 1'b0;
    $display("RNG seeded with 0x%04h", rng_seed);

    // Starting balance should be 500 after reset
    if (balance !== 10'd500) begin
      $fatal(1, "Expected starting balance 500, got %0d", balance);
    end

    // Play a few rounds:
    // Round 1: no double
    play_one_round(1, /*allow_double=*/0);

    // Round 2: allow double
    play_one_round(2, /*allow_double=*/1);

    // Round 3: allow double
    play_one_round(3, /*allow_double=*/1);

    $display("\nALL ROUNDS PASSED ✅");
    $finish;
  end

endmodule
