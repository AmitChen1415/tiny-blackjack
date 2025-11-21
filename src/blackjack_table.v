// ============================================================================
// blackjack_table.v  (640x480 @ 25 MHz)
// Felt background, dealer+player cards with green gap, "BLACKJACK" in center,
// "Balance: $1100" at left-middle (red), and a face-down deck on right-middle.
// Digits inside cards move with the card position.
// (Buttons were removed to free space for future cards.)
// NO FUNCTIONS VERSION – only assigns + always blocks.
// ============================================================================

module blackjack_table (
    input  wire clk_25MHz,
    input  wire rst_n,
    output wire vga_hsync,
    output wire vga_vsync,
    output reg  [1:0] vga_r,
    output reg  [1:0] vga_g,
    output reg  [1:0] vga_b
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
    // Layout (cards with visible GAP)
    // -------------------------
    localparam CARD_W   = 70;
    localparam CARD_H   = 100;
    localparam CARD_GAP = 8;       // visible green strip between cards
    localparam BORDER   = 2;

    // Dealer (top center)
    localparam D_Y  = 60;
    localparam D_X0 = 320 - CARD_W - (CARD_GAP/2);
    localparam D_X1 = D_X0 + CARD_W + CARD_GAP;

    // Player (bottom center)
    localparam P_Y  = 300;
    localparam P_X0 = 320 - CARD_W - (CARD_GAP/2);
    localparam P_X1 = P_X0 + CARD_W + CARD_GAP;

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
    localparam [1:0] C1      = 2'b01; // gray (for center text)
    localparam [1:0] C2      = 2'b11; // white
    localparam [1:0] G_DARK  = 2'b10; // felt

    // -------------------------
    // Primitive areas by assigns (rect / rect_border inlined)
    // -------------------------

    // Card fills
    wire d0_fill = (x >= D_X0) && (x < D_X0+CARD_W) &&
                   (y >= D_Y  ) && (y < D_Y+CARD_H);
    wire d1_fill = (x >= D_X1) && (x < D_X1+CARD_W) &&
                   (y >= D_Y  ) && (y < D_Y+CARD_H);
    wire p0_fill = (x >= P_X0) && (x < P_X0+CARD_W) &&
                   (y >= P_Y  ) && (y < P_Y+CARD_H);
    wire p1_fill = (x >= P_X1) && (x < P_X1+CARD_W) &&
                   (y >= P_Y  ) && (y < P_Y+CARD_H);

    // Card borders
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

    // Deck rectangles
    wire deck_back =
       (x >= DECK_X+DECK2_DX) && (x < DECK_X+DECK2_DX+DECK_W) &&
       (y >= DECK_Y+DECK2_DY) && (y < DECK_Y+DECK2_DY+DECK_H);

    wire deck_fill =
       (x >= DECK_X) && (x < DECK_X+DECK_W) &&
       (y >= DECK_Y) && (y < DECK_Y+DECK_H);

    wire deck_brd =
       ((x >= DECK_X                 ) && (x < DECK_X+DECK_W           ) && (y >= DECK_Y                  ) && (y < DECK_Y+DECK_BORDER        )) ||
       ((x >= DECK_X                 ) && (x < DECK_X+DECK_W           ) && (y >= DECK_Y+DECK_H-DECK_BORDER) && (y < DECK_Y+DECK_H           )) ||
       ((x >= DECK_X                 ) && (x < DECK_X+DECK_BORDER      ) && (y >= DECK_Y                  ) && (y < DECK_Y+DECK_H            )) ||
       ((x >= DECK_X+DECK_W-DECK_BORDER) && (x < DECK_X+DECK_W        ) && (y >= DECK_Y                  ) && (y < DECK_Y+DECK_H            ));

    wire inside_deck =
       (x >= DECK_X+DECK_BORDER) && (x < DECK_X+DECK_W-DECK_BORDER) &&
       (y >= DECK_Y+DECK_BORDER) && (y < DECK_Y+DECK_H-DECK_BORDER);

    wire deck_checker = inside_deck && (x[3] ^ y[3]);  // 8x8 checker

    // -------------------------
    // Text: "BLACKJACK" in center
    // -------------------------
    localparam TXT_S   = 2;                         // scale
    localparam TXT_W   = 6*TXT_S;                   // char advance
    localparam TXT_X0  = 320 - (9*TXT_W)/2;         // 9 letters
    localparam TXT_Y0  = 230;

    // We implement each letter with assigns only, using 5x7 patterns.

    // Helpers are per-character: signed lx/ly, col, row, bit pattern.
    // --- B (center) ---
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

    // --- second A (A2) ---
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

    // --- second C (C2) ---
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

    // --- second K (K2) ---
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
    // Balance label (left-middle)  "BALANCE: $1100"
    // -------------------------
    localparam BAL_S   = 2;
    localparam BAL_X0  = 40;
    localparam BAL_Y0  = 240;

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
    // Digits inside each card (move with card)
    // -------------------------
    localparam DIG_S      = 2;
    localparam [9:0] INSET_X = 12, INSET_Y = 10;

    // Example digits:
    // D0 = "2"; D1 = "6"; P0 = "8"; P1 = "9"

    // Dealer left card – "2"
    wire signed [10:0] d0_lx = $signed({1'b0,x}) - $signed(D_X0 + INSET_X);
    wire signed [10:0] d0_ly = $signed({1'b0,y}) - $signed(D_Y  + INSET_Y);
    wire        d0_in = (d0_lx >= 0) && (d0_lx < 5*DIG_S) &&
                        (d0_ly >= 0) && (d0_ly < 7*DIG_S);
    wire [2:0]  d0_col = d0_lx[10:0] / DIG_S;
    wire [2:0]  d0_row = d0_ly[10:0] / DIG_S;
    wire [6:0]  d0_bits =
        (d0_col==3'd0) ? 7'b0100011 :
        (d0_col==3'd1) ? 7'b1000101 :
        (d0_col==3'd2) ? 7'b1001001 :
        (d0_col==3'd3) ? 7'b1010001 :
        (d0_col==3'd4) ? 7'b0100001 :
                          7'b0000000;
    wire        d0_digit = d0_in && d0_bits[6 - d0_row];

    // Dealer right card – "6"
    wire signed [10:0] d1_lx = $signed({1'b0,x}) - $signed(D_X1 + INSET_X);
    wire signed [10:0] d1_ly = $signed({1'b0,y}) - $signed(D_Y  + INSET_Y);
    wire        d1_in = (d1_lx >= 0) && (d1_lx < 5*DIG_S) &&
                        (d1_ly >= 0) && (d1_ly < 7*DIG_S);
    wire [2:0]  d1_col = d1_lx[10:0] / DIG_S;
    wire [2:0]  d1_row = d1_ly[10:0] / DIG_S;
    wire [6:0]  d1_bits =
        (d1_col==3'd0) ? 7'b0111110 :
        (d1_col==3'd1) ? 7'b1010001 :
        (d1_col==3'd2) ? 7'b1010001 :
        (d1_col==3'd3) ? 7'b1010001 :
        (d1_col==3'd4) ? 7'b0001110 :
                          7'b0000000;
    wire        d1_digit = d1_in && d1_bits[6 - d1_row];

    // Player left card – "8"
    wire signed [10:0] p0_lx = $signed({1'b0,x}) - $signed(P_X0 + INSET_X);
    wire signed [10:0] p0_ly = $signed({1'b0,y}) - $signed(P_Y  + INSET_Y);
    wire        p0_in = (p0_lx >= 0) && (p0_lx < 5*DIG_S) &&
                        (p0_ly >= 0) && (p0_ly < 7*DIG_S);
    wire [2:0]  p0_col = p0_lx[10:0] / DIG_S;
    wire [2:0]  p0_row = p0_ly[10:0] / DIG_S;
    wire [6:0]  p0_bits =
        (p0_col==3'd0) ? 7'b0110110 :
        (p0_col==3'd1) ? 7'b1001001 :
        (p0_col==3'd2) ? 7'b1001001 :
        (p0_col==3'd3) ? 7'b1001001 :
        (p0_col==3'd4) ? 7'b0110110 :
                          7'b0000000;
    wire        p0_digit = p0_in && p0_bits[6 - p0_row];

    // Player right card – "9"
    wire signed [10:0] p1_lx = $signed({1'b0,x}) - $signed(P_X1 + INSET_X);
    wire signed [10:0] p1_ly = $signed({1'b0,y}) - $signed(P_Y  + INSET_Y);
    wire        p1_in = (p1_lx >= 0) && (p1_lx < 5*DIG_S) &&
                        (p1_ly >= 0) && (p1_ly < 7*DIG_S);
    wire [2:0]  p1_col = p1_lx[10:0] / DIG_S;
    wire [2:0]  p1_row = p1_ly[10:0] / DIG_S;
    wire [6:0]  p1_bits =
        (p1_col==3'd0) ? 7'b0111000 :
        (p1_col==3'd1) ? 7'b1000101 :
        (p1_col==3'd2) ? 7'b1000101 :
        (p1_col==3'd3) ? 7'b1000101 :
        (p1_col==3'd4) ? 7'b0111110 :
                        7'b0000000;
    wire        p1_digit = p1_in && p1_bits[6 - p1_row];

    // -------------------------
    // Painter's algorithm
    // -------------------------
    reg [1:0] R,G,B;
    always @* begin
        // background felt
        R = C0; G = G_DARK; B = C0;

        // deck back layer (slight shadow - gray)
        if (deck_back) begin R = C1; G = C1; B = C1; end

        // deck white fill
        if (deck_fill) begin R = C2; G = C2; B = C2; end

        // deck checker pattern (red) inside border
        if (deck_checker) begin R = 2'b11; G = 2'b00; B = 2'b00; end

        // deck border (black)
        if (deck_brd) begin R = C0; G = C0; B = C0; end

        // cards fill
        if (d0_fill || d1_fill || p0_fill || p1_fill) begin R = C2; G = C2; B = C2; end
        // cards border
        if (d0_brd  || d1_brd  || p0_brd  || p1_brd ) begin R = C0; G = C0; B = C0; end

        // digits on cards (black)
        if (d0_digit || d1_digit || p0_digit || p1_digit) begin R = C0; G = C0; B = C0; end

        // center "BLACKJACK" (light gray)
        if (blackjack_text) begin R = C1; G = C1; B = C1; end

        // balance label overrides with bright red
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
