// ============================================================================
// balance_digits
// Draws 4 decimal digits of user_balance next to "BALANCE: $".
// Uses the same spacing as your original 1100 block.
//
// Parameters BAL_S, BAL_X0, BAL_Y0 must match blackjack_table.
// ============================================================================
module balance_digits #(
    parameter BAL_S  = 2,
    parameter BAL_X0 = 40,
    parameter BAL_Y0 = 240
)(
    input  wire [9:0] x,
    input  wire [9:0] y,
    input  wire [9:0] balance,   // binary balance, default 500 in top
    output wire       on         // 1 if any digit pixel is on
);
    // Clamp to 0..999 (fits 3 digits; leftmost 4th digit kept blank)
    wire [9:0] bal_clamped = (balance > 10'd999) ? 10'd999 : balance;

    // Simple binary -> BCD (using / and % by constants)
    wire [3:0] hundreds = (bal_clamped / 100) % 10;
    wire [3:0] tens     = (bal_clamped / 10 ) % 10;
    wire [3:0] ones     =  bal_clamped        % 10;

    // 4-digit layout: [d3][d2][d1][d0]
    // we'll leave d3 blank (0) for 0..999
    wire [3:0] d3 = 4'd0;
    wire [3:0] d2 = hundreds;
    wire [3:0] d1 = tens;
    wire [3:0] d0 = ones;

    // ------------------------------------------------------------------------
    // For each digit: compute local coords, run through digit5x7_dec
    // Positions are exactly like your original:
    // '1' at BAL_X0 + 10*6*BAL_S
    // second '1' at BAL_X0 + 11*6*BAL_S
    // '0'        at BAL_X0 + 12*6*BAL_S
    // second '0' at BAL_X0 + 13*6*BAL_S
    // ------------------------------------------------------------------------
    // d3 at BAL_X0 + 10*6*BAL_S  (left-most)
    wire signed [10:0] d3_lx = $signed({1'b0,x}) - $signed(BAL_X0 + 10*6*BAL_S);
    wire signed [10:0] d3_ly = $signed({1'b0,y}) - $signed(BAL_Y0);
    wire        d3_in  = (d3_lx >= 0) && (d3_lx < 5*BAL_S) &&
                         (d3_ly >= 0) && (d3_ly < 7*BAL_S);
    wire [2:0]  d3_col = d3_lx[10:0] / BAL_S;
    wire [2:0]  d3_row = d3_ly[10:0] / BAL_S;
    wire        d3_pix;
    digit5x7_dec d3_digit (
        .val(d3),
        .col(d3_col),
        .row(d3_row),
        .on (d3_pix)
    );
    wire d3_on = d3_in && d3_pix;

    // d2 at BAL_X0 + 11*6*BAL_S
    wire signed [10:0] d2_lx = $signed({1'b0,x}) - $signed(BAL_X0 + 11*6*BAL_S);
    wire signed [10:0] d2_ly = $signed({1'b0,y}) - $signed(BAL_Y0);
    wire        d2_in  = (d2_lx >= 0) && (d2_lx < 5*BAL_S) &&
                         (d2_ly >= 0) && (d2_ly < 7*BAL_S);
    wire [2:0]  d2_col = d2_lx[10:0] / BAL_S;
    wire [2:0]  d2_row = d2_ly[10:0] / BAL_S;
    wire        d2_pix;
    digit5x7_dec d2_digit (
        .val(d2),
        .col(d2_col),
        .row(d2_row),
        .on (d2_pix)
    );
    wire d2_on = d2_in && d2_pix;

    // d1 at BAL_X0 + 12*6*BAL_S
    wire signed [10:0] d1_lx = $signed({1'b0,x}) - $signed(BAL_X0 + 12*6*BAL_S);
    wire signed [10:0] d1_ly = $signed({1'b0,y}) - $signed(BAL_Y0);
    wire        d1_in  = (d1_lx >= 0) && (d1_lx < 5*BAL_S) &&
                         (d1_ly >= 0) && (d1_ly < 7*BAL_S);
    wire [2:0]  d1_col = d1_lx[10:0] / BAL_S;
    wire [2:0]  d1_row = d1_ly[10:0] / BAL_S;
    wire        d1_pix;
    digit5x7_dec d1_digit (
        .val(d1),
        .col(d1_col),
        .row(d1_row),
        .on (d1_pix)
    );
    wire d1_on = d1_in && d1_pix;

    // d0 at BAL_X0 + 13*6*BAL_S (right-most)
    wire signed [10:0] d0_lx = $signed({1'b0,x}) - $signed(BAL_X0 + 13*6*BAL_S);
    wire signed [10:0] d0_ly = $signed({1'b0,y}) - $signed(BAL_Y0);
    wire        d0_in  = (d0_lx >= 0) && (d0_lx < 5*BAL_S) &&
                         (d0_ly >= 0) && (d0_ly < 7*BAL_S);
    wire [2:0]  d0_col = d0_lx[10:0] / BAL_S;
    wire [2:0]  d0_row = d0_ly[10:0] / BAL_S;
    wire        d0_pix;
    digit5x7_dec d0_digit (
        .val(d0),
        .col(d0_col),
        .row(d0_row),
        .on (d0_pix)
    );
    wire d0_on = d0_in && d0_pix;

    assign on = d3_on | d2_on | d1_on | d0_on;

endmodule
