// ============================================================================
// blackjack_table.v  (640x480 @ 25 MHz pixel clock)
// Renders a simple blackjack layout with blank white cards and green felt.
// ----------------------------------------------------------------------------
// Uses: vga_controller (your module below)
// Colors: 2bpp per channel (R,G,B)
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
        .rst_n(rst_n),
        .hsync(vga_hsync),
        .vsync(vga_vsync),
        .x_count(x),
        .y_count(y)
    );

    // Active video region
    wire active = (x < 640) && (y < 480);

    // -------------------------
    // Helpers
    // -------------------------
    // Rectangle test: [x0, x1) x [y0, y1)
    function automatic rect;
        input [9:0] X, Y;
        input [9:0] x0, y0, x1, y1;
        begin
            rect = (X >= x0) && (X < x1) && (Y >= y0) && (Y < y1);
        end
    endfunction

    // Border for a rectangle (1 or 2 pixel thickness)
    function automatic rect_border;
        input [9:0] X, Y;
        input [9:0] x0, y0, x1, y1;
        input [3:0] th; // thickness in pixels
        begin
            rect_border =
                rect(X,Y,x0,y0,x1,y0+th) || // top
                rect(X,Y,x0,y1-th,x1,y1) || // bottom
                rect(X,Y,x0,y0,x0+th,y1) || // left
                rect(X,Y,x1-th,y0,x1,y1);   // right
        end
    endfunction

    // Simple circle (for a faint center chip placeholder; optional)
    function automatic circle;
        input integer X, Y;        // current pixel
        input integer cx, cy;      // center
        input integer r2;          // radius^2
        begin
            integer dx, dy, d2;
            dx = X - cx;
            dy = Y - cy;
            d2 = dx*dx + dy*dy;
            circle = (d2 <= r2);
        end
    endfunction

    // -------------------------
    // Layout constants (tweak as you like)
    // -------------------------
    // Card size and overlap
    localparam CARD_W = 70;
    localparam CARD_H = 100;
    localparam CARD_OV = 16;       // overlap in pixels
    localparam BORDER  = 2;        // card/button border thickness

    // Dealer cards (top center)
    localparam D_Y  = 60;
    localparam D_X0 = 320 - CARD_W - (CARD_OV/2);
    localparam D_X1 = D_X0 + CARD_W - CARD_OV; // second card shifted right

    // Player cards (bottom center)
    localparam P_Y  = 300;
    localparam P_X0 = 320 - CARD_W - (CARD_OV/2);
    localparam P_X1 = P_X0 + CARD_W - CARD_OV;

    // Buttons (approx positions like the screenshot)
    localparam BTN_W = 130;
    localparam BTN_H = 60;
    localparam BTN_Y = 330;
    localparam HIT_X = 80;                 // left button
    localparam STD_X = 640-80-BTN_W;       // right button

    // Optional center chip circle
    localparam CHIP_CX = 320;
    localparam CHIP_CY = 240;
    localparam CHIP_R2 = 45*45;

    // -------------------------
    // Color palette (2 bits per channel)
    // -------------------------
    // Dark felt green
    localparam [1:0] G_DARK = 2'b10;
    // Bright button green
    localparam [1:0] G_BRIGHT = 2'b11;
    // White
    localparam [1:0] C2 = 2'b11;
    // Black
    localparam [1:0] C0 = 2'b00;
    // Mid gray (borders/shadows)
    localparam [1:0] C1 = 2'b01;

    // -------------------------
    // Draw primitives (layered back-to-front)
    // -------------------------
    // Background felt
    wire bg = active; // all active pixels

    // Dealer cards (two overlapped)
    wire d0_fill = rect(x,y, D_X0, D_Y, D_X0+CARD_W, D_Y+CARD_H);
    wire d1_fill = rect(x,y, D_X1, D_Y, D_X1+CARD_W, D_Y+CARD_H);
    wire d0_brd  = rect_border(x,y, D_X0, D_Y, D_X0+CARD_W, D_Y+CARD_H, BORDER);
    wire d1_brd  = rect_border(x,y, D_X1, D_Y, D_X1+CARD_W, D_Y+CARD_H, BORDER);

    // Player cards (two overlapped)
    wire p0_fill = rect(x,y, P_X0, P_Y, P_X0+CARD_W, P_Y+CARD_H);
    wire p1_fill = rect(x,y, P_X1, P_Y, P_X1+CARD_W, P_Y+CARD_H);
    wire p0_brd  = rect_border(x,y, P_X0, P_Y, P_X0+CARD_W, P_Y+CARD_H, BORDER);
    wire p1_brd  = rect_border(x,y, P_X1, P_Y, P_X1+CARD_W, P_Y+CARD_H, BORDER);

    // Buttons
    wire hit_fill = rect(x,y, HIT_X, BTN_Y, HIT_X+BTN_W, BTN_Y+BTN_H);
    wire std_fill = rect(x,y, STD_X, BTN_Y, STD_X+BTN_W, BTN_Y+BTN_H);
    wire hit_brd  = rect_border(x,y, HIT_X, BTN_Y, HIT_X+BTN_W, BTN_Y+BTN_H, BORDER);
    wire std_brd  = rect_border(x,y, STD_X, BTN_Y, STD_X+BTN_W, BTN_Y+BTN_H, BORDER);

    // Optional center chip
    wire chip = circle(x,y, CHIP_CX, CHIP_CY, CHIP_R2) && !circle(x,y, CHIP_CX, CHIP_CY, (45-6)*(45-6));

    // -------------------------
    // Color composition (priority painter's algorithm)
    // -------------------------
    reg [1:0] R, G, B;

    always @* begin
        // Default: background felt
        R = C0;
        G = G_DARK;
        B = C0;

        // Center chip ring (light gray)
        if (chip) begin
            R = C1; G = C1; B = C1;
        end

        // Buttons (bright green)
        if (hit_fill || std_fill) begin
            R = C0; G = G_BRIGHT; B = C0;
        end
        // Button borders
        if (hit_brd || std_brd) begin
            R = C0; G = C0; B = C0;
        end

        // Cards (white fills)
        if (d0_fill || d1_fill || p0_fill || p1_fill) begin
            R = C2; G = C2; B = C2; // white
        end
        // Card borders on top
        if (d0_brd || d1_brd || p0_brd || p1_brd) begin
            R = C0; G = C0; B = C0;
        end

        // Outside active video = black
        if (!active) begin
            R = C0; G = C0; B = C0;
        end
    end

    // Register to the pixel clock
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
