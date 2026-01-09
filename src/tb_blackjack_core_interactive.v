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

  // balance digits (BCD)
  wire [3:0] bal_d3, bal_d2, bal_d1, bal_d0;
  wire [9:0] balance_num;
  wire [9:0] balance;


  // cards
  wire [3:0] dealer_card1_o, dealer_card2_o, dealer_card3_o, dealer_card4_o, dealer_card5_o;
  wire [3:0] player_card1_o, player_card2_o, player_card3_o, player_card4_o, player_card5_o;

  // FSM encoding (must match core if you peek dut.state)
  localparam S_IDLE        = 3'd0;
  localparam S_INIT_DEAL   = 3'd1;
  localparam S_PLAYER_TURN = 3'd2;
  localparam S_DEALER_TURN = 3'd3;
  localparam S_UPDATE_BAL  = 3'd4;

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

    .bal_d3         (bal_d3),
    .bal_d2         (bal_d2),
    .bal_d1         (bal_d1),
    .bal_d0         (bal_d0),

    .dealer_card1_o (dealer_card1_o),
    .dealer_card2_o (dealer_card2_o),
    .dealer_card3_o (dealer_card3_o),
    .dealer_card4_o (dealer_card4_o),
    .dealer_card5_o (dealer_card5_o),

    .player_card1_o (player_card1_o),
    .player_card2_o (player_card2_o),
    .player_card3_o (player_card3_o),
    .player_card4_o (player_card4_o),
    .player_card5_o (player_card5_o),
    .balance(balance)
  );

  assign balance_num = (bal_d3 * 10'd1000) + (bal_d2 * 10'd100) + (bal_d1 * 10'd10) + (bal_d0);

  // 50MHz clock
  initial begin
    clk = 1'b0;
    forever #10 clk = ~clk;
  end

  integer i;
  integer t;
  integer ch;
  integer round;
  reg [9:0] bal_before;
  reg in_round;
  reg do_finish;

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

    // reset
    for (i = 0; i < 5; i = i + 1) @(posedge clk);
    rst_n = 1'b1;
    for (i = 0; i < 2; i = i + 1) @(posedge clk);

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

      // START pulse 1 clock
      bal_before = balance_num;

      btn_hit    = 1'b0;
      btn_stand  = 1'b0;
      btn_double = 1'b0;
      btn_start  = 1'b0;

      @(negedge clk);
      btn_start = 1'b1;
      @(posedge clk);
      @(negedge clk);
      btn_start = 1'b0;

      // wait deal done: wait until state leaves INIT_DEAL
      for (i = 0; i < 2; i = i + 1) @(posedge clk);
      t = 0;
      while ((dut.state == S_INIT_DEAL) && (t < 4000)) begin
        @(posedge clk);
        t = t + 1;
      end
      if (t >= 4000) $display("ERROR: deal_done timeout (stuck INIT_DEAL)");

      $display("After deal: balance=%0d digits=%0d%0d%0d%0d  user_total=%0d dealer_total=%0d state=%0d",
               balance_num, bal_d3, bal_d2, bal_d1, bal_d0, user_total, dealer_total, dut.state);
      $display("Cards P:[%0d %0d %0d %0d %0d] D:[%0d %0d %0d %0d %0d]",
               player_card1_o, player_card2_o, player_card3_o, player_card4_o, player_card5_o,
               dealer_card1_o, dealer_card2_o, dealer_card3_o, dealer_card4_o, dealer_card5_o);

      // interactive loop
      in_round = 1'b1;
      while (in_round) begin
        $display("");
        $display("Balance=%0d digits=%0d%0d%0d%0d  User=%0d Dealer=%0d state=%0d",
                 balance_num, bal_d3, bal_d2, bal_d1, bal_d0, user_total, dealer_total, dut.state);
        $display("Choose: h=hit, s=stand, d=double, q=quit");

        // read a non-newline char
        ch = 10;
        while (ch == 10 || ch == 13) ch = $fgetc(32'h8000_0000);

        do_finish = 1'b0;

        // default buttons low
        btn_hit    = 1'b0;
        btn_stand  = 1'b0;
        btn_double = 1'b0;
        btn_start  = 1'b0;

        if (ch == "q" || ch == "Q") begin
          $display("Quit.");
          $finish;

        end else if (ch == "h" || ch == "H") begin
          $display("Action: HIT");
          @(negedge clk); btn_hit = 1'b1;
          @(posedge clk);
          @(negedge clk); btn_hit = 1'b0;

          for (i = 0; i < 6; i = i + 1) @(posedge clk);

          if (user_total >= 21) do_finish = 1'b1;
          if (dut.state != S_PLAYER_TURN) do_finish = 1'b1;

        end else if (ch == "s" || ch == "S") begin
          $display("Action: STAND");
          @(negedge clk); btn_stand = 1'b1;
          @(posedge clk);
          @(negedge clk); btn_stand = 1'b0;
          do_finish = 1'b1;

        end else if (ch == "d" || ch == "D") begin
          $display("Action: DOUBLE");
          @(negedge clk); btn_double = 1'b1;
          @(posedge clk);
          @(negedge clk); btn_double = 1'b0;
          do_finish = 1'b1;

        end else begin
          $display("Unknown key '%0d'. Use h/s/d/q.", ch);
        end

        if (do_finish) begin
          bal_before = balance_num;

          // wait round end (back to IDLE)
          t = 0;
          while ((dut.state != S_IDLE) && (t < 20000)) begin
            @(posedge clk);
            t = t + 1;
          end
          if (t >= 20000) $display("ERROR: round_done timeout");

          $display("FINAL: balance=%0d digits=%0d%0d%0d%0d  user_total=%0d dealer_total=%0d",
                   balance_num, bal_d3, bal_d2, bal_d1, bal_d0, user_total, dealer_total);
          $display("Cards P:[%0d %0d %0d %0d %0d] D:[%0d %0d %0d %0d %0d]",
                   player_card1_o, player_card2_o, player_card3_o, player_card4_o, player_card5_o,
                   dealer_card1_o, dealer_card2_o, dealer_card3_o, dealer_card4_o, dealer_card5_o);

          if (balance_num > bal_before) $display("RESULT: PLAYER WIN (+%0d)", (balance_num - bal_before));
          else if (balance_num < bal_before) $display("RESULT: PLAYER LOSE (%0d)", (balance_num - bal_before));
          else $display("RESULT: PUSH (tie)");

          round = round + 1;
          for (i = 0; i < 10; i = i + 1) @(posedge clk);

          in_round = 1'b0; // exit interactive loop -> next round
        end
      end
    end
  end

endmodule
