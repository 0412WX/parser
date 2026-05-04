module parser_stage_fifo #(
    parameter SLOT_WIDTH = 4,
    parameter ISSUE_WIDTH = 8,
    parameter DEPTH = 16
)(
    input                         clk,
    input                         rst_n,
    input                         wr_en,
    input      [SLOT_WIDTH-1:0]   wr_slot_id,
    input      [ISSUE_WIDTH-1:0]  wr_issue_id,
    input                         rd_en,
    output                        full,
    output                        empty,
    output     [SLOT_WIDTH-1:0]   head_slot_id,
    output     [ISSUE_WIDTH-1:0]  head_issue_id
);

function integer clog2;
    input integer value;
    integer tmp;
    begin
        tmp = value - 1;
        clog2 = 0;
        while (tmp > 0) begin
            clog2 = clog2 + 1;
            tmp = tmp >> 1;
        end
        if (clog2 == 0) begin
            clog2 = 1;
        end
    end
endfunction

localparam integer PTR_WIDTH = clog2(DEPTH);

reg [SLOT_WIDTH-1:0]  slot_mem [0:DEPTH-1];
reg [ISSUE_WIDTH-1:0] issue_mem [0:DEPTH-1];
reg [PTR_WIDTH-1:0]   wr_ptr_r;
reg [PTR_WIDTH-1:0]   rd_ptr_r;
reg [PTR_WIDTH:0]     count_r;

integer idx;

assign full = (count_r == DEPTH);
assign empty = (count_r == 0);
assign head_slot_id = empty ? {SLOT_WIDTH{1'b0}} : slot_mem[rd_ptr_r];
assign head_issue_id = empty ? {ISSUE_WIDTH{1'b0}} : issue_mem[rd_ptr_r];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_ptr_r <= {PTR_WIDTH{1'b0}};
        rd_ptr_r <= {PTR_WIDTH{1'b0}};
        count_r <= {(PTR_WIDTH+1){1'b0}};
        for (idx = 0; idx < DEPTH; idx = idx + 1) begin
            slot_mem[idx] <= {SLOT_WIDTH{1'b0}};
            issue_mem[idx] <= {ISSUE_WIDTH{1'b0}};
        end
    end else begin
        if (wr_en && !full) begin
            slot_mem[wr_ptr_r] <= wr_slot_id;
            issue_mem[wr_ptr_r] <= wr_issue_id;
            if (wr_ptr_r == DEPTH-1) begin
                wr_ptr_r <= {PTR_WIDTH{1'b0}};
            end else begin
                wr_ptr_r <= wr_ptr_r + 1'b1;
            end
        end

        if (rd_en && !empty) begin
            if (rd_ptr_r == DEPTH-1) begin
                rd_ptr_r <= {PTR_WIDTH{1'b0}};
            end else begin
                rd_ptr_r <= rd_ptr_r + 1'b1;
            end
        end

        case ({wr_en && !full, rd_en && !empty})
            2'b10: count_r <= count_r + 1'b1;
            2'b01: count_r <= count_r - 1'b1;
            default: count_r <= count_r;
        endcase
    end
end

endmodule
