// ============================================================================
// blackjack_table.v  (640x480 @ 25 MHz)
// Felt background, dealer+player cards with green gap, "BLACKJACK" in center,
// "Balance: $1100" at left-middle (red), and a face-down deck on right-middle.
// Digits inside cards move with the card position.
// (Buttons were removed to free space for future cards.)
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
    // Helpers
    // -------------------------
    function automatic rect; // [x0,x1) x [y0,y1)
        input [9:0] X,Y,x0,y0,x1,y1;
        begin
            rect = (X>=x0)&&(X<x1)&&(Y>=y0)&&(Y<y1);
        end
    endfunction

    function automatic rect_border;
        input [9:0] X,Y,x0,y0,x1,y1; input [3:0] th;
        begin
            rect_border =
                rect(X,Y,x0,y0,x1,y0+th) ||
                rect(X,Y,x0,y1-th,x1,y1) ||
                rect(X,Y,x0,y0,x0+th,y1) ||
                rect(X,Y,x1-th,y0,x1,y1);
        end
    endfunction

    // -------------------------
    // 5x7 font (subset) + scaler
    // font_col(ch,col) -> 7 bits (bit6=top row, bit0=bottom)
    // -------------------------
    function automatic [6:0] font_col;
        input [7:0] ch; input [2:0] col;
        begin
            case (ch)
                // Digits 0..9
                "0": case(col) 0:font_col=7'b0111110; 1:font_col=7'b1000001;
                                 2:font_col=7'b1000001; 3:font_col=7'b1000001;
                                 4:font_col=7'b0111110; default:font_col=7'b0; endcase
                "1": case(col) 0:font_col=7'b0000000; 1:font_col=7'b0100001;
                                 2:font_col=7'b1111111; 3:font_col=7'b0000001;
                                 4:font_col=7'b0000000; default:font_col=7'b0; endcase
                "2": case(col) 0:font_col=7'b0100011; 1:font_col=7'b1000101;
                                 2:font_col=7'b1001001; 3:font_col=7'b1010001;
                                 4:font_col=7'b0100001; default:font_col=7'b0; endcase
                "3": case(col) 0:font_col=7'b0100010; 1:font_col=7'b1000001;
                                 2:font_col=7'b1001001; 3:font_col=7'b1001001;
                                 4:font_col=7'b0110110; default:font_col=7'b0; endcase
                "4": case(col) 0:font_col=7'b0001100; 1:font_col=7'b0010100;
                                 2:font_col=7'b0100100; 3:font_col=7'b1111111;
                                 4:font_col=7'b0000100; default:font_col=7'b0; endcase
                "5": case(col) 0:font_col=7'b1111001; 1:font_col=7'b1010001;
                                 2:font_col=7'b1010001; 3:font_col=7'b1010001;
                                 4:font_col=7'b1001110; default:font_col=7'b0; endcase
                "6": case(col) 0:font_col=7'b0111110; 1:font_col=7'b1010001;
                                 2:font_col=7'b1010001; 3:font_col=7'b1010001;
                                 4:font_col=7'b0001110; default:font_col=7'b0; endcase
                "7": case(col) 0:font_col=7'b1000000; 1:font_col=7'b1001111;
                                 2:font_col=7'b1010000; 3:font_col=7'b1100000;
                                 4:font_col=7'b1000000; default:font_col=7'b0; endcase
                "8": case(col) 0:font_col=7'b0110110; 1:font_col=7'b1001001;
                                 2:font_col=7'b1001001; 3:font_col=7'b1001001;
                                 4:font_col=7'b0110110; default:font_col=7'b0; endcase
                "9": case(col) 0:font_col=7'b0111000; 1:font_col=7'b1000101;
                                 2:font_col=7'b1000101; 3:font_col=7'b1000101;
                                 4:font_col=7'b0111110; default:font_col=7'b0; endcase
                // Letters used: A,B,C,E,J,K,L,N (BLACKJACK + BALANCE)
                "A": case(col) 0:font_col=7'b0011111; 1:font_col=7'b0100100;
                                 2:font_col=7'b0100100; 3:font_col=7'b0100100;
                                 4:font_col=7'b0011111; default:font_col=7'b0; endcase
                "B": case(col) 0:font_col=7'b1111111; 1:font_col=7'b1001001;
                                 2:font_col=7'b1001001; 3:font_col=7'b1001001;
                                 4:font_col=7'b0110110; default:font_col=7'b0; endcase
                "C": case(col) 0:font_col=7'b0111110; 1:font_col=7'b1000001;
                                 2:font_col=7'b1000001; 3:font_col=7'b1000001;
                                 4:font_col=7'b0100010; default:font_col=7'b0; endcase
                "E": case(col) 0:font_col=7'b1111111; 1:font_col=7'b1001001;
                                 2:font_col=7'b1001001; 3:font_col=7'b1001001;
                                 4:font_col=7'b1001001; default:font_col=7'b0; endcase
                "J": case(col) 0:font_col=7'b0000010; 1:font_col=7'b0000001;
                                 2:font_col=7'b1000001; 3:font_col=7'b1111110;
                                 4:font_col=7'b1000000; default:font_col=7'b0; endcase
                "K": case(col) 0:font_col=7'b1111111; 1:font_col=7'b0001000;
                                 2:font_col=7'b0010100; 3:font_col=7'b0100010;
                                 4:font_col=7'b1000001; default:font_col=7'b0; endcase
                "L": case(col) 0:font_col=7'b1111111; 1:font_col=7'b1000000;
                                 2:font_col=7'b1000000; 3:font_col=7'b1000000;
                                 4:font_col=7'b1000000; default:font_col=7'b0; endcase
                "N": case(col) 0:font_col=7'b1111111; 1:font_col=7'b0110000;
                                 2:font_col=7'b0001100; 3:font_col=7'b0000011;
                                 4:font_col=7'b1111111; default:font_col=7'b0; endcase
                // Symbols: ':' and '$'
                ":": case(col) 0:font_col=7'b0000000; 1:font_col=7'b0000000;
                                 2:font_col=7'b0010100; 3:font_col=7'b0000000;
                                 4:font_col=7'b0000000; default:font_col=7'b0; endcase
                "$": case(col) 0:font_col=7'b0110010; 1:font_col=7'b1001001;
                                 2:font_col=7'b1001001; 3:font_col=7'b1001001;
                                 4:font_col=7'b0100110; default:font_col=7'b0; endcase
                default: font_col = 7'b0000000;
            endcase
        end
    endfunction

    function automatic text_px; // scaled 5x7 at (gx,gy)
        input [9:0] X,Y,gx,gy; input [7:0] ch; input [2:0] scale;
        integer lx, ly, col, row; reg [6:0] colbits;
        begin
            text_px = 1'b0;
            if (X>=gx && Y>=gy) begin
                lx = X - gx; ly = Y - gy;
                if (lx < (5*scale) && ly < (7*scale)) begin
                    col = lx/scale; row = ly/scale;
                    colbits = font_col(ch, col[2:0]);
                    text_px = colbits[6-row]; // bit6 = top row
                end
            end
        end
    endfunction

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
    localparam DECK_Y = 240 - (DECK_H/2);                    // vertical center
    localparam DECK_BORDER = 2;

    // Slight back layer for "thickness"
    localparam DECK2_DX = -4;
    localparam DECK2_DY = -4;

    // -------------------------
    // Colors (2-bit each)
    // -------------------------
    localparam [1:0] C0 = 2'b00; // black
    localparam [1:0] C1 = 2'b01; // gray (for center text)
    localparam [1:0] C2 = 2'b11; // white
    localparam [1:0] G_DARK   = 2'b10; // felt

    // Primitive areas
    wire d0_fill = rect(x,y, D_X0, D_Y, D_X0+CARD_W, D_Y+CARD_H);
    wire d1_fill = rect(x,y, D_X1, D_Y, D_X1+CARD_W, D_Y+CARD_H);
    wire d0_brd  = rect_border(x,y, D_X0, D_Y, D_X0+CARD_W, D_Y+CARD_H, BORDER);
    wire d1_brd  = rect_border(x,y, D_X1, D_Y, D_X1+CARD_W, D_Y+CARD_H, BORDER);

    wire p0_fill = rect(x,y, P_X0, P_Y, P_X0+CARD_W, P_Y+CARD_H);
    wire p1_fill = rect(x,y, P_X1, P_Y, P_X1+CARD_W, P_Y+CARD_H);
    wire p0_brd  = rect_border(x,y, P_X0, P_Y, P_X0+CARD_W, P_Y+CARD_H, BORDER);
    wire p1_brd  = rect_border(x,y, P_X1, P_Y, P_X1+CARD_W, P_Y+CARD_H, BORDER);

    // Deck rectangles
    wire deck_back = rect(x,y, DECK_X+DECK2_DX, DECK_Y+DECK2_DY,
                               DECK_X+DECK2_DX+DECK_W, DECK_Y+DECK2_DY+DECK_H);
    wire deck_fill = rect(x,y, DECK_X, DECK_Y, DECK_X+DECK_W, DECK_Y+DECK_H);
    wire deck_brd  = rect_border(x,y, DECK_X, DECK_Y, DECK_X+DECK_W, DECK_Y+DECK_H, DECK_BORDER);

    // Checker pattern inside deck (red diamonds style)
    wire inside_deck = rect(x,y, DECK_X+DECK_BORDER, DECK_Y+DECK_BORDER,
                                 DECK_X+DECK_W-DECK_BORDER, DECK_Y+DECK_H-DECK_BORDER);
    // 8x8 checker using bits [3] of x,y (alternating)
    wire deck_checker = inside_deck && ( (x[3] ^ y[3]) );

    // -------------------------
    // Center text: "BLACKJACK"
    // -------------------------
    localparam TXT_S   = 2;                         // scale
    localparam TXT_W   = 6*TXT_S;                   // char advance
    localparam TXT_X0  = 320 - (9*TXT_W)/2;         // 9 letters
    localparam TXT_Y0  = 230;

    wire tB = text_px(x,y, TXT_X0 + 0*TXT_W, TXT_Y0, "B", TXT_S);
    wire tL = text_px(x,y, TXT_X0 + 1*TXT_W, TXT_Y0, "L", TXT_S);
    wire tA = text_px(x,y, TXT_X0 + 2*TXT_W, TXT_Y0, "A", TXT_S);
    wire tC = text_px(x,y, TXT_X0 + 3*TXT_W, TXT_Y0, "C", TXT_S);
    wire tK = text_px(x,y, TXT_X0 + 4*TXT_W, TXT_Y0, "K", TXT_S);
    wire tJ = text_px(x,y, TXT_X0 + 5*TXT_W, TXT_Y0, "J", TXT_S);
    wire tA2= text_px(x,y, TXT_X0 + 6*TXT_W, TXT_Y0, "A", TXT_S);
    wire tC2= text_px(x,y, TXT_X0 + 7*TXT_W, TXT_Y0, "C", TXT_S);
    wire tK2= text_px(x,y, TXT_X0 + 8*TXT_W, TXT_Y0, "K", TXT_S);
    wire blackjack_text = tB|tL|tA|tC|tK|tJ|tA2|tC2|tK2;

    // -------------------------
    // Balance label (left-middle)  "BALANCE: $1100"
    // -------------------------
    localparam BAL_S   = 2;
    localparam BAL_X0  = 40;
    localparam BAL_Y0  = 240;

    wire b_B = text_px(x,y, BAL_X0 + 0*6*BAL_S, BAL_Y0, "B", BAL_S);
    wire b_A = text_px(x,y, BAL_X0 + 1*6*BAL_S, BAL_Y0, "A", BAL_S);
    wire b_L = text_px(x,y, BAL_X0 + 2*6*BAL_S, BAL_Y0, "L", BAL_S);
    wire b_A2= text_px(x,y, BAL_X0 + 3*6*BAL_S, BAL_Y0, "A", BAL_S);
    wire b_N = text_px(x,y, BAL_X0 + 4*6*BAL_S, BAL_Y0, "N", BAL_S);
    wire b_C = text_px(x,y, BAL_X0 + 5*6*BAL_S, BAL_Y0, "C", BAL_S);
    wire b_E = text_px(x,y, BAL_X0 + 6*6*BAL_S, BAL_Y0, "E", BAL_S);
    wire b_colon = text_px(x,y, BAL_X0 + 7*6*BAL_S, BAL_Y0, ":", BAL_S);
    wire b_dol = text_px(x,y, BAL_X0 + 9*6*BAL_S, BAL_Y0, "$", BAL_S);
    // Number: change digits here later as needed
    localparam [7:0] BAL_D0 = "1";
    localparam [7:0] BAL_D1 = "1";
    localparam [7:0] BAL_D2 = "0";
    localparam [7:0] BAL_D3 = "0";
    wire b_n0 = text_px(x,y, BAL_X0 +10*6*BAL_S, BAL_Y0, BAL_D0, BAL_S);
    wire b_n1 = text_px(x,y, BAL_X0 +11*6*BAL_S, BAL_Y0, BAL_D1, BAL_S);
    wire b_n2 = text_px(x,y, BAL_X0 +12*6*BAL_S, BAL_Y0, BAL_D2, BAL_S);
    wire b_n3 = text_px(x,y, BAL_X0 +13*6*BAL_S, BAL_Y0, BAL_D3, BAL_S);

    wire balance_text = b_B|b_A|b_L|b_A2|b_N|b_C|b_E|b_colon|b_dol|b_n0|b_n1|b_n2|b_n3;

    // -------------------------
    // Digits inside each card (move with card)
    // -------------------------
    localparam DIG_S   = 2;
    localparam [9:0] INSET_X = 12, INSET_Y = 10;

    // Example digits (change freely)
    localparam [7:0] D0 = "2"; // dealer left
    localparam [7:0] D1 = "6"; // dealer right
    localparam [7:0] P0 = "8"; // player left
    localparam [7:0] P1 = "9"; // player right

    wire d0_digit = text_px(x,y, D_X0+INSET_X, D_Y+INSET_Y, D0, DIG_S);
    wire d1_digit = text_px(x,y, D_X1+INSET_X, D_Y+INSET_Y, D1, DIG_S);
    wire p0_digit = text_px(x,y, P_X0+INSET_X, P_Y+INSET_Y, P0, DIG_S);
    wire p1_digit = text_px(x,y, P_X1+INSET_X, P_Y+INSET_Y, P1, DIG_S);

    // -------------------------
    // Painter's algorithm
    // -------------------------
    reg [1:0] R,G,B;
    always @* begin
        // background felt
        R=C0; G=G_DARK; B=C0;

        // deck back layer (slight shadow - gray)
        if (deck_back) begin R=C1; G=C1; B=C1; end

        // deck white fill
        if (deck_fill) begin R=C2; G=C2; B=C2; end

        // deck checker pattern (red) inside border
        if (deck_checker) begin R=2'b11; G=2'b00; B=2'b00; end

        // deck border (black)
        if (deck_brd) begin R=C0; G=C0; B=C0; end

        // cards fill
        if (d0_fill || d1_fill || p0_fill || p1_fill) begin R=C2; G=C2; B=C2; end
        // cards border
        if (d0_brd  || d1_brd  || p0_brd  || p1_brd ) begin R=C0; G=C0; B=C0; end

        // digits on cards (black)
        if (d0_digit || d1_digit || p0_digit || p1_digit) begin R=C0; G=C0; B=C0; end

        // center "BLACKJACK" (light gray)
        if (blackjack_text) begin R=C1; G=C1; B=C1; end

        // balance label overrides with bright red
        if (balance_text) begin R=2'b11; G=2'b00; B=2'b00; end

        // outside active area
        if (!active) begin R=C0; G=C0; B=C0; end
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
