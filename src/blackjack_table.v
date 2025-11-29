// ============================================================================
// blackjack_table.v  (640x480 @ 25 MHz)
// Felt background, up to 5 dealer + 5 player cards, "BLACKJACK" in center,
// "Balance: $1100" at left-middle (red), a face-down deck on right-middle.
//
//  - 10 inputs for card values:
//      dealer_card1..5, player_card1..5
//  - Each input is 4-bit value: 0 = no card, 1–9 = digit drawn on the card.
//  - Card positions are fixed. Card 1 is left-most, others are added to the right.
//  - Each card shows:
//        * value at top-left
//        * value at bottom-right
//        * red diamond in the card center
// ============================================================================

module blackjack_table (
    input  wire        clk_25MHz,
    input  wire        rst_n,

    // Dealer cards (top row)
    input  wire [3:0]  dealer_card1,
    input  wire [3:0]  dealer_card2,
    input  wire [3:0]  dealer_card3,
    input  wire [3:0]  dealer_card4,
    input  wire [3:0]  dealer_card5,

    // Player cards (bottom row)
    input  wire [3:0]  player_card1,
    input  wire [3:0]  player_card2,
    input  wire [3:0]  player_card3,
    input  wire [3:0]  player_card4,
    input  wire [3:0]  player_card5,

    output wire        vga_hsync,
    output wire        vga_vsync,
    output reg  [1:0]  vga_r,
    output reg  [1:0]  vga_g,
    output reg  [1:0]  vga_b
);

    // -------------------------
    // Timing / coordinates
    // -------------------------
    wire [9:0] x, y;
    vga_controller vga_ctrl (
        .pixel_clk(clk_25MHz),
        .rst_n    (rst_n),
        .hsync    (vga_hsync),
        .vsync    (vga_vsync),
        .x_count  (x),
        .y_count  (y)
    );

    wire active = (x < 640) && (y < 480);

    // -------------------------
    // Layout (up to 5 cards each, fixed positions)
    // -------------------------
    localparam CARD_W   = 70;
    localparam CARD_H   = 100;
    localparam CARD_GAP = 8;       // visible green strip between cards
    localparam BORDER   = 2;

    // Center 5 cards around x = 320:
    // total width = 5*CARD_W + 4*CARD_GAP
    localparam TOTAL_W  = 5*CARD_W + 4*CARD_GAP;
    localparam BASE_X   = 320 - (TOTAL_W/2);   // left-most card

    // Dealer (top)
    localparam D_Y  = 60;
    localparam D_X0 = BASE_X;
    localparam D_X1 = BASE_X + (CARD_W+CARD_GAP)*1;
    localparam D_X2 = BASE_X + (CARD_W+CARD_GAP)*2;
    localparam D_X3 = BASE_X + (CARD_W+CARD_GAP)*3;
    localparam D_X4 = BASE_X + (CARD_W+CARD_GAP)*4;

    // Player (bottom)
    localparam P_Y  = 300;
    localparam P_X0 = BASE_X;
    localparam P_X1 = BASE_X + (CARD_W+CARD_GAP)*1;
    localparam P_X2 = BASE_X + (CARD_W+CARD_GAP)*2;
    localparam P_X3 = BASE_X + (CARD_W+CARD_GAP)*3;
    localparam P_X4 = BASE_X + (CARD_W+CARD_GAP)*4;

    // -------------------------
    // Deck (right-middle, opposite "Balance")
    // -------------------------
    localparam DECK_W = 60;
    localparam DECK_H = 90;
    localparam DECK_X = 640 - 40 - DECK_W;                  // right margin ~40
    localparam DECK_Y = 240 - (DECK_H/2);                   // vertical center
    localparam DECK_BORDER = 2;

    // Slight back layer for "thickness"
    localparam DECK2_DX = -4;
    localparam DECK2_DY = -4;

    // -------------------------
    // Colors (2-bit each)
    // -------------------------
    localparam [1:0] C0      = 2'b00; // black
    localparam [1:0] C1      = 2'b01; // gray
    localparam [1:0] C2      = 2'b11; // white
    localparam [1:0] G_DARK  = 2'b10; // felt

    // -------------------------
    // Card presence (0 => no card drawn at all)
    // -------------------------
    wire d0_has = (dealer_card1 != 4'd0);
    wire d1_has = (dealer_card2 != 4'd0);
    wire d2_has = (dealer_card3 != 4'd0);
    wire d3_has = (dealer_card4 != 4'd0);
    wire d4_has = (dealer_card5 != 4'd0);

    wire p0_has = (player_card1 != 4'd0);
    wire p1_has = (player_card2 != 4'd0);
    wire p2_has = (player_card3 != 4'd0);
    wire p3_has = (player_card4 != 4'd0);
    wire p4_has = (player_card5 != 4'd0);

    // -------------------------
    // Primitive areas: card rectangles
    // -------------------------
    // dealer fills
    wire d0_fill = (x >= D_X0) && (x < D_X0+CARD_W) &&
                   (y >= D_Y  ) && (y < D_Y+CARD_H);
    wire d1_fill = (x >= D_X1) && (x < D_X1+CARD_W) &&
                   (y >= D_Y  ) && (y < D_Y+CARD_H);
    wire d2_fill = (x >= D_X2) && (x < D_X2+CARD_W) &&
                   (y >= D_Y  ) && (y < D_Y+CARD_H);
    wire d3_fill = (x >= D_X3) && (x < D_X3+CARD_W) &&
                   (y >= D_Y  ) && (y < D_Y+CARD_H);
    wire d4_fill = (x >= D_X4) && (x < D_X4+CARD_W) &&
                   (y >= D_Y  ) && (y < D_Y+CARD_H);

    // player fills
    wire p0_fill = (x >= P_X0) && (x < P_X0+CARD_W) &&
                   (y >= P_Y  ) && (y < P_Y+CARD_H);
    wire p1_fill = (x >= P_X1) && (x < P_X1+CARD_W) &&
                   (y >= P_Y  ) && (y < P_Y+CARD_H);
    wire p2_fill = (x >= P_X2) && (x < P_X2+CARD_W) &&
                   (y >= P_Y  ) && (y < P_Y+CARD_H);
    wire p3_fill = (x >= P_X3) && (x < P_X3+CARD_W) &&
                   (y >= P_Y  ) && (y < P_Y+CARD_H);
    wire p4_fill = (x >= P_X4) && (x < P_X4+CARD_W) &&
                   (y >= P_Y  ) && (y < P_Y+CARD_H);

    // dealer borders
    wire d0_brd =
       ((x >= D_X0              ) && (x < D_X0+CARD_W       ) && (y >= D_Y               ) && (y < D_Y+BORDER        )) || // top
       ((x >= D_X0              ) && (x < D_X0+CARD_W       ) && (y >= D_Y+CARD_H-BORDER ) && (y < D_Y+CARD_H        )) || // bottom
       ((x >= D_X0              ) && (x < D_X0+BORDER       ) && (y >= D_Y               ) && (y < D_Y+CARD_H        )) || // left
       ((x >= D_X0+CARD_W-BORDER) && (x < D_X0+CARD_W       ) && (y >= D_Y               ) && (y < D_Y+CARD_H        ));  // right

    wire d1_brd =
       ((x >= D_X1              ) && (x < D_X1+CARD_W       ) && (y >= D_Y               ) && (y < D_Y+BORDER        )) ||
       ((x >= D_X1              ) && (x < D_X1+CARD_W       ) && (y >= D_Y+CARD_H-BORDER ) && (y < D_Y+CARD_H        )) ||
       ((x >= D_X1              ) && (x < D_X1+BORDER       ) && (y >= D_Y               ) && (y < D_Y+CARD_H        )) ||
       ((x >= D_X1+CARD_W-BORDER) && (x < D_X1+CARD_W       ) && (y >= D_Y               ) && (y < D_Y+CARD_H        ));

    wire d2_brd =
       ((x >= D_X2              ) && (x < D_X2+CARD_W       ) && (y >= D_Y               ) && (y < D_Y+BORDER        )) ||
       ((x >= D_X2              ) && (x < D_X2+CARD_W       ) && (y >= D_Y+CARD_H-BORDER ) && (y < D_Y+CARD_H        )) ||
       ((x >= D_X2              ) && (x < D_X2+BORDER       ) && (y >= D_Y               ) && (y < D_Y+CARD_H        )) ||
       ((x >= D_X2+CARD_W-BORDER) && (x < D_X2+CARD_W       ) && (y >= D_Y               ) && (y < D_Y+CARD_H        ));

    wire d3_brd =
       ((x >= D_X3              ) && (x < D_X3+CARD_W       ) && (y >= D_Y               ) && (y < D_Y+BORDER        )) ||
       ((x >= D_X3              ) && (x < D_X3+CARD_W       ) && (y >= D_Y+CARD_H-BORDER ) && (y < D_Y+CARD_H        )) ||
       ((x >= D_X3              ) && (x < D_X3+BORDER       ) && (y >= D_Y               ) && (y < D_Y+CARD_H        )) ||
       ((x >= D_X3+CARD_W-BORDER) && (x < D_X3+CARD_W       ) && (y >= D_Y               ) && (y < D_Y+CARD_H        ));

    wire d4_brd =
       ((x >= D_X4              ) && (x < D_X4+CARD_W       ) && (y >= D_Y               ) && (y < D_Y+BORDER        )) ||
       ((x >= D_X4              ) && (x < D_X4+CARD_W       ) && (y >= D_Y+CARD_H-BORDER ) && (y < D_Y+CARD_H        )) ||
       ((x >= D_X4              ) && (x < D_X4+BORDER       ) && (y >= D_Y               ) && (y < D_Y+CARD_H        )) ||
       ((x >= D_X4+CARD_W-BORDER) && (x < D_X4+CARD_W       ) && (y >= D_Y               ) && (y < D_Y+CARD_H        ));

    // player borders
    wire p0_brd =
       ((x >= P_X0              ) && (x < P_X0+CARD_W       ) && (y >= P_Y               ) && (y < P_Y+BORDER        )) ||
       ((x >= P_X0              ) && (x < P_X0+CARD_W       ) && (y >= P_Y+CARD_H-BORDER ) && (y < P_Y+CARD_H        )) ||
       ((x >= P_X0              ) && (x < P_X0+BORDER       ) && (y >= P_Y               ) && (y < P_Y+CARD_H        )) ||
       ((x >= P_X0+CARD_W-BORDER) && (x < P_X0+CARD_W       ) && (y >= P_Y               ) && (y < P_Y+CARD_H        ));

    wire p1_brd =
       ((x >= P_X1              ) && (x < P_X1+CARD_W       ) && (y >= P_Y               ) && (y < P_Y+BORDER        )) ||
       ((x >= P_X1              ) && (x < P_X1+CARD_W       ) && (y >= P_Y+CARD_H-BORDER ) && (y < P_Y+CARD_H        )) ||
       ((x >= P_X1              ) && (x < P_X1+BORDER       ) && (y >= P_Y               ) && (y < P_Y+CARD_H        )) ||
       ((x >= P_X1+CARD_W-BORDER) && (x < P_X1+CARD_W       ) && (y >= P_Y               ) && (y < P_Y+CARD_H        ));

    wire p2_brd =
       ((x >= P_X2              ) && (x < P_X2+CARD_W       ) && (y >= P_Y               ) && (y < P_Y+BORDER        )) ||
       ((x >= P_X2              ) && (x < P_X2+CARD_W       ) && (y >= P_Y+CARD_H-BORDER ) && (y < P_Y+CARD_H        )) ||
       ((x >= P_X2              ) && (x < P_X2+BORDER       ) && (y >= P_Y               ) && (y < P_Y+CARD_H        )) ||
       ((x >= P_X2+CARD_W-BORDER) && (x < P_X2+CARD_W       ) && (y >= P_Y               ) && (y < P_Y+CARD_H        ));

    wire p3_brd =
       ((x >= P_X3              ) && (x < P_X3+CARD_W       ) && (y >= P_Y               ) && (y < P_Y+BORDER        )) ||
       ((x >= P_X3              ) && (x < P_X3+CARD_W       ) && (y >= P_Y+CARD_H-BORDER ) && (y < P_Y+CARD_H        )) ||
       ((x >= P_X3              ) && (x < P_X3+BORDER       ) && (y >= P_Y               ) && (y < P_Y+CARD_H        )) ||
       ((x >= P_X3+CARD_W-BORDER) && (x < P_X3+CARD_W       ) && (y >= P_Y               ) && (y < P_Y+CARD_H        ));

    wire p4_brd =
       ((x >= P_X4              ) && (x < P_X4+CARD_W       ) && (y >= P_Y               ) && (y < P_Y+BORDER        )) ||
       ((x >= P_X4              ) && (x < P_X4+CARD_W       ) && (y >= P_Y+CARD_H-BORDER ) && (y < P_Y+CARD_H        )) ||
       ((x >= P_X4              ) && (x < P_X4+BORDER       ) && (y >= P_Y               ) && (y < P_Y+CARD_H        )) ||
       ((x >= P_X4+CARD_W-BORDER) && (x < P_X4+CARD_W       ) && (y >= P_Y               ) && (y < P_Y+CARD_H        ));

    // -------------------------
    // Deck rectangles
    // -------------------------
    wire deck_back =
       (x >= DECK_X+DECK2_DX) && (x < DECK_X+DECK2_DX+DECK_W) &&
       (y >= DECK_Y+DECK2_DY) && (y < DECK_Y+DECK2_DY+DECK_H);

    wire deck_fill =
       (x >= DECK_X) && (x < DECK_X+DECK_W) &&
       (y >= DECK_Y) && (y < DECK_Y+DECK_H);

    wire deck_brd =
       ((x >= DECK_X                 ) && (x < DECK_X+DECK_W              ) && (y >= DECK_Y                    ) && (y < DECK_Y+DECK_BORDER        )) ||
       ((x >= DECK_X                 ) && (x < DECK_X+DECK_W              ) && (y >= DECK_Y+DECK_H-DECK_BORDER ) && (y < DECK_Y+DECK_H             )) ||
       ((x >= DECK_X                 ) && (x < DECK_X+DECK_BORDER         ) && (y >= DECK_Y                    ) && (y < DECK_Y+DECK_H             )) ||
       ((x >= DECK_X+DECK_W-DECK_BORDER) && (x < DECK_X+DECK_W           ) && (y >= DECK_Y                    ) && (y < DECK_Y+DECK_H             ));

    wire inside_deck =
       (x >= DECK_X+DECK_BORDER) && (x < DECK_X+DECK_W-DECK_BORDER) &&
       (y >= DECK_Y+DECK_BORDER) && (y < DECK_Y+DECK_H-DECK_BORDER);

    wire deck_checker = inside_deck && (x[3] ^ y[3]);  // 8x8 checker

    // -------------------------
    // "BLACKJACK" text in center
    // -------------------------
    localparam TXT_S   = 2;                         // scale
    localparam TXT_W   = 6*TXT_S;                   // char advance
    localparam TXT_X0  = 320 - (9*TXT_W)/2;         // 9 letters
    localparam TXT_Y0  = 230;

    // --- B ---
    wire signed [10:0] tB_lx = $signed({1'b0,x}) - $signed(TXT_X0 + 0*TXT_W);
    wire signed [10:0] tB_ly = $signed({1'b0,y}) - $signed(TXT_Y0);
    wire        tB_in  = (tB_lx >= 0) && (tB_lx < 5*TXT_S) &&
                         (tB_ly >= 0) && (tB_ly < 7*TXT_S);
    wire [2:0]  tB_col = tB_lx[10:0] / TXT_S;
    wire [2:0]  tB_row = tB_ly[10:0] / TXT_S;
    wire [6:0]  tB_bits =
        (tB_col==3'd0) ? 7'b1111111 :
        (tB_col==3'd1) ? 7'b1001001 :
        (tB_col==3'd2) ? 7'b1001001 :
        (tB_col==3'd3) ? 7'b1001001 :
        (tB_col==3'd4) ? 7'b0110110 :
                         7'b0000000;
    wire        tB = tB_in && tB_bits[6 - tB_row];

    // --- L ---
    wire signed [10:0] tL_lx = $signed({1'b0,x}) - $signed(TXT_X0 + 1*TXT_W);
    wire signed [10:0] tL_ly = $signed({1'b0,y}) - $signed(TXT_Y0);
    wire        tL_in  = (tL_lx >= 0) && (tL_lx < 5*TXT_S) &&
                         (tL_ly >= 0) && (tL_ly < 7*TXT_S);
    wire [2:0]  tL_col = tL_lx[10:0] / TXT_S;
    wire [2:0]  tL_row = tL_ly[10:0] / TXT_S;
    wire [6:0]  tL_bits =
        (tL_col==3'd0) ? 7'b1111111 :
        (tL_col==3'd1) ? 7'b1000000 :
        (tL_col==3'd2) ? 7'b1000000 :
        (tL_col==3'd3) ? 7'b1000000 :
        (tL_col==3'd4) ? 7'b1000000 :
                         7'b0000000;
    wire        tL = tL_in && tL_bits[6 - tL_row];

    // --- A ---
    wire signed [10:0] tA_lx = $signed({1'b0,x}) - $signed(TXT_X0 + 2*TXT_W);
    wire signed [10:0] tA_ly = $signed({1'b0,y}) - $signed(TXT_Y0);
    wire        tA_in  = (tA_lx >= 0) && (tA_lx < 5*TXT_S) &&
                         (tA_ly >= 0) && (tA_ly < 7*TXT_S);
    wire [2:0]  tA_col = tA_lx[10:0] / TXT_S;
    wire [2:0]  tA_row = tA_ly[10:0] / TXT_S;
    wire [6:0]  tA_bits =
        (tA_col==3'd0) ? 7'b0011111 :
        (tA_col==3'd1) ? 7'b0100100 :
        (tA_col==3'd2) ? 7'b0100100 :
        (tA_col==3'd3) ? 7'b0100100 :
        (tA_col==3'd4) ? 7'b0011111 :
                         7'b0000000;
    wire        tA = tA_in && tA_bits[6 - tA_row];

    // --- C ---
    wire signed [10:0] tC_lx = $signed({1'b0,x}) - $signed(TXT_X0 + 3*TXT_W);
    wire signed [10:0] tC_ly = $signed({1'b0,y}) - $signed(TXT_Y0);
    wire        tC_in  = (tC_lx >= 0) && (tC_lx < 5*TXT_S) &&
                         (tC_ly >= 0) && (tC_ly < 7*TXT_S);
    wire [2:0]  tC_col = tC_lx[10:0] / TXT_S;
    wire [2:0]  tC_row = tC_ly[10:0] / TXT_S;
    wire [6:0]  tC_bits =
        (tC_col==3'd0) ? 7'b0111110 :
        (tC_col==3'd1) ? 7'b1000001 :
        (tC_col==3'd2) ? 7'b1000001 :
        (tC_col==3'd3) ? 7'b1000001 :
        (tC_col==3'd4) ? 7'b0100010 :
                         7'b0000000;
    wire        tC = tC_in && tC_bits[6 - tC_row];

    // --- K ---
    wire signed [10:0] tK_lx = $signed({1'b0,x}) - $signed(TXT_X0 + 4*TXT_W);
    wire signed [10:0] tK_ly = $signed({1'b0,y}) - $signed(TXT_Y0);
    wire        tK_in  = (tK_lx >= 0) && (tK_lx < 5*TXT_S) &&
                         (tK_ly >= 0) && (tK_ly < 7*TXT_S);
    wire [2:0]  tK_col = tK_lx[10:0] / TXT_S;
    wire [2:0]  tK_row = tK_ly[10:0] / TXT_S;
    wire [6:0]  tK_bits =
        (tK_col==3'd0) ? 7'b1111111 :
        (tK_col==3'd1) ? 7'b0001000 :
        (tK_col==3'd2) ? 7'b0010100 :
        (tK_col==3'd3) ? 7'b0100010 :
        (tK_col==3'd4) ? 7'b1000001 :
                         7'b0000000;
    wire        tK = tK_in && tK_bits[6 - tK_row];

    // --- J ---
    wire signed [10:0] tJ_lx = $signed({1'b0,x}) - $signed(TXT_X0 + 5*TXT_W);
    wire signed [10:0] tJ_ly = $signed({1'b0,y}) - $signed(TXT_Y0);
    wire        tJ_in  = (tJ_lx >= 0) && (tJ_lx < 5*TXT_S) &&
                         (tJ_ly >= 0) && (tJ_ly < 7*TXT_S);
    wire [2:0]  tJ_col = tJ_lx[10:0] / TXT_S;
    wire [2:0]  tJ_row = tJ_ly[10:0] / TXT_S;
    wire [6:0]  tJ_bits =
        (tJ_col==3'd0) ? 7'b0000010 :
        (tJ_col==3'd1) ? 7'b0000001 :
        (tJ_col==3'd2) ? 7'b1000001 :
        (tJ_col==3'd3) ? 7'b1111110 :
        (tJ_col==3'd4) ? 7'b1000000 :
                         7'b0000000;
    wire        tJ = tJ_in && tJ_bits[6 - tJ_row];

    // --- A2 ---
    wire signed [10:0] tA2_lx = $signed({1'b0,x}) - $signed(TXT_X0 + 6*TXT_W);
    wire signed [10:0] tA2_ly = $signed({1'b0,y}) - $signed(TXT_Y0);
    wire        tA2_in  = (tA2_lx >= 0) && (tA2_lx < 5*TXT_S) &&
                          (tA2_ly >= 0) && (tA2_ly < 7*TXT_S);
    wire [2:0]  tA2_col = tA2_lx[10:0] / TXT_S;
    wire [2:0]  tA2_row = tA2_ly[10:0] / TXT_S;
    wire [6:0]  tA2_bits =
        (tA2_col==3'd0) ? 7'b0011111 :
        (tA2_col==3'd1) ? 7'b0100100 :
        (tA2_col==3'd2) ? 7'b0100100 :
        (tA2_col==3'd3) ? 7'b0100100 :
        (tA2_col==3'd4) ? 7'b0011111 :
                          7'b0000000;
    wire        tA2 = tA2_in && tA2_bits[6 - tA2_row];

    // --- C2 ---
    wire signed [10:0] tC2_lx = $signed({1'b0,x}) - $signed(TXT_X0 + 7*TXT_W);
    wire signed [10:0] tC2_ly = $signed({1'b0,y}) - $signed(TXT_Y0);
    wire        tC2_in  = (tC2_lx >= 0) && (tC2_lx < 5*TXT_S) &&
                          (tC2_ly >= 0) && (tC2_ly < 7*TXT_S);
    wire [2:0]  tC2_col = tC2_lx[10:0] / TXT_S;
    wire [2:0]  tC2_row = tC2_ly[10:0] / TXT_S;
    wire [6:0]  tC2_bits =
        (tC2_col==3'd0) ? 7'b0111110 :
        (tC2_col==3'd1) ? 7'b1000001 :
        (tC2_col==3'd2) ? 7'b1000001 :
        (tC2_col==3'd3) ? 7'b1000001 :
        (tC2_col==3'd4) ? 7'b0100010 :
                          7'b0000000;
    wire        tC2 = tC2_in && tC2_bits[6 - tC2_row];

    // --- K2 ---
    wire signed [10:0] tK2_lx = $signed({1'b0,x}) - $signed(TXT_X0 + 8*TXT_W);
    wire signed [10:0] tK2_ly = $signed({1'b0,y}) - $signed(TXT_Y0);
    wire        tK2_in  = (tK2_lx >= 0) && (tK2_lx < 5*TXT_S) &&
                          (tK2_ly >= 0) && (tK2_ly < 7*TXT_S);
    wire [2:0]  tK2_col = tK2_lx[10:0] / TXT_S;
    wire [2:0]  tK2_row = tK2_ly[10:0] / TXT_S;
    wire [6:0]  tK2_bits =
        (tK2_col==3'd0) ? 7'b1111111 :
        (tK2_col==3'd1) ? 7'b0001000 :
        (tK2_col==3'd2) ? 7'b0010100 :
        (tK2_col==3'd3) ? 7'b0100010 :
        (tK2_col==3'd4) ? 7'b1000001 :
                          7'b0000000;
    wire        tK2 = tK2_in && tK2_bits[6 - tK2_row];

    wire blackjack_text = tB | tL | tA | tC | tK | tJ | tA2 | tC2 | tK2;

    // -------------------------
    // Balance label "BALANCE: $1100" (left-middle)
    // -------------------------
    localparam BAL_S   = 2;
    localparam BAL_X0  = 40;
    localparam BAL_Y0  = 240;

    // (exactly as before – unchanged; keeping for completeness)
    // B
    wire signed [10:0] bB_lx = $signed({1'b0,x}) - $signed(BAL_X0 + 0*6*BAL_S);
    wire signed [10:0] bB_ly = $signed({1'b0,y}) - $signed(BAL_Y0);
    wire        bB_in  = (bB_lx >= 0) && (bB_lx < 5*BAL_S) &&
                         (bB_ly >= 0) && (bB_ly < 7*BAL_S);
    wire [2:0]  bB_col = bB_lx[10:0] / BAL_S;
    wire [2:0]  bB_row = bB_ly[10:0] / BAL_S;
    wire [6:0]  bB_bits =
        (bB_col==3'd0) ? 7'b1111111 :
        (bB_col==3'd1) ? 7'b1001001 :
        (bB_col==3'd2) ? 7'b1001001 :
        (bB_col==3'd3) ? 7'b1001001 :
        (bB_col==3'd4) ? 7'b0110110 :
                         7'b0000000;
    wire        b_B = bB_in && bB_bits[6 - bB_row];

    // A
    wire signed [10:0] bA_lx = $signed({1'b0,x}) - $signed(BAL_X0 + 1*6*BAL_S);
    wire signed [10:0] bA_ly = $signed({1'b0,y}) - $signed(BAL_Y0);
    wire        bA_in  = (bA_lx >= 0) && (bA_lx < 5*BAL_S) &&
                         (bA_ly >= 0) && (bA_ly < 7*BAL_S);
    wire [2:0]  bA_col = bA_lx[10:0] / BAL_S;
    wire [2:0]  bA_row = bA_ly[10:0] / BAL_S;
    wire [6:0]  bA_bits =
        (bA_col==3'd0) ? 7'b0011111 :
        (bA_col==3'd1) ? 7'b0100100 :
        (bA_col==3'd2) ? 7'b0100100 :
        (bA_col==3'd3) ? 7'b0100100 :
        (bA_col==3'd4) ? 7'b0011111 :
                         7'b0000000;
    wire        b_A = bA_in && bA_bits[6 - bA_row];

    // L
    wire signed [10:0] bL_lx = $signed({1'b0,x}) - $signed(BAL_X0 + 2*6*BAL_S);
    wire signed [10:0] bL_ly = $signed({1'b0,y}) - $signed(BAL_Y0);
    wire        bL_in  = (bL_lx >= 0) && (bL_lx < 5*BAL_S) &&
                         (bL_ly >= 0) && (bL_ly < 7*BAL_S);
    wire [2:0]  bL_col = bL_lx[10:0] / BAL_S;
    wire [2:0]  bL_row = bL_ly[10:0] / BAL_S;
    wire [6:0]  bL_bits =
        (bL_col==3'd0) ? 7'b1111111 :
        (bL_col==3'd1) ? 7'b1000000 :
        (bL_col==3'd2) ? 7'b1000000 :
        (bL_col==3'd3) ? 7'b1000000 :
        (bL_col==3'd4) ? 7'b1000000 :
                         7'b0000000;
    wire        b_L = bL_in && bL_bits[6 - bL_row];

    // second A (A2)
    wire signed [10:0] bA2_lx = $signed({1'b0,x}) - $signed(BAL_X0 + 3*6*BAL_S);
    wire signed [10:0] bA2_ly = $signed({1'b0,y}) - $signed(BAL_Y0);
    wire        bA2_in  = (bA2_lx >= 0) && (bA2_lx < 5*BAL_S) &&
                          (bA2_ly >= 0) && (bA2_ly < 7*BAL_S);
    wire [2:0]  bA2_col = bA2_lx[10:0] / BAL_S;
    wire [2:0]  bA2_row = bA2_ly[10:0] / BAL_S;
    wire [6:0]  bA2_bits =
        (bA2_col==3'd0) ? 7'b0011111 :
        (bA2_col==3'd1) ? 7'b0100100 :
        (bA2_col==3'd2) ? 7'b0100100 :
        (bA2_col==3'd3) ? 7'b0100100 :
        (bA2_col==3'd4) ? 7'b0011111 :
                          7'b0000000;
    wire        b_A2 = bA2_in && bA2_bits[6 - bA2_row];

    // N
    wire signed [10:0] bN_lx = $signed({1'b0,x}) - $signed(BAL_X0 + 4*6*BAL_S);
    wire signed [10:0] bN_ly = $signed({1'b0,y}) - $signed(BAL_Y0);
    wire        bN_in  = (bN_lx >= 0) && (bN_lx < 5*BAL_S) &&
                         (bN_ly >= 0) && (bN_ly < 7*BAL_S);
    wire [2:0]  bN_col = bN_lx[10:0] / BAL_S;
    wire [2:0]  bN_row = bN_ly[10:0] / BAL_S;
    wire [6:0]  bN_bits =
        (bN_col==3'd0) ? 7'b1111111 :
        (bN_col==3'd1) ? 7'b0110000 :
        (bN_col==3'd2) ? 7'b0001100 :
        (bN_col==3'd3) ? 7'b0000011 :
        (bN_col==3'd4) ? 7'b1111111 :
                         7'b0000000;
    wire        b_N = bN_in && bN_bits[6 - bN_row];

    // C
    wire signed [10:0] bC_lx = $signed({1'b0,x}) - $signed(BAL_X0 + 5*6*BAL_S);
    wire signed [10:0] bC_ly = $signed({1'b0,y}) - $signed(BAL_Y0);
    wire        bC_in  = (bC_lx >= 0) && (bC_lx < 5*BAL_S) &&
                         (bC_ly >= 0) && (bC_ly < 7*BAL_S);
    wire [2:0]  bC_col = bC_lx[10:0] / BAL_S;
    wire [2:0]  bC_row = bC_ly[10:0] / BAL_S;
    wire [6:0]  bC_bits =
        (bC_col==3'd0) ? 7'b0111110 :
        (bC_col==3'd1) ? 7'b1000001 :
        (bC_col==3'd2) ? 7'b1000001 :
        (bC_col==3'd3) ? 7'b1000001 :
        (bC_col==3'd4) ? 7'b0100010 :
                         7'b0000000;
    wire        b_C = bC_in && bC_bits[6 - bC_row];

    // E
    wire signed [10:0] bE_lx = $signed({1'b0,x}) - $signed(BAL_X0 + 6*6*BAL_S);
    wire signed [10:0] bE_ly = $signed({1'b0,y}) - $signed(BAL_Y0);
    wire        bE_in  = (bE_lx >= 0) && (bE_lx < 5*BAL_S) &&
                         (bE_ly >= 0) && (bE_ly < 7*BAL_S);
    wire [2:0]  bE_col = bE_lx[10:0] / BAL_S;
    wire [2:0]  bE_row = bE_ly[10:0] / BAL_S;
    wire [6:0]  bE_bits =
        (bE_col==3'd0) ? 7'b1111111 :
        (bE_col==3'd1) ? 7'b1001001 :
        (bE_col==3'd2) ? 7'b1001001 :
        (bE_col==3'd3) ? 7'b1001001 :
        (bE_col==3'd4) ? 7'b1001001 :
                         7'b0000000;
    wire        b_E = bE_in && bE_bits[6 - bE_row];

    // ':'  at BAL_X0 + 7*6*BAL_S
    wire signed [10:0] bColon_lx = $signed({1'b0,x}) - $signed(BAL_X0 + 7*6*BAL_S);
    wire signed [10:0] bColon_ly = $signed({1'b0,y}) - $signed(BAL_Y0);
    wire        bColon_in  = (bColon_lx >= 0) && (bColon_lx < 5*BAL_S) &&
                             (bColon_ly >= 0) && (bColon_ly < 7*BAL_S);
    wire [2:0]  bColon_col = bColon_lx[10:0] / BAL_S;
    wire [2:0]  bColon_row = bColon_ly[10:0] / BAL_S;
    wire [6:0]  bColon_bits =
        (bColon_col==3'd0) ? 7'b0000000 :
        (bColon_col==3'd1) ? 7'b0000000 :
        (bColon_col==3'd2) ? 7'b0010100 :
        (bColon_col==3'd3) ? 7'b0000000 :
        (bColon_col==3'd4) ? 7'b0000000 :
                             7'b0000000;
    wire        b_colon = bColon_in && bColon_bits[6 - bColon_row];

    // '$' at BAL_X0 + 9*6*BAL_S
    wire signed [10:0] bDol_lx = $signed({1'b0,x}) - $signed(BAL_X0 + 9*6*BAL_S);
    wire signed [10:0] bDol_ly = $signed({1'b0,y}) - $signed(BAL_Y0);
    wire        bDol_in  = (bDol_lx >= 0) && (bDol_lx < 5*BAL_S) &&
                           (bDol_ly >= 0) && (bDol_ly < 7*BAL_S);
    wire [2:0]  bDol_col = bDol_lx[10:0] / BAL_S;
    wire [2:0]  bDol_row = bDol_ly[10:0] / BAL_S;
    wire [6:0]  bDol_bits =
        (bDol_col==3'd0) ? 7'b0110010 :
        (bDol_col==3'd1) ? 7'b1001001 :
        (bDol_col==3'd2) ? 7'b1001001 :
        (bDol_col==3'd3) ? 7'b1001001 :
        (bDol_col==3'd4) ? 7'b0100110 :
                           7'b0000000;
    wire        b_dol = bDol_in && bDol_bits[6 - bDol_row];

    // Digits of "1100"
    // '1' at BAL_X0 + 10*6*BAL_S
    wire signed [10:0] bN0_lx = $signed({1'b0,x}) - $signed(BAL_X0 + 10*6*BAL_S);
    wire signed [10:0] bN0_ly = $signed({1'b0,y}) - $signed(BAL_Y0);
    wire        bN0_in  = (bN0_lx >= 0) && (bN0_lx < 5*BAL_S) &&
                          (bN0_ly >= 0) && (bN0_ly < 7*BAL_S);
    wire [2:0]  bN0_col = bN0_lx[10:0] / BAL_S;
    wire [2:0]  bN0_row = bN0_ly[10:0] / BAL_S;
    wire [6:0]  bN0_bits =
        (bN0_col==3'd0) ? 7'b0000000 :
        (bN0_col==3'd1) ? 7'b0100001 :
        (bN0_col==3'd2) ? 7'b1111111 :
        (bN0_col==3'd3) ? 7'b0000001 :
        (bN0_col==3'd4) ? 7'b0000000 :
                          7'b0000000;
    wire        b_n0 = bN0_in && bN0_bits[6 - bN0_row];

    // second '1' at BAL_X0 + 11*6*BAL_S
    wire signed [10:0] bN1_lx = $signed({1'b0,x}) - $signed(BAL_X0 + 11*6*BAL_S);
    wire signed [10:0] bN1_ly = $signed({1'b0,y}) - $signed(BAL_Y0);
    wire        bN1_in  = (bN1_lx >= 0) && (bN1_lx < 5*BAL_S) &&
                          (bN1_ly >= 0) && (bN1_ly < 7*BAL_S);
    wire [2:0]  bN1_col = bN1_lx[10:0] / BAL_S;
    wire [2:0]  bN1_row = bN1_ly[10:0] / BAL_S;
    wire [6:0]  bN1_bits =
        (bN1_col==3'd0) ? 7'b0000000 :
        (bN1_col==3'd1) ? 7'b0100001 :
        (bN1_col==3'd2) ? 7'b1111111 :
        (bN1_col==3'd3) ? 7'b0000001 :
        (bN1_col==3'd4) ? 7'b0000000 :
                          7'b0000000;
    wire        b_n1 = bN1_in && bN1_bits[6 - bN1_row];

    // '0' at BAL_X0 + 12*6*BAL_S
    wire signed [10:0] bN2_lx = $signed({1'b0,x}) - $signed(BAL_X0 + 12*6*BAL_S);
    wire signed [10:0] bN2_ly = $signed({1'b0,y}) - $signed(BAL_Y0);
    wire        bN2_in  = (bN2_lx >= 0) && (bN2_lx < 5*BAL_S) &&
                          (bN2_ly >= 0) && (bN2_ly < 7*BAL_S);
    wire [2:0]  bN2_col = bN2_lx[10:0] / BAL_S;
    wire [2:0]  bN2_row = bN2_ly[10:0] / BAL_S;
    wire [6:0]  bN2_bits =
        (bN2_col==3'd0) ? 7'b0111110 :
        (bN2_col==3'd1) ? 7'b1000001 :
        (bN2_col==3'd2) ? 7'b1000001 :
        (bN2_col==3'd3) ? 7'b1000001 :
        (bN2_col==3'd4) ? 7'b0111110 :
                          7'b0000000;
    wire        b_n2 = bN2_in && bN2_bits[6 - bN2_row];

    // second '0' at BAL_X0 + 13*6*BAL_S
    wire signed [10:0] bN3_lx = $signed({1'b0,x}) - $signed(BAL_X0 + 13*6*BAL_S);
    wire signed [10:0] bN3_ly = $signed({1'b0,y}) - $signed(BAL_Y0);
    wire        bN3_in  = (bN3_lx >= 0) && (bN3_lx < 5*BAL_S) &&
                          (bN3_ly >= 0) && (bN3_ly < 7*BAL_S);
    wire [2:0]  bN3_col = bN3_lx[10:0] / BAL_S;
    wire [2:0]  bN3_row = bN3_ly[10:0] / BAL_S;
    wire [6:0]  bN3_bits =
        (bN3_col==3'd0) ? 7'b0111110 :
        (bN3_col==3'd1) ? 7'b1000001 :
        (bN3_col==3'd2) ? 7'b1000001 :
        (bN3_col==3'd3) ? 7'b1000001 :
        (bN3_col==3'd4) ? 7'b0111110 :
                          7'b0000000;
    wire        b_n3 = bN3_in && bN3_bits[6 - bN3_row];

    wire balance_text = b_B | b_A | b_L | b_A2 | b_N | b_C | b_E |
                        b_colon | b_dol | b_n0 | b_n1 | b_n2 | b_n3;

    // -------------------------
    // Digits inside each card: top-left
    // -------------------------
    localparam DIG_S      = 2;
    localparam [9:0] INSET_X_TL = 12, INSET_Y_TL = 10;

    // Bottom-right inset (same orientation, inside the card)
    localparam [9:0] INSET_X_BR = 12;
    localparam [9:0] INSET_Y_BR = 10;

    // Dealer card 1 - top-left
    wire signed [10:0] d0_lx = $signed({1'b0,x}) - $signed(D_X0 + INSET_X_TL);
    wire signed [10:0] d0_ly = $signed({1'b0,y}) - $signed(D_Y   + INSET_Y_TL);
    wire        d0_in   = (d0_lx >= 0) && (d0_lx < 5*DIG_S) &&
                          (d0_ly >= 0) && (d0_ly < 7*DIG_S);
    wire [2:0]  d0_col  = d0_lx[10:0] / DIG_S;
    wire [2:0]  d0_row  = d0_ly[10:0] / DIG_S;
    wire        d0_pix;
    digit5x7_pixel d0_digit_gen (
        .val(dealer_card1),
        .col(d0_col),
        .row(d0_row),
        .on (d0_pix)
    );
    wire d0_digit = d0_in && d0_pix;

    // Dealer card 1 - bottom-right
    wire signed [10:0] d0b_lx = $signed({1'b0,x}) -
                                $signed(D_X0 + CARD_W - INSET_X_BR - 5*DIG_S);
    wire signed [10:0] d0b_ly = $signed({1'b0,y}) -
                                $signed(D_Y  + CARD_H - INSET_Y_BR - 7*DIG_S);
    wire        d0b_in   = (d0b_lx >= 0) && (d0b_lx < 5*DIG_S) &&
                           (d0b_ly >= 0) && (d0b_ly < 7*DIG_S);
    wire [2:0]  d0b_col  = d0b_lx[10:0] / DIG_S;
    wire [2:0]  d0b_row  = d0b_ly[10:0] / DIG_S;
    wire        d0b_pix;
    digit5x7_pixel d0b_digit_gen (
        .val(dealer_card1),
        .col(d0b_col),
        .row(d0b_row),
        .on (d0b_pix)
    );
    wire d0b_digit = d0b_in && d0b_pix;

    // Dealer card 2 - top-left
    wire signed [10:0] d1_lx = $signed({1'b0,x}) - $signed(D_X1 + INSET_X_TL);
    wire signed [10:0] d1_ly = $signed({1'b0,y}) - $signed(D_Y   + INSET_Y_TL);
    wire        d1_in   = (d1_lx >= 0) && (d1_lx < 5*DIG_S) &&
                          (d1_ly >= 0) && (d1_ly < 7*DIG_S);
    wire [2:0]  d1_col  = d1_lx[10:0] / DIG_S;
    wire [2:0]  d1_row  = d1_ly[10:0] / DIG_S;
    wire        d1_pix;
    digit5x7_pixel d1_digit_gen (
        .val(dealer_card2),
        .col(d1_col),
        .row(d1_row),
        .on (d1_pix)
    );
    wire d1_digit = d1_in && d1_pix;

    // Dealer card 2 - bottom-right
    wire signed [10:0] d1b_lx = $signed({1'b0,x}) -
                                $signed(D_X1 + CARD_W - INSET_X_BR - 5*DIG_S);
    wire signed [10:0] d1b_ly = $signed({1'b0,y}) -
                                $signed(D_Y  + CARD_H - INSET_Y_BR - 7*DIG_S);
    wire        d1b_in   = (d1b_lx >= 0) && (d1b_lx < 5*DIG_S) &&
                           (d1b_ly >= 0) && (d1b_ly < 7*DIG_S);
    wire [2:0]  d1b_col  = d1b_lx[10:0] / DIG_S;
    wire [2:0]  d1b_row  = d1b_ly[10:0] / DIG_S;
    wire        d1b_pix;
    digit5x7_pixel d1b_digit_gen (
        .val(dealer_card2),
        .col(d1b_col),
        .row(d1b_row),
        .on (d1b_pix)
    );
    wire d1b_digit = d1b_in && d1b_pix;

    // Dealer card 3 - TL + BR
    wire signed [10:0] d2_lx = $signed({1'b0,x}) - $signed(D_X2 + INSET_X_TL);
    wire signed [10:0] d2_ly = $signed({1'b0,y}) - $signed(D_Y   + INSET_Y_TL);
    wire        d2_in   = (d2_lx >= 0) && (d2_lx < 5*DIG_S) &&
                          (d2_ly >= 0) && (d2_ly < 7*DIG_S);
    wire [2:0]  d2_col  = d2_lx[10:0] / DIG_S;
    wire [2:0]  d2_row  = d2_ly[10:0] / DIG_S;
    wire        d2_pix;
    digit5x7_pixel d2_digit_gen (
        .val(dealer_card3),
        .col(d2_col),
        .row(d2_row),
        .on (d2_pix)
    );
    wire d2_digit = d2_in && d2_pix;

    wire signed [10:0] d2b_lx = $signed({1'b0,x}) -
                                $signed(D_X2 + CARD_W - INSET_X_BR - 5*DIG_S);
    wire signed [10:0] d2b_ly = $signed({1'b0,y}) -
                                $signed(D_Y  + CARD_H - INSET_Y_BR - 7*DIG_S);
    wire        d2b_in   = (d2b_lx >= 0) && (d2b_lx < 5*DIG_S) &&
                           (d2b_ly >= 0) && (d2b_ly < 7*DIG_S);
    wire [2:0]  d2b_col  = d2b_lx[10:0] / DIG_S;
    wire [2:0]  d2b_row  = d2b_ly[10:0] / DIG_S;
    wire        d2b_pix;
    digit5x7_pixel d2b_digit_gen (
        .val(dealer_card3),
        .col(d2b_col),
        .row(d2b_row),
        .on (d2b_pix)
    );
    wire d2b_digit = d2b_in && d2b_pix;

    // Dealer card 4
    wire signed [10:0] d3_lx = $signed({1'b0,x}) - $signed(D_X3 + INSET_X_TL);
    wire signed [10:0] d3_ly = $signed({1'b0,y}) - $signed(D_Y   + INSET_Y_TL);
    wire        d3_in   = (d3_lx >= 0) && (d3_lx < 5*DIG_S) &&
                          (d3_ly >= 0) && (d3_ly < 7*DIG_S);
    wire [2:0]  d3_col  = d3_lx[10:0] / DIG_S;
    wire [2:0]  d3_row  = d3_ly[10:0] / DIG_S;
    wire        d3_pix;
    digit5x7_pixel d3_digit_gen (
        .val(dealer_card4),
        .col(d3_col),
        .row(d3_row),
        .on (d3_pix)
    );
    wire d3_digit = d3_in && d3_pix;

    wire signed [10:0] d3b_lx = $signed({1'b0,x}) -
                                $signed(D_X3 + CARD_W - INSET_X_BR - 5*DIG_S);
    wire signed [10:0] d3b_ly = $signed({1'b0,y}) -
                                $signed(D_Y  + CARD_H - INSET_Y_BR - 7*DIG_S);
    wire        d3b_in   = (d3b_lx >= 0) && (d3b_lx < 5*DIG_S) &&
                           (d3b_ly >= 0) && (d3b_ly < 7*DIG_S);
    wire [2:0]  d3b_col  = d3b_lx[10:0] / DIG_S;
    wire [2:0]  d3b_row  = d3b_ly[10:0] / DIG_S;
    wire        d3b_pix;
    digit5x7_pixel d3b_digit_gen (
        .val(dealer_card4),
        .col(d3b_col),
        .row(d3b_row),
        .on (d3b_pix)
    );
    wire d3b_digit = d3b_in && d3b_pix;

    // Dealer card 5
    wire signed [10:0] d4_lx = $signed({1'b0,x}) - $signed(D_X4 + INSET_X_TL);
    wire signed [10:0] d4_ly = $signed({1'b0,y}) - $signed(D_Y   + INSET_Y_TL);
    wire        d4_in   = (d4_lx >= 0) && (d4_lx < 5*DIG_S) &&
                          (d4_ly >= 0) && (d4_ly < 7*DIG_S);
    wire [2:0]  d4_col  = d4_lx[10:0] / DIG_S;
    wire [2:0]  d4_row  = d4_ly[10:0] / DIG_S;
    wire        d4_pix;
    digit5x7_pixel d4_digit_gen (
        .val(dealer_card5),
        .col(d4_col),
        .row(d4_row),
        .on (d4_pix)
    );
    wire d4_digit = d4_in && d4_pix;

    wire signed [10:0] d4b_lx = $signed({1'b0,x}) -
                                $signed(D_X4 + CARD_W - INSET_X_BR - 5*DIG_S);
    wire signed [10:0] d4b_ly = $signed({1'b0,y}) -
                                $signed(D_Y  + CARD_H - INSET_Y_BR - 7*DIG_S);
    wire        d4b_in   = (d4b_lx >= 0) && (d4b_lx < 5*DIG_S) &&
                           (d4b_ly >= 0) && (d4b_ly < 7*DIG_S);
    wire [2:0]  d4b_col  = d4b_lx[10:0] / DIG_S;
    wire [2:0]  d4b_row  = d4b_ly[10:0] / DIG_S;
    wire        d4b_pix;
    digit5x7_pixel d4b_digit_gen (
        .val(dealer_card5),
        .col(d4b_col),
        .row(d4b_row),
        .on (d4b_pix)
    );
    wire d4b_digit = d4b_in && d4b_pix;

    // Player card 1
    wire signed [10:0] p0_lx = $signed({1'b0,x}) - $signed(P_X0 + INSET_X_TL);
    wire signed [10:0] p0_ly = $signed({1'b0,y}) - $signed(P_Y   + INSET_Y_TL);
    wire        p0_in   = (p0_lx >= 0) && (p0_lx < 5*DIG_S) &&
                          (p0_ly >= 0) && (p0_ly < 7*DIG_S);
    wire [2:0]  p0_col  = p0_lx[10:0] / DIG_S;
    wire [2:0]  p0_row  = p0_ly[10:0] / DIG_S;
    wire        p0_pix;
    digit5x7_pixel p0_digit_gen (
        .val(player_card1),
        .col(p0_col),
        .row(p0_row),
        .on (p0_pix)
    );
    wire p0_digit = p0_in && p0_pix;

    wire signed [10:0] p0b_lx = $signed({1'b0,x}) -
                                $signed(P_X0 + CARD_W - INSET_X_BR - 5*DIG_S);
    wire signed [10:0] p0b_ly = $signed({1'b0,y}) -
                                $signed(P_Y  + CARD_H - INSET_Y_BR - 7*DIG_S);
    wire        p0b_in   = (p0b_lx >= 0) && (p0b_lx < 5*DIG_S) &&
                           (p0b_ly >= 0) && (p0b_ly < 7*DIG_S);
    wire [2:0]  p0b_col  = p0b_lx[10:0] / DIG_S;
    wire [2:0]  p0b_row  = p0b_ly[10:0] / DIG_S;
    wire        p0b_pix;
    digit5x7_pixel p0b_digit_gen (
        .val(player_card1),
        .col(p0b_col),
        .row(p0b_row),
        .on (p0b_pix)
    );
    wire p0b_digit = p0b_in && p0b_pix;

    // Player card 2
    wire signed [10:0] p1_lx = $signed({1'b0,x}) - $signed(P_X1 + INSET_X_TL);
    wire signed [10:0] p1_ly = $signed({1'b0,y}) - $signed(P_Y   + INSET_Y_TL);
    wire        p1_in   = (p1_lx >= 0) && (p1_lx < 5*DIG_S) &&
                          (p1_ly >= 0) && (p1_ly < 7*DIG_S);
    wire [2:0]  p1_col  = p1_lx[10:0] / DIG_S;
    wire [2:0]  p1_row  = p1_ly[10:0] / DIG_S;
    wire        p1_pix;
    digit5x7_pixel p1_digit_gen (
        .val(player_card2),
        .col(p1_col),
        .row(p1_row),
        .on (p1_pix)
    );
    wire p1_digit = p1_in && p1_pix;

    wire signed [10:0] p1b_lx = $signed({1'b0,x}) -
                                $signed(P_X1 + CARD_W - INSET_X_BR - 5*DIG_S);
    wire signed [10:0] p1b_ly = $signed({1'b0,y}) -
                                $signed(P_Y  + CARD_H - INSET_Y_BR - 7*DIG_S);
    wire        p1b_in   = (p1b_lx >= 0) && (p1b_lx < 5*DIG_S) &&
                           (p1b_ly >= 0) && (p1b_ly < 7*DIG_S);
    wire [2:0]  p1b_col  = p1b_lx[10:0] / DIG_S;
    wire [2:0]  p1b_row  = p1b_ly[10:0] / DIG_S;
    wire        p1b_pix;
    digit5x7_pixel p1b_digit_gen (
        .val(player_card2),
        .col(p1b_col),
        .row(p1b_row),
        .on (p1b_pix)
    );
    wire p1b_digit = p1b_in && p1b_pix;

    // Player card 3
    wire signed [10:0] p2_lx = $signed({1'b0,x}) - $signed(P_X2 + INSET_X_TL);
    wire signed [10:0] p2_ly = $signed({1'b0,y}) - $signed(P_Y   + INSET_Y_TL);
    wire        p2_in   = (p2_lx >= 0) && (p2_lx < 5*DIG_S) &&
                          (p2_ly >= 0) && (p2_ly < 7*DIG_S);
    wire [2:0]  p2_col  = p2_lx[10:0] / DIG_S;
    wire [2:0]  p2_row  = p2_ly[10:0] / DIG_S;
    wire        p2_pix;
    digit5x7_pixel p2_digit_gen (
        .val(player_card3),
        .col(p2_col),
        .row(p2_row),
        .on (p2_pix)
    );
    wire p2_digit = p2_in && p2_pix;

    wire signed [10:0] p2b_lx = $signed({1'b0,x}) -
                                $signed(P_X2 + CARD_W - INSET_X_BR - 5*DIG_S);
    wire signed [10:0] p2b_ly = $signed({1'b0,y}) -
                                $signed(P_Y  + CARD_H - INSET_Y_BR - 7*DIG_S);
    wire        p2b_in   = (p2b_lx >= 0) && (p2b_lx < 5*DIG_S) &&
                           (p2b_ly >= 0) && (p2b_ly < 7*DIG_S);
    wire [2:0]  p2b_col  = p2b_lx[10:0] / DIG_S;
    wire [2:0]  p2b_row  = p2b_ly[10:0] / DIG_S;
    wire        p2b_pix;
    digit5x7_pixel p2b_digit_gen (
        .val(player_card3),
        .col(p2b_col),
        .row(p2b_row),
        .on (p2b_pix)
    );
    wire p2b_digit = p2b_in && p2b_pix;

    // Player card 4
    wire signed [10:0] p3_lx = $signed({1'b0,x}) - $signed(P_X3 + INSET_X_TL);
    wire signed [10:0] p3_ly = $signed({1'b0,y}) - $signed(P_Y   + INSET_Y_TL);
    wire        p3_in   = (p3_lx >= 0) && (p3_lx < 5*DIG_S) &&
                          (p3_ly >= 0) && (p3_ly < 7*DIG_S);
    wire [2:0]  p3_col  = p3_lx[10:0] / DIG_S;
    wire [2:0]  p3_row  = p3_ly[10:0] / DIG_S;
    wire        p3_pix;
    digit5x7_pixel p3_digit_gen (
        .val(player_card4),
        .col(p3_col),
        .row(p3_row),
        .on (p3_pix)
    );
    wire p3_digit = p3_in && p3_pix;

    wire signed [10:0] p3b_lx = $signed({1'b0,x}) -
                                $signed(P_X3 + CARD_W - INSET_X_BR - 5*DIG_S);
    wire signed [10:0] p3b_ly = $signed({1'b0,y}) -
                                $signed(P_Y  + CARD_H - INSET_Y_BR - 7*DIG_S);
    wire        p3b_in   = (p3b_lx >= 0) && (p3b_lx < 5*DIG_S) &&
                           (p3b_ly >= 0) && (p3b_ly < 7*DIG_S);
    wire [2:0]  p3b_col  = p3b_lx[10:0] / DIG_S;
    wire [2:0]  p3b_row  = p3b_ly[10:0] / DIG_S;
    wire        p3b_pix;
    digit5x7_pixel p3b_digit_gen (
        .val(player_card4),
        .col(p3b_col),
        .row(p3b_row),
        .on (p3b_pix)
    );
    wire p3b_digit = p3b_in && p3b_pix;

    // Player card 5
    wire signed [10:0] p4_lx = $signed({1'b0,x}) - $signed(P_X4 + INSET_X_TL);
    wire signed [10:0] p4_ly = $signed({1'b0,y}) - $signed(P_Y   + INSET_Y_TL);
    wire        p4_in   = (p4_lx >= 0) && (p4_lx < 5*DIG_S) &&
                          (p4_ly >= 0) && (p4_ly < 7*DIG_S);
    wire [2:0]  p4_col  = p4_lx[10:0] / DIG_S;
    wire [2:0]  p4_row  = p4_ly[10:0] / DIG_S;
    wire        p4_pix;
    digit5x7_pixel p4_digit_gen (
        .val(player_card5),
        .col(p4_col),
        .row(p4_row),
        .on (p4_pix)
    );
    wire p4_digit = p4_in && p4_pix;

    wire signed [10:0] p4b_lx = $signed({1'b0,x}) -
                                $signed(P_X4 + CARD_W - INSET_X_BR - 5*DIG_S);
    wire signed [10:0] p4b_ly = $signed({1'b0,y}) -
                                $signed(P_Y  + CARD_H - INSET_Y_BR - 7*DIG_S);
    wire        p4b_in   = (p4b_lx >= 0) && (p4b_lx < 5*DIG_S) &&
                           (p4b_ly >= 0) && (p4b_ly < 7*DIG_S);
    wire [2:0]  p4b_col  = p4b_lx[10:0] / DIG_S;
    wire [2:0]  p4b_row  = p4b_ly[10:0] / DIG_S;
    wire        p4b_pix;
    digit5x7_pixel p4b_digit_gen (
        .val(player_card5),
        .col(p4b_col),
        .row(p4b_row),
        .on (p4b_pix)
    );
    wire p4b_digit = p4b_in && p4b_pix;

    // -------------------------
    // Diamond in card center
    // -------------------------
    // helper function: rotated diamond shaped hit
    function diamond_hit;
        input [9:0] px;
        input [9:0] py;
        input [9:0] cx;
        input [9:0] cy;
        integer dx, dy, ax, ay;
        begin
            dx = 8;   // half-width
            dy = 11;  // half-height
            ax = (px >= cx) ? (px - cx) : (cx - px);
            ay = (py >= cy) ? (py - cy) : (cy - py);
            // diamond |x|/dx + |y|/dy <= 1  -> avoid division:
            diamond_hit = (ax*dy + ay*dx <= dx*dy);
        end
    endfunction

    localparam D0_CX = D_X0 + CARD_W/2;
    localparam D1_CX = D_X1 + CARD_W/2;
    localparam D2_CX = D_X2 + CARD_W/2;
    localparam D3_CX = D_X3 + CARD_W/2;
    localparam D4_CX = D_X4 + CARD_W/2;
    localparam P0_CX = P_X0 + CARD_W/2;
    localparam P1_CX = P_X1 + CARD_W/2;
    localparam P2_CX = P_X2 + CARD_W/2;
    localparam P3_CX = P_X3 + CARD_W/2;
    localparam P4_CX = P_X4 + CARD_W/2;

    localparam D_CY = D_Y + CARD_H/2;
    localparam P_CY = P_Y + CARD_H/2;

    wire d0_diamond = diamond_hit(x, y, D0_CX[9:0], D_CY[9:0]) && d0_has;
    wire d1_diamond = diamond_hit(x, y, D1_CX[9:0], D_CY[9:0]) && d1_has;
    wire d2_diamond = diamond_hit(x, y, D2_CX[9:0], D_CY[9:0]) && d2_has;
    wire d3_diamond = diamond_hit(x, y, D3_CX[9:0], D_CY[9:0]) && d3_has;
    wire d4_diamond = diamond_hit(x, y, D4_CX[9:0], D_CY[9:0]) && d4_has;

    wire p0_diamond = diamond_hit(x, y, P0_CX[9:0], P_CY[9:0]) && p0_has;
    wire p1_diamond = diamond_hit(x, y, P1_CX[9:0], P_CY[9:0]) && p1_has;
    wire p2_diamond = diamond_hit(x, y, P2_CX[9:0], P_CY[9:0]) && p2_has;
    wire p3_diamond = diamond_hit(x, y, P3_CX[9:0], P_CY[9:0]) && p3_has;
    wire p4_diamond = diamond_hit(x, y, P4_CX[9:0], P_CY[9:0]) && p4_has;

    // -------------------------
    // Painter's algorithm
    // -------------------------
    reg [1:0] R,G,B;
    always @* begin
        // background felt
        R = C0; G = G_DARK; B = C0;

        // deck back layer (shadow)
        if (deck_back) begin R = C1; G = C1; B = C1; end

        // deck white fill
        if (deck_fill) begin R = C2; G = C2; B = C2; end

        // deck checker pattern (red)
        if (deck_checker) begin R = 2'b11; G = 2'b00; B = 2'b00; end

        // deck border
        if (deck_brd) begin R = C0; G = C0; B = C0; end

        // cards fill (only if card "exists")
        if ((d0_fill && d0_has) || (d1_fill && d1_has) ||
            (d2_fill && d2_has) || (d3_fill && d3_has) ||
            (d4_fill && d4_has) ||
            (p0_fill && p0_has) || (p1_fill && p1_has) ||
            (p2_fill && p2_has) || (p3_fill && p3_has) ||
            (p4_fill && p4_has)) begin
            R = C2; G = C2; B = C2;
        end

        // cards border
        if ((d0_brd && d0_has) || (d1_brd && d1_has) ||
            (d2_brd && d2_has) || (d3_brd && d3_has) ||
            (d4_brd && d4_has) ||
            (p0_brd && p0_has) || (p1_brd && p1_has) ||
            (p2_brd && p2_has) || (p3_brd && p3_has) ||
            (p4_brd && p4_has)) begin
            R = C0; G = C0; B = C0;
        end

        // diamond symbol (red) – on top of card fill, under digits
        if (d0_diamond || d1_diamond || d2_diamond || d3_diamond || d4_diamond ||
            p0_diamond || p1_diamond || p2_diamond || p3_diamond || p4_diamond) begin
            R = 2'b11; G = 2'b00; B = 2'b00;
        end

        // digits on cards (black) – both corners
        if (d0_digit  || d1_digit  || d2_digit  || d3_digit  || d4_digit  ||
            p0_digit  || p1_digit  || p2_digit  || p3_digit  || p4_digit  ||
            d0b_digit || d1b_digit || d2b_digit || d3b_digit || d4b_digit ||
            p0b_digit || p1b_digit || p2b_digit || p3b_digit || p4b_digit) begin
            R = C0; G = C0; B = C0;
        end

        // center "BLACKJACK" (light gray)
        if (blackjack_text) begin R = C1; G = C1; B = C1; end

        // balance label (bright red)
        if (balance_text) begin R = 2'b11; G = 2'b00; B = 2'b00; end

        // outside active area
        if (!active) begin R = C0; G = C0; B = C0; end
    end

    // Register to pixel clock
    always @(posedge clk_25MHz or negedge rst_n) begin
        if (!rst_n) begin
            vga_r <= 2'b00; vga_g <= 2'b00; vga_b <= 2'b00;
        end else begin
            vga_r <= R; vga_g <= G; vga_b <= B;
        end
    end

endmodule


// ============================================================================
// digit5x7_pixel
// 5x7 bitmap digit / letter.
// val = 0 or invalid -> no pixel.
// 1 is drawn as 'A' (for Ace).
// col: 0..4, row: 0..6.
// ============================================================================
module digit5x7_pixel (
    input  wire [3:0] val,
    input  wire [2:0] col,
    input  wire [2:0] row,
    output reg        on
);
    // each row is 5 bits: [4] = rightmost, [0] = leftmost
    reg [4:0] r0, r1, r2, r3, r4, r5, r6;

    always @* begin
        // default: blank
        r0 = 5'b00000;
        r1 = 5'b00000;
        r2 = 5'b00000;
        r3 = 5'b00000;
        r4 = 5'b00000;
        r5 = 5'b00000;
        r6 = 5'b00000;

        case (val)
            // 1 -> 'A'
            4'd1: begin
                r0 = 5'b00100;
                r1 = 5'b01010;
                r2 = 5'b10001;
                r3 = 5'b11111;
                r4 = 5'b10001;
                r5 = 5'b10001;
                r6 = 5'b00000;
            end

            // 2
            4'd2: begin
                r0 = 5'b01110;
                r1 = 5'b10001;
                r2 = 5'b00001;
                r3 = 5'b00110;
                r4 = 5'b01000;
                r5 = 5'b11111;
                r6 = 5'b00000;
            end

            // 3
            4'd3: begin
                r0 = 5'b01110;
                r1 = 5'b10001;
                r2 = 5'b00001;
                r3 = 5'b00110;
                r4 = 5'b00001;
                r5 = 5'b10001;
                r6 = 5'b01110;
            end

            // 4
            4'd4: begin
                r0 = 5'b00010;
                r1 = 5'b00110;
                r2 = 5'b01010;
                r3 = 5'b10010;
                r4 = 5'b11111;
                r5 = 5'b00010;
                r6 = 5'b00010;
            end

            // 5
            4'd5: begin
                r0 = 5'b11111;
                r1 = 5'b10000;
                r2 = 5'b11110;
                r3 = 5'b00001;
                r4 = 5'b00001;
                r5 = 5'b10001;
                r6 = 5'b01110;
            end

            // 6
            4'd6: begin
                r0 = 5'b01110;
                r1 = 5'b10000;
                r2 = 5'b11110;
                r3 = 5'b10001;
                r4 = 5'b10001;
                r5 = 5'b10001;
                r6 = 5'b01110;
            end

            // 7
            4'd7: begin
                r0 = 5'b11111;
                r1 = 5'b00001;
                r2 = 5'b00010;
                r3 = 5'b00100;
                r4 = 5'b01000;
                r5 = 5'b01000;
                r6 = 5'b01000;
            end

            // 8
            4'd8: begin
                r0 = 5'b01110;
                r1 = 5'b10001;
                r2 = 5'b10001;
                r3 = 5'b01110;
                r4 = 5'b10001;
                r5 = 5'b10001;
                r6 = 5'b01110;
            end

            // 9
            4'd9: begin
                r0 = 5'b01110;
                r1 = 5'b10001;
                r2 = 5'b10001;
                r3 = 5'b01111;
                r4 = 5'b00001;
                r5 = 5'b00001;
                r6 = 5'b01110;
            end

            default: begin
                r0 = 5'b00000;
                r1 = 5'b00000;
                r2 = 5'b00000;
                r3 = 5'b00000;
                r4 = 5'b00000;
                r5 = 5'b00000;
                r6 = 5'b00000;
            end
        endcase

        // select pixel
        on = 1'b0;
        case (row)
            3'd0: on = r0[4 - col];
            3'd1: on = r1[4 - col];
            3'd2: on = r2[4 - col];
            3'd3: on = r3[4 - col];
            3'd4: on = r4[4 - col];
            3'd5: on = r5[4 - col];
            3'd6: on = r6[4 - col];
            default: on = 1'b0;
        endcase
    end

endmodule
