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