module vga_controller (
	pixel_clk,
	rst_n,
	hsync,
	vsync,
	x_count,
	y_count
);

	input wire pixel_clk;
	input wire rst_n;

	output wire hsync;
	output wire vsync;
	output reg [9:0] x_count;
	output reg [9:0] y_count;

	// VGA timing parameters
	localparam H_ACTIVE = 640;
    localparam H_FRONT_PORCH = 16;
    localparam H_SYNC = 96;
    localparam H_BACK_PORCH = 48;
    localparam H_TOTAL = H_ACTIVE + H_FRONT_PORCH + H_SYNC + H_BACK_PORCH;

    localparam V_ACTIVE = 480;
    localparam V_FRONT_PORCH = 10;
    localparam V_SYNC = 2;
    localparam V_BACK_PORCH = 33;
    localparam V_TOTAL = V_ACTIVE + V_FRONT_PORCH + V_SYNC + V_BACK_PORCH;


	always @(posedge pixel_clk or negedge rst_n)
	begin
		if (!rst_n) begin
			x_count <= 10'd0;
			y_count <= 10'd0;
		end
		else if (x_count == H_TOTAL - 1) begin
			x_count <= 10'd0;
			if (y_count == V_TOTAL - 1)
				y_count <= 10'd0;
			else
				y_count <= y_count + 10'b0000000001;
		end
		else
			x_count <= x_count + 10'b0000000001;
	end

	// Generate hsync and vsync
    assign hsync = (x_count >= H_ACTIVE + H_FRONT_PORCH) &&
                   (x_count < H_ACTIVE + H_FRONT_PORCH + H_SYNC);
    assign vsync = (y_count >= V_ACTIVE + V_FRONT_PORCH) &&
                   (y_count < V_ACTIVE + V_FRONT_PORCH + V_SYNC);

endmodule