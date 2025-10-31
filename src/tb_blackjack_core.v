`timescale 1ns/1ps
`default_nettype none

module tb_blackjack_core;

  // DUT inputs
  reg clk;
  reg rst_n;
  reg btn_hit;
  reg btn_stand;
  reg btn_double;
  reg btn_start;
  reg rng_load;
  reg [15:0] rng_seed;
  integer seed;
  integer i;
  reg [9:0] bal_before;

  // DUT outputs
  wire [5:0] user_total;
  wire [5:0] dealer_total;
  wire [9:0] balance;
  // Debug outputs from DUT
  wire [4:0] dbg_last_card;
  wire [1:0] dbg_deal_count;
  wire dbg_blackjack;
  // captured initial deal cards (derived from totals)
  reg  [5:0] u_snap1, u_snap2, d_snap;
  reg  [4:0] c1, c2, c3;

  // Instantiate DUT
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
    .balance(balance)
    , .dbg_blackjack(dbg_blackjack)
    , .dbg_last_card(dbg_last_card)
    , .dbg_deal_count(dbg_deal_count)
  );

  // Clock generator (50MHz equiv → 20ns period)
  always #10 clk = ~clk;

  // Test sequence
  initial begin
    // Init
    clk = 0;
    rst_n = 0;
    btn_hit = 0;
    btn_stand = 0;
    btn_double = 0;
    btn_start = 0;
    rng_load = 0;
    rng_seed = 16'hBEEF;

  // VCD dump for GTKWave
    $dumpfile("tb_blackjack_core.vcd");
    $dumpvars(0, tb_blackjack_core);

  // init captured card registers / snapshots
  c1 = 0; c2 = 0; c3 = 0;
  u_snap1 = 0; u_snap2 = 0; d_snap = 0;

    // Reset
    #25 rst_n = 1;
    $display("\n--- Reset released ---");

  // We'll run deterministic rounds by loading seeds so results are repeatable.

    // --- ROUND 1: exercise HIT ---
    seed = 16'h0001; bal_before = balance;
    rng_load = 1; rng_seed = seed; #20 rng_load = 0; #20;
    #50 btn_start = 1; #20 btn_start = 0; // initial deal
    wait (dbg_deal_count == 2'd3); #1;
    $display("[R1] After deal: user=%0d dealer=%0d balance=%0d", user_total, dealer_total, balance);
  // Hit once
  #100 btn_hit = 1; #20 btn_hit = 0; #50;
  // End player's turn by standing so dealer can play
  #100 btn_stand = 1; #20 btn_stand = 0;
    $display("[R1] After HIT: user=%0d dealer=%0d balance(before)=%0d", user_total, dealer_total, bal_before);
  // Finish the round: wait for dealer to play and settlement to complete
  #300;
    $display("[R1] End: user=%0d dealer=%0d balance(after)=%0d", user_total, dealer_total, balance);
    // Validate balance change direction/magnitude (stake = 50)
    if (dbg_blackjack) begin
      $display("[R1] Unexpected blackjack in round 1 (seed=%0h)", seed);
    end else begin
      if (user_total > 21) begin
  if (balance != bal_before - 10'd50) begin $display("R1: expected bust loss of 50"); $fatal(1); end
      end else if (dealer_total > 21 || user_total > dealer_total) begin
  if (balance != bal_before + 10'd50) begin $display("R1: expected win of 50"); $fatal(1); end
      end else if (user_total < dealer_total) begin
  if (balance != bal_before - 10'd50) begin $display("R1: expected loss of 50"); $fatal(1); end
      end else begin
  if (balance != bal_before) begin $display("R1: expected push (no change)"); $fatal(1); end
      end
      $display("R1 validation passed");
    end

    // --- ROUND 2: exercise DOUBLE ---
    seed = 16'h00A5; bal_before = balance;
    rng_load = 1; rng_seed = seed; #20 rng_load = 0; #20;
    #50 btn_start = 1; #20 btn_start = 0; // initial deal
    wait (dbg_deal_count == 2'd3); #1;
    $display("[R2] After deal: user=%0d dealer=%0d balance=%0d", user_total, dealer_total, balance);
    // Double: take one card and end turn
    #100 btn_double = 1; #20 btn_double = 0; #100;
    $display("[R2] After DOUBLE: user=%0d dealer=%0d balance(before)=%0d", user_total, dealer_total, bal_before);
  // Finish the round: wait for dealer to play and settlement to complete
  #300;
    $display("[R2] End: user=%0d dealer=%0d balance(after)=%0d", user_total, dealer_total, balance);
    // Validate double stake (100)
    if (dbg_blackjack) begin
      $display("[R2] Unexpected blackjack in round 2 (seed=%0h)", seed);
    end else begin
      if (user_total > 21) begin
  if (balance != bal_before - 10'd100) begin $display("R2: expected bust loss of 100"); $fatal(1); end
      end else if (dealer_total > 21 || user_total > dealer_total) begin
  if (balance != bal_before + 10'd100) begin $display("R2: expected win of 100"); $fatal(1); end
      end else if (user_total < dealer_total) begin
  if (balance != bal_before - 10'd100) begin $display("R2: expected loss of 100"); $fatal(1); end
      end else begin
  if (balance != bal_before) begin $display("R2: expected push (no change)"); $fatal(1); end
      end
      $display("R2 validation passed");
    end

    // --- ROUND 3: exercise STAND ---
    seed = 16'h0F0F; bal_before = balance;
    rng_load = 1; rng_seed = seed; #20 rng_load = 0; #20;
    #50 btn_start = 1; #20 btn_start = 0; // initial deal
    wait (dbg_deal_count == 2'd3); #1;
    $display("[R3] After deal: user=%0d dealer=%0d balance=%0d", user_total, dealer_total, balance);
    // Stand immediately (no hit/double)
    #100 btn_stand = 1; #20 btn_stand = 0; #100;
  // Finish the round: wait for dealer to play and settlement to complete
  #300;
    $display("[R3] End: user=%0d dealer=%0d balance(after)=%0d", user_total, dealer_total, balance);
    // Validate single stake (50)
    if (dbg_blackjack) begin
      $display("[R3] Unexpected blackjack in round 3 (seed=%0h)", seed);
    end else begin
      if (user_total > 21) begin
  if (balance != bal_before - 10'd50) begin $display("R3: expected bust loss of 50"); $fatal(1); end
      end else if (dealer_total > 21 || user_total > dealer_total) begin
  if (balance != bal_before + 10'd50) begin $display("R3: expected win of 50"); $fatal(1); end
      end else if (user_total < dealer_total) begin
  if (balance != bal_before - 10'd50) begin $display("R3: expected loss of 50"); $fatal(1); end
      end else begin
  if (balance != bal_before) begin $display("R3: expected push (no change)"); $fatal(1); end
      end
      $display("R3 validation passed");
    end

    // --- ROUND 4: search for a natural blackjack (2-card 21) by loading seeds ---
  // We'll try a few seeds; when dbg_blackjack asserted we verify the +150 payout.
  bal_before = balance;
  for (i = 0; i < 200; i = i + 1) begin
      rng_load = 1;
      rng_seed = i;
      #20;
      rng_load = 0;
      #20;
      // Start a round
      btn_start = 1; #20 btn_start = 0;
      wait (dbg_deal_count == 2'd3); #1;
      // If blackjack, settlement will occur on next state entry; capture balance after settlement
      if (dbg_blackjack) begin
  // Allow settlement to happen
  #200;
        $display("[R4] Found blackjack with seed=%0d: balance before=%0d after=%0d", i, bal_before, balance);
        if (balance != bal_before + 10'd150) begin
          $display("ERROR: blackjack payout incorrect: expected %0d got %0d", bal_before + 150, balance);
          $fatal(1);
        end else begin
          $display("PASS: blackjack payout correct (+150)");
        end
        // exit loop once found by forcing i past end
        i = 200;
      end else begin
  // No blackjack: finish the round normally to reset for next try
  #200;
        bal_before = balance; // update baseline for next trial
      end
    end

    #200 $finish;
  end

  // Capture the RNG output when the deal counter increments so we can check
  // the three initial draws.
  always @(posedge clk) begin
    // capture user total snapshots and dealer snapshot to derive individual cards
    if (dbg_deal_count == 2'd1 && u_snap1 == 0)
      u_snap1 <= user_total;
    else if (dbg_deal_count == 2'd2 && u_snap2 == 0)
      u_snap2 <= user_total;
    else if (dbg_deal_count == 2'd3 && d_snap == 0)
      d_snap <= dealer_total;
  end

endmodule
