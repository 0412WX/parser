`timescale 1ns/1ps

module pparser_stage1_cam_core (
    input  wire        clk,
    input  wire        rst,
    input  wire [32:0] cmp_din,
    output wire        ready,
    output wire        match,
    output wire [3:0]  match_addr
);
    localparam INIT_PULSE        = 2'd0;
    localparam INIT_WAIT_BUSY_HI = 2'd1;
    localparam INIT_WAIT_BUSY_LO = 2'd2;
    localparam RUN               = 2'd3;

    reg [1:0]  state_r = INIT_PULSE;
    reg [3:0]  init_index_r = 4'd0;
    reg        we_r = 1'b0;
    reg        ready_r = 1'b0;
    wire       busy_w;
    wire       match_w;
    wire [3:0] match_addr_w;
    reg [32:0] cam_data_init [0:15];
    reg [32:0] cam_mask_init [0:15];

    initial begin
        $readmemb("pparser_stage1_cam_data.mif", cam_data_init);
        $readmemb("pparser_stage1_cam_mask.mif", cam_mask_init);
    end

    cam_top #(
        .C_ADDR_TYPE(0),
        .C_DEPTH(16),
        .C_FAMILY("virtex6"),
        .C_HAS_CMP_DIN(1),
        .C_HAS_EN(1),
        .C_HAS_MULTIPLE_MATCH(0),
        .C_HAS_READ_WARNING(0),
        .C_HAS_SINGLE_MATCH(0),
        .C_HAS_WE(1),
        .C_MATCH_RESOLUTION_TYPE(0),
        .C_MEM_INIT(0),
        .C_MEM_INIT_FILE(""),
        .C_MEM_TYPE(0),
        .C_REG_OUTPUTS(0),
        .C_TERNARY_MODE(1),
        .C_WIDTH(33)
    ) stage1_cam_i (
        .CLK(clk),
        .CMP_DATA_MASK({33{1'b0}}),
        .CMP_DIN(cmp_din),
        .DATA_MASK(cam_mask_init[init_index_r]),
        .DIN(cam_data_init[init_index_r]),
        .EN(1'b1),
        .WE(we_r),
        .WR_ADDR(init_index_r),
        .BUSY(busy_w),
        .MATCH(match_w),
        .MATCH_ADDR(match_addr_w),
        .MULTIPLE_MATCH(),
        .READ_WARNING(),
        .SINGLE_MATCH()
    );

    always @(posedge clk) begin
        if (rst) begin
            state_r <= INIT_PULSE;
            init_index_r <= 4'd0;
            we_r <= 1'b0;
            ready_r <= 1'b0;
        end else begin
            case (state_r)
                INIT_PULSE: begin
                    we_r <= 1'b1;
                    ready_r <= 1'b0;
                    state_r <= INIT_WAIT_BUSY_HI;
                end
                INIT_WAIT_BUSY_HI: begin
                    we_r <= 1'b0;
                    if (busy_w) begin
                        state_r <= INIT_WAIT_BUSY_LO;
                    end
                end
                INIT_WAIT_BUSY_LO: begin
                    if (!busy_w) begin
                        if (init_index_r == 4'd6) begin
                            state_r <= RUN;
                            ready_r <= 1'b1;
                        end else begin
                            init_index_r <= init_index_r + 1'b1;
                            state_r <= INIT_PULSE;
                        end
                    end
                end
                default: begin
                    we_r <= 1'b0;
                    ready_r <= 1'b1;
                end
            endcase
        end
    end

    assign ready = ready_r;
    assign match = match_w;
    assign match_addr = match_addr_w;
endmodule
