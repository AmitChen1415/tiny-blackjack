`timescale 1ns/1ps

module tb_blackjack_core_interactive;

  // clock/reset
  reg clk;
  reg rst_n;

  // buttons
  reg btn_hit;
  reg btn_stand;
  reg btn_double;
  reg btn_start;

  // RNG seeding
  reg        rng_load;
  reg [15:0] rng_seed;

  // DUT outputs
  wire [5:0] user_total;
  wire [5:0] dealer_total;
  wire [9:0] balance;

  wire [4:0] dbg_last_card;
  wire [1:0] dbg_deal_count;
  wire       dbg_blackjack;

  wire [3:0] dealer_card1_o, dealer_card2_o, dealer_card3_o, dealer_card4_o, dealer_card5_o;
  wire [3:0] player_card1_o, player_card2_o, player_card3_o, player_card4_o, player_card5_o;

  // DUT
  blackjack_core dut (
    .clk            (clk),
    .rst_n          (rst_n),

    .btn_hit        (btn_hit),
    .btn_stand      (btn_stand),
    .btn_double     (btn_double),
    .btn_start      (btn_start),

    .rng_load       (rng_load),
    .rng_seed       (rng_seed),

    .user_total     (user_total),
    .dealer_total   (dealer_total),
    .balance        (balance),

    .dbg_last_card  (dbg_last_card),
    .dbg_deal_count (dbg_deal_count),
    .dbg_blackjack  (dbg_blackjack),

    .dealer_card1_o (dealer_card1_o),
    .dealer_card2_o (dealer_card2_o),
    .dealer_card3_o (dealer_card3_o),
    .dealer_card4_o (dealer_card4_o),
    .dealer_card5_o (dealer_card5_o),

    .player_card1_o (player_card1_o),
    .player_card2_o (player_card2_o),
    .player_card3_o (player_card3_o),
    .player_card4_o (player_card4_o),
    .player_card5_o (player_card5_o)
  );

  // clock: 50MHz
  initial begin
    clk = 1'b0;
    forever #10 clk = ~clk;
  end

  // 1-cycle button press
  task press_one_clk;
    input [1:0] which; // 0=hit,1=stand,2=double,3=start
    begin
      btn_hit    = 1'b0;
      btn_stand  = 1'b0;
      btn_double = 1'b0;
      btn_start  = 1'b0;

      @(negedge clk);
      if (which == 2'd0) btn_hit    = 1'b1;
      if (which == 2'd1) btn_stand  = 1'b1;
      if (which == 2'd2) btn_double = 1'b1;
      if (which == 2'd3) btn_start  = 1'b1;

      @(posedge clk);
      @(negedge clk);

      btn_hit    = 1'b0;
      btn_stand  = 1'b0;
      btn_double = 1'b0;
      btn_start  = 1'b0;
    end
  endtask

  task wait_cycles;
    input integer n;
    integer i;
    begin
      for (i = 0; i < n; i = i + 1) @(posedge clk);
    end
  endtask

  task wait_deal_done;
    integer t;
    begin
      t = 0;
      while (dbg_deal_count != 2'd3 && t < 500) begin
        @(posedge clk);
        t = t + 1;
      end
      if (dbg_deal_count != 2'd3) $display("ERROR: deal_count timeout");
    end
  endtask

  task wait_settlement;
    input [9:0] bal_before;
    integer t;
    begin
      t = 0;
      while (balance == bal_before && t < 2000) begin
        @(posedge clk);
        t = t + 1;
      end
      if (balance == bal_before) $display("ERROR: settlement timeout");
    end
  endtask

  integer ch;
  integer round;
  reg [9:0] bal_before;
  reg in_round;      // 1 while waiting for user actions
  reg do_settle;     // request settle after action
  reg [1:0] act;     // 0 hit,1 stand,2 double

  initial begin
    // init
    rst_n      = 1'b0;
    btn_hit    = 1'b0;
    btn_stand  = 1'b0;
    btn_double = 1'b0;
    btn_start  = 1'b0;
    rng_load   = 1'b0;
    rng_seed   = 16'h0000;

    $dumpfile("tb_blackjack_core_interactive.vcd");
    $dumpvars(0, tb_blackjack_core_interactive);

    wait_cycles(5);
    rst_n = 1'b1;
    wait_cycles(2);

    // seed RNG once
    rng_seed = 16'hACE1;
    @(negedge clk);
    rng_load = 1'b1;
    @(posedge clk);
    @(negedge clk);
    rng_load = 1'b0;
    $display("RNG seeded with 0x%h", rng_seed);

    round = 1;

    while (1) begin
      $display("");
      $display("=============== ROUND %0d ===============", round);

      // start round
      bal_before = balance;
      press_one_clk(2'd3); // start

      wait_deal_done();

      $display("After deal: balance=%0d user=%0d dealer=%0d blackjack=%0d",
               balance, user_total, dealer_total, dbg_blackjack);
      $display("Cards P:[%0d %0d %0d %0d %0d] D:[%0d %0d %0d %0d %0d]",
               player_card1_o, player_card2_o, player_card3_o, player_card4_o, player_card5_o,
               dealer_card1_o, dealer_card2_o, dealer_card3_o, dealer_card4_o, dealer_card5_o);

      // natural blackjack -> settle
      if (dbg_blackjack) begin
        $display("Natural blackjack -> settling...");
        wait_settlement(bal_before);
        $display("End round: balance=%0d user=%0d dealer=%0d", balance, user_total, dealer_total);
        round = round + 1;
        wait_cycles(10);
      end else begin
        in_round  = 1'b1;

        while (in_round) begin
          do_settle = 1'b0;
          act       = 2'd0;

          $display("");
          $display("Balance=%0d  User=%0d  Dealer=%0d  last_card=%0d",
                   balance, user_total, dealer_total, dbg_last_card);
          $display("Choose: h=hit, s=stand, d=double, q=quit");

          ch = $fgetc(32'h8000_0000); // stdin

          // ignore newline
          if (ch == 10 || ch == 13) begin
            // no-op
          end else if (ch == "q" || ch == "Q") begin
            $display("Quit.");
            $finish;
          end else if (ch == "h" || ch == "H") begin
            $display("Action: HIT");
            press_one_clk(2'd0);
            wait_cycles(6);

            // if 21 or bust -> settle
            if (user_total >= 21) begin
              do_settle = 1'b1;
            end
          end else if (ch == "s" || ch == "S") begin
            $display("Action: STAND");
            press_one_clk(2'd1);
            do_settle = 1'b1;
          end else if (ch == "d" || ch == "D") begin
            $display("Action: DOUBLE");
            press_one_clk(2'd2);
            do_settle = 1'b1;
          end else begin
            $display("Unknown key '%0d'. Use h/s/d/q.", ch);
          end

          if (do_settle) begin
            bal_before = balance;
            wait_settlement(bal_before);
            $display("End round: balance=%0d user=%0d dealer=%0d", balance, user_total, dealer_total);
            round = round + 1;
            wait_cycles(10);
            in_round = 1'b0; // exit loop without break
          end
        end
      end
    end
  end

endmodule
