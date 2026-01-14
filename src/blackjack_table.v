`default_nettype none

module blackjack_table (
    input  wire        clk_25MHz,
    input  wire        rst_n,

    // VALUES: 0 empty, 2..11 (11=A), 10 means 10/J/Q/K
    input  wire [3:0]  dealer_card1,
    input  wire [3:0]  dealer_card2,
    input  wire [3:0]  dealer_card3,
    input  wire [3:0]  dealer_card4,
    input  wire [3:0]  dealer_card5,

    input  wire [3:0]  player_card1,
    input  wire [3:0]  player_card2,
    input  wire [3:0]  player_card3,
    input  wire [3:0]  player_card4,
    input  wire [3:0]  player_card5,

    // BCD digits from core
    input  wire [3:0]  bal_d3,
    input  wire [3:0]  bal_d2,
    input  wire [3:0]  bal_d1,
    input  wire [3:0]  bal_d0,

    output wire        vga_hsync,
    output wire        vga_vsync,
    output reg  [1:0]  vga_r,
    output reg  [1:0]  vga_g,
    output reg  [1:0]  vga_b
);

    // ------------------------------------------------------------
    // VGA timing / coords
    // ------------------------------------------------------------
    wire [9:0] x, y;
    vga_controller vga_ctrl (
        .pixel_clk(clk_25MHz),
        .rst_n    (rst_n),
        .hsync    (vga_hsync),
        .vsync    (vga_vsync),
        .x_count  (x),
        .y_count  (y)
    );

    wire active = (x < 10'd640) && (y < 10'd480);

    // ------------------------------------------------------------
    // Colors (2-bit per channel)
    // ------------------------------------------------------------
    localparam [1:0] C0 = 2'b00; // black
    localparam [1:0] C1 = 2'b01; // gray
    localparam [1:0] C2 = 2'b11; // white
    localparam [1:0] GF = 2'b10; // felt green

    // ------------------------------------------------------------
    // Card layout
    // ------------------------------------------------------------
    localparam [9:0] CARD_W = 10'd70;
    localparam [9:0] CARD_H = 10'd100;
    localparam [9:0] GAP    = 10'd8;
    localparam [9:0] BOR    = 10'd2;

    localparam [9:0] TOTAL_W = 10'd382;          // 5*70 + 4*8
    localparam [9:0] BASE_X  = 10'd129;          // 320 - TOTAL_W/2
    localparam [9:0] D_Y     = 10'd60;
    localparam [9:0] P_Y     = 10'd300;

    localparam [9:0] X0 = BASE_X;
    localparam [9:0] X1 = BASE_X + (CARD_W+GAP)*1;
    localparam [9:0] X2 = BASE_X + (CARD_W+GAP)*2;
    localparam [9:0] X3 = BASE_X + (CARD_W+GAP)*3;
    localparam [9:0] X4 = BASE_X + (CARD_W+GAP)*4;

    wire d_row = (y >= D_Y) && (y < D_Y + CARD_H);
    wire p_row = (y >= P_Y) && (y < P_Y + CARD_H);

    // presence
    wire d1_has = (dealer_card1 != 4'd0);
    wire d2_has = (dealer_card2 != 4'd0);
    wire d3_has = (dealer_card3 != 4'd0);
    wire d4_has = (dealer_card4 != 4'd0);
    wire d5_has = (dealer_card5 != 4'd0);

    wire p1_has = (player_card1 != 4'd0);
    wire p2_has = (player_card2 != 4'd0);
    wire p3_has = (player_card3 != 4'd0);
    wire p4_has = (player_card4 != 4'd0);
    wire p5_has = (player_card5 != 4'd0);

    // fills
    wire d1_fill = d_row && (x >= X0) && (x < X0+CARD_W);
    wire d2_fill = d_row && (x >= X1) && (x < X1+CARD_W);
    wire d3_fill = d_row && (x >= X2) && (x < X2+CARD_W);
    wire d4_fill = d_row && (x >= X3) && (x < X3+CARD_W);
    wire d5_fill = d_row && (x >= X4) && (x < X4+CARD_W);

    wire p1_fill = p_row && (x >= X0) && (x < X0+CARD_W);
    wire p2_fill = p_row && (x >= X1) && (x < X1+CARD_W);
    wire p3_fill = p_row && (x >= X2) && (x < X2+CARD_W);
    wire p4_fill = p_row && (x >= X3) && (x < X3+CARD_W);
    wire p5_fill = p_row && (x >= X4) && (x < X4+CARD_W);

    // borders
    wire d1_brd = d1_fill && ( (x < X0+BOR) || (x >= X0+CARD_W-BOR) || (y < D_Y+BOR) || (y >= D_Y+CARD_H-BOR) );
    wire d2_brd = d2_fill && ( (x < X1+BOR) || (x >= X1+CARD_W-BOR) || (y < D_Y+BOR) || (y >= D_Y+CARD_H-BOR) );
    wire d3_brd = d3_fill && ( (x < X2+BOR) || (x >= X2+CARD_W-BOR) || (y < D_Y+BOR) || (y >= D_Y+CARD_H-BOR) );
    wire d4_brd = d4_fill && ( (x < X3+BOR) || (x >= X3+CARD_W-BOR) || (y < D_Y+BOR) || (y >= D_Y+CARD_H-BOR) );
    wire d5_brd = d5_fill && ( (x < X4+BOR) || (x >= X4+CARD_W-BOR) || (y < D_Y+BOR) || (y >= D_Y+CARD_H-BOR) );

    wire p1_brd = p1_fill && ( (x < X0+BOR) || (x >= X0+CARD_W-BOR) || (y < P_Y+BOR) || (y >= P_Y+CARD_H-BOR) );
    wire p2_brd = p2_fill && ( (x < X1+BOR) || (x >= X1+CARD_W-BOR) || (y < P_Y+BOR) || (y >= P_Y+CARD_H-BOR) );
    wire p3_brd = p3_fill && ( (x < X2+BOR) || (x >= X2+CARD_W-BOR) || (y < P_Y+BOR) || (y >= P_Y+CARD_H-BOR) );
    wire p4_brd = p4_fill && ( (x < X3+BOR) || (x >= X3+CARD_W-BOR) || (y < P_Y+BOR) || (y >= P_Y+CARD_H-BOR) );
    wire p5_brd = p5_fill && ( (x < X4+BOR) || (x >= X4+CARD_W-BOR) || (y < P_Y+BOR) || (y >= P_Y+CARD_H-BOR) );

    // ------------------------------------------------------------
    // Random 10/J/Q/K per slot
    // ------------------------------------------------------------
    reg [7:0] lfsr8;
    wire lfsr_fb = lfsr8[7] ^ lfsr8[5] ^ lfsr8[4] ^ lfsr8[3];

    always @(posedge clk_25MHz or negedge rst_n) begin
        if (!rst_n) lfsr8 <= 8'hA7;
        else        lfsr8 <= {lfsr8[6:0], lfsr_fb};
    end

    reg [1:0] d10v1, d10v2, d10v3, d10v4, d10v5;
    reg [1:0] p10v1, p10v2, p10v3, p10v4, p10v5;

    reg [3:0] d1_prev, d2_prev, d3_prev, d4_prev, d5_prev;
    reg [3:0] p1_prev, p2_prev, p3_prev, p4_prev, p5_prev;

    always @(posedge clk_25MHz or negedge rst_n) begin
        if (!rst_n) begin
            d1_prev <= 4'd0; d2_prev <= 4'd0; d3_prev <= 4'd0; d4_prev <= 4'd0; d5_prev <= 4'd0;
            p1_prev <= 4'd0; p2_prev <= 4'd0; p3_prev <= 4'd0; p4_prev <= 4'd0; p5_prev <= 4'd0;

            d10v1 <= 2'd0; d10v2 <= 2'd0; d10v3 <= 2'd0; d10v4 <= 2'd0; d10v5 <= 2'd0;
            p10v1 <= 2'd0; p10v2 <= 2'd0; p10v3 <= 2'd0; p10v4 <= 2'd0; p10v5 <= 2'd0;
        end else begin
            d1_prev <= dealer_card1; d2_prev <= dealer_card2; d3_prev <= dealer_card3; d4_prev <= dealer_card4; d5_prev <= dealer_card5;
            p1_prev <= player_card1; p2_prev <= player_card2; p3_prev <= player_card3; p4_prev <= player_card4; p5_prev <= player_card5;

            if (d1_prev == 4'd0 && dealer_card1 == 4'd10) d10v1 <= lfsr8[1:0];
            if (d2_prev == 4'd0 && dealer_card2 == 4'd10) d10v2 <= lfsr8[3:2];
            if (d3_prev == 4'd0 && dealer_card3 == 4'd10) d10v3 <= lfsr8[5:4];
            if (d4_prev == 4'd0 && dealer_card4 == 4'd10) d10v4 <= lfsr8[7:6];
            if (d5_prev == 4'd0 && dealer_card5 == 4'd10) d10v5 <= lfsr8[1:0];

            if (p1_prev == 4'd0 && player_card1 == 4'd10) p10v1 <= lfsr8[3:2];
            if (p2_prev == 4'd0 && player_card2 == 4'd10) p10v2 <= lfsr8[5:4];
            if (p3_prev == 4'd0 && player_card3 == 4'd10) p10v3 <= lfsr8[7:6];
            if (p4_prev == 4'd0 && player_card4 == 4'd10) p10v4 <= lfsr8[1:0];
            if (p5_prev == 4'd0 && player_card5 == 4'd10) p10v5 <= lfsr8[3:2];
        end
    end

    // ------------------------------------------------------------
    // Text drawing parameters
    // ------------------------------------------------------------
    localparam [9:0] DIG_S = 10'd2;      // scale
    localparam [9:0] IN_X  = 10'd12;
    localparam [9:0] IN_Y  = 10'd10;

    localparam [9:0] GLYPH_W = 10'd5;
    localparam [9:0] GLYPH_H = 10'd7;

    // ------------------------------------------------------------
    // Diamond per card (no function)
    // ------------------------------------------------------------
    reg [9:0] ax, ay;
    reg       diamond_on;

    always @(*) begin
        ax = 10'd0;
        ay = 10'd0;
        diamond_on = 1'b0;

        if (d1_fill && d1_has) begin
            ax = (x > (X0 + CARD_W/2)) ? (x - (X0 + CARD_W/2)) : ((X0 + CARD_W/2) - x);
            ay = (y > (D_Y + CARD_H/2)) ? (y - (D_Y + CARD_H/2)) : ((D_Y + CARD_H/2) - y);
            diamond_on = ((ax * 10'd11) + (ay * 10'd8)) <= 10'd88;
        end else if (d2_fill && d2_has) begin
            ax = (x > (X1 + CARD_W/2)) ? (x - (X1 + CARD_W/2)) : ((X1 + CARD_W/2) - x);
            ay = (y > (D_Y + CARD_H/2)) ? (y - (D_Y + CARD_H/2)) : ((D_Y + CARD_H/2) - y);
            diamond_on = ((ax * 10'd11) + (ay * 10'd8)) <= 10'd88;
        end else if (d3_fill && d3_has) begin
            ax = (x > (X2 + CARD_W/2)) ? (x - (X2 + CARD_W/2)) : ((X2 + CARD_W/2) - x);
            ay = (y > (D_Y + CARD_H/2)) ? (y - (D_Y + CARD_H/2)) : ((D_Y + CARD_H/2) - y);
            diamond_on = ((ax * 10'd11) + (ay * 10'd8)) <= 10'd88;
        end else if (d4_fill && d4_has) begin
            ax = (x > (X3 + CARD_W/2)) ? (x - (X3 + CARD_W/2)) : ((X3 + CARD_W/2) - x);
            ay = (y > (D_Y + CARD_H/2)) ? (y - (D_Y + CARD_H/2)) : ((D_Y + CARD_H/2) - y);
            diamond_on = ((ax * 10'd11) + (ay * 10'd8)) <= 10'd88;
        end else if (d5_fill && d5_has) begin
            ax = (x > (X4 + CARD_W/2)) ? (x - (X4 + CARD_W/2)) : ((X4 + CARD_W/2) - x);
            ay = (y > (D_Y + CARD_H/2)) ? (y - (D_Y + CARD_H/2)) : ((D_Y + CARD_H/2) - y);
            diamond_on = ((ax * 10'd11) + (ay * 10'd8)) <= 10'd88;
        end else if (p1_fill && p1_has) begin
            ax = (x > (X0 + CARD_W/2)) ? (x - (X0 + CARD_W/2)) : ((X0 + CARD_W/2) - x);
            ay = (y > (P_Y + CARD_H/2)) ? (y - (P_Y + CARD_H/2)) : ((P_Y + CARD_H/2) - y);
            diamond_on = ((ax * 10'd11) + (ay * 10'd8)) <= 10'd88;
        end else if (p2_fill && p2_has) begin
            ax = (x > (X1 + CARD_W/2)) ? (x - (X1 + CARD_W/2)) : ((X1 + CARD_W/2) - x);
            ay = (y > (P_Y + CARD_H/2)) ? (y - (P_Y + CARD_H/2)) : ((P_Y + CARD_H/2) - y);
            diamond_on = ((ax * 10'd11) + (ay * 10'd8)) <= 10'd88;
        end else if (p3_fill && p3_has) begin
            ax = (x > (X2 + CARD_W/2)) ? (x - (X2 + CARD_W/2)) : ((X2 + CARD_W/2) - x);
            ay = (y > (P_Y + CARD_H/2)) ? (y - (P_Y + CARD_H/2)) : ((P_Y + CARD_H/2) - y);
            diamond_on = ((ax * 10'd11) + (ay * 10'd8)) <= 10'd88;
        end else if (p4_fill && p4_has) begin
            ax = (x > (X3 + CARD_W/2)) ? (x - (X3 + CARD_W/2)) : ((X3 + CARD_W/2) - x);
            ay = (y > (P_Y + CARD_H/2)) ? (y - (P_Y + CARD_H/2)) : ((P_Y + CARD_H/2) - y);
            diamond_on = ((ax * 10'd11) + (ay * 10'd8)) <= 10'd88;
        end else if (p5_fill && p5_has) begin
            ax = (x > (X4 + CARD_W/2)) ? (x - (X4 + CARD_W/2)) : ((X4 + CARD_W/2) - x);
            ay = (y > (P_Y + CARD_H/2)) ? (y - (P_Y + CARD_H/2)) : ((P_Y + CARD_H/2) - y);
            diamond_on = ((ax * 10'd11) + (ay * 10'd8)) <= 10'd88;
        end
    end

    // ------------------------------------------------------------
    // Decide glyph(s) for a given VALUE + variant
    // ------------------------------------------------------------
    reg [4:0] g0, g1;
    reg       use_two;

    reg [3:0] cur_val;
    reg [1:0] cur_v10;

    always @(*) begin
        g0 = 5'd0; g1 = 5'd0; use_two = 1'b0;

        if (cur_val == 4'd11) begin
            g0 = 5'd1; // A
        end else if (cur_val >= 4'd2 && cur_val <= 4'd9) begin
            g0 = {1'b0, cur_val}; // 2..9
        end else if (cur_val == 4'd10) begin
            if (cur_v10 == 2'd0) begin
                use_two = 1'b1;
                g0 = 5'd11; // '1'
                g1 = 5'd10; // '0'
            end else if (cur_v10 == 2'd1) begin
                g0 = 5'd12; // J
            end else if (cur_v10 == 2'd2) begin
                g0 = 5'd13; // Q
            end else begin
                g0 = 5'd14; // K
            end
        end else begin
            g0 = 5'd0;
        end
    end

    // ------------------------------------------------------------
    // Corner digits
    // ------------------------------------------------------------
    reg corner_on;
    reg signed [11:0] lx, ly;
    reg [2:0] col, row;
    wire pix0, pix1;

    glyph5x7 u_g0 (.code(g0), .col(col), .row(row), .on(pix0));
    glyph5x7 u_g1 (.code(g1), .col(col), .row(row), .on(pix1));

    // width in pixels of the corner label
    wire signed [11:0] label_w = $signed(use_two ? ((GLYPH_W*2 + 1) * DIG_S) : (GLYPH_W * DIG_S));
    wire signed [11:0] label_h = $signed(GLYPH_H * DIG_S);

    always @(*) begin
        // DEFAULTS (prevent latches)
        corner_on = 1'b0;
        cur_val   = 4'd0;
        cur_v10   = 2'd0;
        lx        = 12'sd0;
        ly        = 12'sd0;
        col       = 3'd0;
        row       = 3'd0;

        // Dealer 1
        if (d1_fill && d1_has) begin
            cur_val = dealer_card1; cur_v10 = d10v1;

            // TL
            lx = $signed({1'b0,x}) - $signed(X0 + IN_X);
            ly = $signed({1'b0,y}) - $signed(D_Y + IN_Y);
            if (lx >= 0 && ly >= 0 && lx < label_w && ly < label_h) begin
                col = lx / DIG_S;
                row = ly / DIG_S;
                if (use_two) begin
                    if (col < 3'd5) corner_on = pix0;
                    else if (col > 3'd5) begin
                        col = col - 3'd6;
                        corner_on = pix1;
                    end
                end else begin
                    corner_on = pix0;
                end
            end

            // BR
            lx = $signed({1'b0,x}) - $signed(X0 + CARD_W - IN_X - label_w);
            ly = $signed({1'b0,y}) - $signed(D_Y + CARD_H - IN_Y - label_h);
            if (!corner_on && lx >= 0 && ly >= 0 && lx < label_w && ly < label_h) begin
                col = lx / DIG_S;
                row = ly / DIG_S;
                if (use_two) begin
                    if (col < 3'd5) corner_on = pix0;
                    else if (col > 3'd5) begin
                        col = col - 3'd6;
                        corner_on = pix1;
                    end
                end else begin
                    corner_on = pix0;
                end
            end

        end else if (d2_fill && d2_has) begin
            cur_val = dealer_card2; cur_v10 = d10v2;

            lx = $signed({1'b0,x}) - $signed(X1 + IN_X);
            ly = $signed({1'b0,y}) - $signed(D_Y + IN_Y);
            if (lx >= 0 && ly >= 0 && lx < label_w && ly < label_h) begin
                col = lx / DIG_S; row = ly / DIG_S;
                if (use_two) begin
                    if (col < 3'd5) corner_on = pix0;
                    else if (col > 3'd5) begin col = col - 3'd6; corner_on = pix1; end
                end else corner_on = pix0;
            end

            lx = $signed({1'b0,x}) - $signed(X1 + CARD_W - IN_X - label_w);
            ly = $signed({1'b0,y}) - $signed(D_Y + CARD_H - IN_Y - label_h);
            if (!corner_on && lx >= 0 && ly >= 0 && lx < label_w && ly < label_h) begin
                col = lx / DIG_S; row = ly / DIG_S;
                if (use_two) begin
                    if (col < 3'd5) corner_on = pix0;
                    else if (col > 3'd5) begin col = col - 3'd6; corner_on = pix1; end
                end else corner_on = pix0;
            end

        end else if (d3_fill && d3_has) begin
            cur_val = dealer_card3; cur_v10 = d10v3;

            lx = $signed({1'b0,x}) - $signed(X2 + IN_X);
            ly = $signed({1'b0,y}) - $signed(D_Y + IN_Y);
            if (lx >= 0 && ly >= 0 && lx < label_w && ly < label_h) begin
                col = lx / DIG_S; row = ly / DIG_S;
                if (use_two) begin
                    if (col < 3'd5) corner_on = pix0;
                    else if (col > 3'd5) begin col = col - 3'd6; corner_on = pix1; end
                end else corner_on = pix0;
            end

            lx = $signed({1'b0,x}) - $signed(X2 + CARD_W - IN_X - label_w);
            ly = $signed({1'b0,y}) - $signed(D_Y + CARD_H - IN_Y - label_h);
            if (!corner_on && lx >= 0 && ly >= 0 && lx < label_w && ly < label_h) begin
                col = lx / DIG_S; row = ly / DIG_S;
                if (use_two) begin
                    if (col < 3'd5) corner_on = pix0;
                    else if (col > 3'd5) begin col = col - 3'd6; corner_on = pix1; end
                end else corner_on = pix0;
            end

        end else if (d4_fill && d4_has) begin
            cur_val = dealer_card4; cur_v10 = d10v4;

            lx = $signed({1'b0,x}) - $signed(X3 + IN_X);
            ly = $signed({1'b0,y}) - $signed(D_Y + IN_Y);
            if (lx >= 0 && ly >= 0 && lx < label_w && ly < label_h) begin
                col = lx / DIG_S; row = ly / DIG_S;
                if (use_two) begin
                    if (col < 3'd5) corner_on = pix0;
                    else if (col > 3'd5) begin col = col - 3'd6; corner_on = pix1; end
                end else corner_on = pix0;
            end

            lx = $signed({1'b0,x}) - $signed(X3 + CARD_W - IN_X - label_w);
            ly = $signed({1'b0,y}) - $signed(D_Y + CARD_H - IN_Y - label_h);
            if (!corner_on && lx >= 0 && ly >= 0 && lx < label_w && ly < label_h) begin
                col = lx / DIG_S; row = ly / DIG_S;
                if (use_two) begin
                    if (col < 3'd5) corner_on = pix0;
                    else if (col > 3'd5) begin col = col - 3'd6; corner_on = pix1; end
                end else corner_on = pix0;
            end

        end else if (d5_fill && d5_has) begin
            cur_val = dealer_card5; cur_v10 = d10v5;

            lx = $signed({1'b0,x}) - $signed(X4 + IN_X);
            ly = $signed({1'b0,y}) - $signed(D_Y + IN_Y);
            if (lx >= 0 && ly >= 0 && lx < label_w && ly < label_h) begin
                col = lx / DIG_S; row = ly / DIG_S;
                if (use_two) begin
                    if (col < 3'd5) corner_on = pix0;
                    else if (col > 3'd5) begin col = col - 3'd6; corner_on = pix1; end
                end else corner_on = pix0;
            end

            lx = $signed({1'b0,x}) - $signed(X4 + CARD_W - IN_X - label_w);
            ly = $signed({1'b0,y}) - $signed(D_Y + CARD_H - IN_Y - label_h);
            if (!corner_on && lx >= 0 && ly >= 0 && lx < label_w && ly < label_h) begin
                col = lx / DIG_S; row = ly / DIG_S;
                if (use_two) begin
                    if (col < 3'd5) corner_on = pix0;
                    else if (col > 3'd5) begin col = col - 3'd6; corner_on = pix1; end
                end else corner_on = pix0;
            end

        // Player cards
        end else if (p1_fill && p1_has) begin
            cur_val = player_card1; cur_v10 = p10v1;

            lx = $signed({1'b0,x}) - $signed(X0 + IN_X);
            ly = $signed({1'b0,y}) - $signed(P_Y + IN_Y);
            if (lx >= 0 && ly >= 0 && lx < label_w && ly < label_h) begin
                col = lx / DIG_S; row = ly / DIG_S;
                if (use_two) begin
                    if (col < 3'd5) corner_on = pix0;
                    else if (col > 3'd5) begin col = col - 3'd6; corner_on = pix1; end
                end else corner_on = pix0;
            end

            lx = $signed({1'b0,x}) - $signed(X0 + CARD_W - IN_X - label_w);
            ly = $signed({1'b0,y}) - $signed(P_Y + CARD_H - IN_Y - label_h);
            if (!corner_on && lx >= 0 && ly >= 0 && lx < label_w && ly < label_h) begin
                col = lx / DIG_S; row = ly / DIG_S;
                if (use_two) begin
                    if (col < 3'd5) corner_on = pix0;
                    else if (col > 3'd5) begin col = col - 3'd6; corner_on = pix1; end
                end else corner_on = pix0;
            end

        end else if (p2_fill && p2_has) begin
            cur_val = player_card2; cur_v10 = p10v2;

            lx = $signed({1'b0,x}) - $signed(X1 + IN_X);
            ly = $signed({1'b0,y}) - $signed(P_Y + IN_Y);
            if (lx >= 0 && ly >= 0 && lx < label_w && ly < label_h) begin
                col = lx / DIG_S; row = ly / DIG_S;
                if (use_two) begin
                    if (col < 3'd5) corner_on = pix0;
                    else if (col > 3'd5) begin col = col - 3'd6; corner_on = pix1; end
                end else corner_on = pix0;
            end

            lx = $signed({1'b0,x}) - $signed(X1 + CARD_W - IN_X - label_w);
            ly = $signed({1'b0,y}) - $signed(P_Y + CARD_H - IN_Y - label_h);
            if (!corner_on && lx >= 0 && ly >= 0 && lx < label_w && ly < label_h) begin
                col = lx / DIG_S; row = ly / DIG_S;
                if (use_two) begin
                    if (col < 3'd5) corner_on = pix0;
                    else if (col > 3'd5) begin col = col - 3'd6; corner_on = pix1; end
                end else corner_on = pix0;
            end

        end else if (p3_fill && p3_has) begin
            cur_val = player_card3; cur_v10 = p10v3;

            lx = $signed({1'b0,x}) - $signed(X2 + IN_X);
            ly = $signed({1'b0,y}) - $signed(P_Y + IN_Y);
            if (lx >= 0 && ly >= 0 && lx < label_w && ly < label_h) begin
                col = lx / DIG_S; row = ly / DIG_S;
                if (use_two) begin
                    if (col < 3'd5) corner_on = pix0;
                    else if (col > 3'd5) begin col = col - 3'd6; corner_on = pix1; end
                end else corner_on = pix0;
            end

            lx = $signed({1'b0,x}) - $signed(X2 + CARD_W - IN_X - label_w);
            ly = $signed({1'b0,y}) - $signed(P_Y + CARD_H - IN_Y - label_h);
            if (!corner_on && lx >= 0 && ly >= 0 && lx < label_w && ly < label_h) begin
                col = lx / DIG_S; row = ly / DIG_S;
                if (use_two) begin
                    if (col < 3'd5) corner_on = pix0;
                    else if (col > 3'd5) begin col = col - 3'd6; corner_on = pix1; end
                end else corner_on = pix0;
            end

        end else if (p4_fill && p4_has) begin
            cur_val = player_card4; cur_v10 = p10v4;

            lx = $signed({1'b0,x}) - $signed(X3 + IN_X);
            ly = $signed({1'b0,y}) - $signed(P_Y + IN_Y);
            if (lx >= 0 && ly >= 0 && lx < label_w && ly < label_h) begin
                col = lx / DIG_S; row = ly / DIG_S;
                if (use_two) begin
                    if (col < 3'd5) corner_on = pix0;
                    else if (col > 3'd5) begin col = col - 3'd6; corner_on = pix1; end
                end else corner_on = pix0;
            end

            lx = $signed({1'b0,x}) - $signed(X3 + CARD_W - IN_X - label_w);
            ly = $signed({1'b0,y}) - $signed(P_Y + CARD_H - IN_Y - label_h);
            if (!corner_on && lx >= 0 && ly >= 0 && lx < label_w && ly < label_h) begin
                col = lx / DIG_S; row = ly / DIG_S;
                if (use_two) begin
                    if (col < 3'd5) corner_on = pix0;
                    else if (col > 3'd5) begin col = col - 3'd6; corner_on = pix1; end
                end else corner_on = pix0;
            end

        end else if (p5_fill && p5_has) begin
            cur_val = player_card5; cur_v10 = p10v5;

            lx = $signed({1'b0,x}) - $signed(X4 + IN_X);
            ly = $signed({1'b0,y}) - $signed(P_Y + IN_Y);
            if (lx >= 0 && ly >= 0 && lx < label_w && ly < label_h) begin
                col = lx / DIG_S; row = ly / DIG_S;
                if (use_two) begin
                    if (col < 3'd5) corner_on = pix0;
                    else if (col > 3'd5) begin col = col - 3'd6; corner_on = pix1; end
                end else corner_on = pix0;
            end

            lx = $signed({1'b0,x}) - $signed(X4 + CARD_W - IN_X - label_w);
            ly = $signed({1'b0,y}) - $signed(P_Y + CARD_H - IN_Y - label_h);
            if (!corner_on && lx >= 0 && ly >= 0 && lx < label_w && ly < label_h) begin
                col = lx / DIG_S; row = ly / DIG_S;
                if (use_two) begin
                    if (col < 3'd5) corner_on = pix0;
                    else if (col > 3'd5) begin col = col - 3'd6; corner_on = pix1; end
                end else corner_on = pix0;
            end
        end
    end

    // ------------------------------------------------------------
    // BAL label (red): "BAL" + 4 digits
    // ------------------------------------------------------------
    localparam [9:0] BAL_X0 = 10'd40;
    localparam [9:0] BAL_Y0 = 10'd240;
    localparam [9:0] BAL_S  = 10'd2;

    reg bal_on;
    reg signed [11:0] blx, bly;
    reg [2:0] bcol, brow;
    reg [4:0] bcode;
    wire bpix;

    // IMPORTANT: idx/cc must be declared OUTSIDE always @(*) in Verilog
    reg [3:0] idx;
    reg [2:0] cc;

    glyph5x7 u_b (.code(bcode), .col(bcol), .row(brow), .on(bpix));

    always @(*) begin
        // DEFAULTS (prevent latches)
        bal_on = 1'b0;
        blx    = 12'sd0;
        bly    = 12'sd0;
        idx    = 4'd0;
        cc     = 3'd0;
        bcol   = 3'd0;
        brow   = 3'd0;
        bcode  = 5'd0;

        blx = $signed({1'b0,x}) - $signed(BAL_X0);
        bly = $signed({1'b0,y}) - $signed(BAL_Y0);

        if (blx >= 0 && bly >= 0 && blx < $signed(10'd9 * 10'd6 * BAL_S) && bly < $signed(10'd7 * BAL_S)) begin
            idx  = blx / (6*BAL_S);
            cc   = (blx / BAL_S) - (idx * 6);

            bcol = cc;                 // 0..5
            brow = (bly / BAL_S);      // 0..6

            if (bcol < 3'd5 && brow < 3'd7) begin
                case (idx)
                    4'd0: bcode = 5'd15; // B
                    4'd1: bcode = 5'd1;  // A
                    4'd2: bcode = 5'd16; // L
                    4'd4: bcode = {1'b0, bal_d3};
                    4'd5: bcode = {1'b0, bal_d2};
                    4'd6: bcode = {1'b0, bal_d1};
                    4'd7: bcode = {1'b0, bal_d0};
                    default: bcode = 5'd0;
                endcase

                if (idx >= 4'd4 && idx <= 4'd7) begin
                    if (bcode[3:0] == 4'd0)      bcode = 5'd10;
                    else if (bcode[3:0] == 4'd1) bcode = 5'd11;
                    else                         bcode = {1'b0, bcode[3:0]};
                end

                bal_on = bpix;
            end
        end
    end

    // ------------------------------------------------------------
    // Painter
    // ------------------------------------------------------------
    reg [1:0] R,G,B;

    always @(*) begin
        R = C0; G = GF; B = C0;

        if ((d1_fill && d1_has) || (d2_fill && d2_has) || (d3_fill && d3_has) || (d4_fill && d4_has) || (d5_fill && d5_has) ||
            (p1_fill && p1_has) || (p2_fill && p2_has) || (p3_fill && p3_has) || (p4_fill && p4_has) || (p5_fill && p5_has)) begin
            R = C2; G = C2; B = C2;
        end

        if ((d1_brd && d1_has) || (d2_brd && d2_has) || (d3_brd && d3_has) || (d4_brd && d4_has) || (d5_brd && d5_has) ||
            (p1_brd && p1_has) || (p2_brd && p2_has) || (p3_brd && p3_has) || (p4_brd && p4_has) || (p5_brd && p5_has)) begin
            R = C0; G = C0; B = C0;
        end

        if (diamond_on) begin
            R = 2'b11; G = 2'b00; B = 2'b00;
        end

        if (corner_on) begin
            R = C0; G = C0; B = C0;
        end

        if (bal_on) begin
            R = 2'b11; G = 2'b00; B = 2'b00;
        end

        if (!active) begin
            R = C0; G = C0; B = C0;
        end
    end

    always @(posedge clk_25MHz or negedge rst_n) begin
        if (!rst_n) begin
            vga_r <= 2'b00;
            vga_g <= 2'b00;
            vga_b <= 2'b00;
        end else begin
            vga_r <= R;
            vga_g <= G;
            vga_b <= B;
        end
    end

endmodule


// ============================================================================
// glyph5x7
// ============================================================================
module glyph5x7 (
    input  wire [4:0] code,
    input  wire [2:0] col,
    input  wire [2:0] row,
    output reg        on
);
    reg [4:0] r0,r1,r2,r3,r4,r5,r6;

    always @(*) begin
        r0=5'b00000; r1=5'b00000; r2=5'b00000; r3=5'b00000; r4=5'b00000; r5=5'b00000; r6=5'b00000;

        case (code)
            5'd1: begin
                r0=5'b00100; r1=5'b01010; r2=5'b10001; r3=5'b11111; r4=5'b10001; r5=5'b10001; r6=5'b00000;
            end
            5'd2: begin
                r0=5'b01110; r1=5'b10001; r2=5'b00001; r3=5'b00110; r4=5'b01000; r5=5'b11111; r6=5'b00000;
            end
            5'd3: begin
                r0=5'b01110; r1=5'b10001; r2=5'b00001; r3=5'b00110; r4=5'b00001; r5=5'b10001; r6=5'b01110;
            end
            5'd4: begin
                r0=5'b00010; r1=5'b00110; r2=5'b01010; r3=5'b10010; r4=5'b11111; r5=5'b00010; r6=5'b00010;
            end
            5'd5: begin
                r0=5'b11111; r1=5'b10000; r2=5'b11110; r3=5'b00001; r4=5'b00001; r5=5'b10001; r6=5'b01110;
            end
            5'd6: begin
                r0=5'b01110; r1=5'b10000; r2=5'b11110; r3=5'b10001; r4=5'b10001; r5=5'b10001; r6=5'b01110;
            end
            5'd7: begin
                r0=5'b11111; r1=5'b00001; r2=5'b00010; r3=5'b00100; r4=5'b01000; r5=5'b01000; r6=5'b01000;
            end
            5'd8: begin
                r0=5'b01110; r1=5'b10001; r2=5'b10001; r3=5'b01110; r4=5'b10001; r5=5'b10001; r6=5'b01110;
            end
            5'd9: begin
                r0=5'b01110; r1=5'b10001; r2=5'b10001; r3=5'b01111; r4=5'b00001; r5=5'b00001; r6=5'b01110;
            end
            5'd10: begin
                r0=5'b01110; r1=5'b10001; r2=5'b10011; r3=5'b10101; r4=5'b11001; r5=5'b10001; r6=5'b01110;
            end
            5'd11: begin
                r0=5'b00100; r1=5'b01100; r2=5'b00100; r3=5'b00100; r4=5'b00100; r5=5'b00100; r6=5'b01110;
            end
            5'd12: begin
                r0=5'b00111; r1=5'b00010; r2=5'b00010; r3=5'b00010; r4=5'b10010; r5=5'b10010; r6=5'b01100;
            end
            5'd13: begin
                r0=5'b01110; r1=5'b10001; r2=5'b10001; r3=5'b10001; r4=5'b10101; r5=5'b10010; r6=5'b01101;
            end
            5'd14: begin
                r0=5'b10001; r1=5'b10010; r2=5'b10100; r3=5'b11000; r4=5'b10100; r5=5'b10010; r6=5'b10001;
            end
            5'd15: begin
                r0=5'b11110; r1=5'b10001; r2=5'b10001; r3=5'b11110; r4=5'b10001; r5=5'b10001; r6=5'b11110;
            end
            5'd16: begin
                r0=5'b10000; r1=5'b10000; r2=5'b10000; r3=5'b10000; r4=5'b10000; r5=5'b10000; r6=5'b11111;
            end
            default: begin
                r0=5'b00000; r1=5'b00000; r2=5'b00000; r3=5'b00000; r4=5'b00000; r5=5'b00000; r6=5'b00000;
            end
        endcase

        on = 1'b0;
        if (col < 3'd5 && row < 3'd7) begin
            case (row)
                3'd0: on = r0[4-col];
                3'd1: on = r1[4-col];
                3'd2: on = r2[4-col];
                3'd3: on = r3[4-col];
                3'd4: on = r4[4-col];
                3'd5: on = r5[4-col];
                3'd6: on = r6[4-col];
                default: on = 1'b0;
            endcase
        end
    end
endmodule
