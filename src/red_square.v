module red_square (
    input  wire clk_25MHz,
    input  wire rst_n,
    output wire vga_hsync,
    output wire vga_vsync,
    output reg  [1:0] vga_r,
    output reg  [1:0] vga_g,
    output reg  [1:0] vga_b
);

    wire [9:0] x_count;
    wire [9:0] y_count;

    // VGA timing generator
    vga_controller vga_ctrl (
        .pixel_clk(clk_25MHz),
        .rst_n(rst_n),
        .hsync(vga_hsync),
        .vsync(vga_vsync),
        .x_count(x_count),
        .y_count(y_count)
    );

    // Define square area (100x100 centered)
    wire square_active = (x_count >= 270 && x_count < 370) &&
                         (y_count >= 190 && y_count < 290);

    // Color selection
    wire [1:0] vga_r_data = square_active ? 2'b11 : 2'b00;
    wire [1:0] vga_g_data = 2'b00;
    wire [1:0] vga_b_data = 2'b00;

    // Sync output to pixel clock
    always @(posedge clk_25MHz or negedge rst_n) begin
        if (!rst_n) begin
            vga_r <= 2'b00;
            vga_g <= 2'b00;
            vga_b <= 2'b00;
        end else begin
            vga_r <= vga_r_data;
            vga_g <= vga_g_data;
            vga_b <= vga_b_data;
        end
    end

endmodule
