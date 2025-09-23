module pwrup_synchronizer (
    input wire clk_in,
    input wire rst_n,
    output wire clk_in_rst_n_sync
);

reg rst_n_sync_0;
reg rst_n_sync_1;

assign clk_in_rst_n_sync = rst_n_sync_1;

always @(posedge clk_in or negedge rst_n)
begin
    if (!rst_n)
    begin
        rst_n_sync_0 <= 1'b0;
        rst_n_sync_1 <= 1'b0;
    end else
    begin
        rst_n_sync_0 <= 1'b1;
        rst_n_sync_1 <= rst_n_sync_0;
    end
end

endmodule