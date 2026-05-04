`timescale 1ns/1ps

module pparser_hw_static (
    input  wire          clk,
    input  wire          rst,
    input  wire          in_valid,
    output wire          in_ready,
    input  wire [2047:0] in_header,
    output wire          out_valid,
    input  wire          out_ready,
    output wire [3:0]    out_path_id,
    output wire          out_error,
    output wire [511:0]  out_phv
);
    localparam PATH_ERROR = 4'hF;
    localparam HEADER_BUFFER_DEPTH = 32;
    localparam SLOT_W = 5;
    localparam TENANT_W = 12;
    localparam ACTION_DESC_COUNT = 26;
    localparam ACTION_DESC_W = 9;

    localparam [16*11-1:0] STAGE0_DESC_FLAT = {
        8'd12, 3'd0, 8'd12, 3'd1, 8'd12, 3'd2, 8'd12, 3'd3,
        8'd12, 3'd4, 8'd12, 3'd5, 8'd12, 3'd6, 8'd12, 3'd7,
        8'd13, 3'd0, 8'd13, 3'd1, 8'd13, 3'd2, 8'd13, 3'd3,
        8'd13, 3'd4, 8'd13, 3'd5, 8'd13, 3'd6, 8'd13, 3'd7
    };

    localparam [32*11-1:0] STAGE1_DESC_FLAT = {
        8'd18, 3'd0, 8'd18, 3'd1, 8'd18, 3'd2, 8'd18, 3'd3,
        8'd18, 3'd4, 8'd18, 3'd5, 8'd18, 3'd6, 8'd18, 3'd7,
        8'd19, 3'd0, 8'd19, 3'd1, 8'd19, 3'd2, 8'd19, 3'd3,
        8'd19, 3'd4, 8'd19, 3'd5, 8'd19, 3'd6, 8'd19, 3'd7,
        8'd22, 3'd0, 8'd22, 3'd1, 8'd22, 3'd2, 8'd22, 3'd3,
        8'd22, 3'd4, 8'd22, 3'd5, 8'd22, 3'd6, 8'd22, 3'd7,
        8'd23, 3'd0, 8'd23, 3'd1, 8'd23, 3'd2, 8'd23, 3'd3,
        8'd23, 3'd4, 8'd23, 3'd5, 8'd23, 3'd6, 8'd23, 3'd7
    };

    reg [SLOT_W-1:0] header_wr_ptr;
    reg [SLOT_W-1:0] header_rd_ptr;
    reg [5:0]        header_count;

    reg              s0_valid;
    reg [SLOT_W-1:0] s0_slot;
    reg [15:0]       s0_stage0_key;

    reg              s1_valid;
    reg [SLOT_W-1:0] s1_slot;
    reg [15:0]       s1_stage0_key;

    reg              s2_valid;
    reg [SLOT_W-1:0] s2_slot;

    reg              s3_valid;
    reg [SLOT_W-1:0] s3_slot;
    reg              s3_stage0_hit;
    reg [1:0]        s3_stage0_addr;

    reg              s4_valid;
    reg [SLOT_W-1:0] s4_slot;
    reg              s4_stage0_hit;
    reg [1:0]        s4_stage0_addr;
    reg [31:0]       s4_stage1_key;

    reg              s5_valid;
    reg [SLOT_W-1:0] s5_slot;
    reg              s5_stage0_hit;
    reg [1:0]        s5_stage0_addr;

    reg              s6_valid;
    reg [SLOT_W-1:0] s6_slot;
    reg              s6_stage0_hit;
    reg [1:0]        s6_stage0_addr;
    reg              s6_stage1_hit;
    reg [2:0]        s6_stage1_addr;

    reg              s7_valid;
    reg [SLOT_W-1:0] s7_slot;
    reg [3:0]        s7_path_id;
    reg              s7_error;

    reg              s8_valid;
    reg [511:0]      s8_phv;
    reg [3:0]        s8_path_id;
    reg              s8_error;

    wire                                    s8_ready;
    wire                                    s7_ready;
    wire                                    s6_ready;
    wire                                    s5_ready;
    wire                                    s4_ready;
    wire                                    s3_ready;
    wire                                    s2_ready;
    wire                                    s1_ready;
    wire                                    output_pop;
    wire                                    header_space_available;
    wire                                    s0_ready;
    wire                                    stage0_hit_comb;
    wire [1:0]                              stage0_addr_comb;
    wire                                    stage0_table_ready;
    wire                                    terminal_after_stage0_unused;
    wire                                    stage1_hit_comb;
    wire [2:0]                              stage1_addr_comb;
    wire                                    stage1_table_ready;
    wire [3:0]                              resolved_path_comb;
    wire                                    resolved_error_comb;
    wire [ACTION_DESC_COUNT*ACTION_DESC_W-1:0] action_descs_comb;
    wire [511:0]                            s7_phv_comb;
    wire [15:0]                             stage0_key_from_input;
    wire [31:0]                             stage1_key_from_bram;
    wire [TENANT_W-1:0]                     tenant_id_comb;
    wire                                    tables_ready;
    wire [2047:0]                           stage1_header_rd_data;
    wire [2047:0]                           phv_header_rd_data;

    assign tenant_id_comb = {TENANT_W{1'b0}};
    assign tables_ready = stage0_table_ready & stage1_table_ready;

    pparser_key_extractor #(
        .HEADER_W(2048),
        .OUTPUT_W(16)
    ) u_stage0_key_extractor (
        .header(in_header),
        .descs_flat(STAGE0_DESC_FLAT),
        .key_bits(stage0_key_from_input)
    );

    pparser_header_bram #(
        .DATA_W(2048),
        .DEPTH(HEADER_BUFFER_DEPTH),
        .ADDR_W(SLOT_W)
    ) u_stage1_header_bram (
        .clk(clk),
        .wr_en(s0_ready & in_valid),
        .wr_addr(header_wr_ptr),
        .wr_data(in_header),
        .rd_en(s1_valid),
        .rd_addr(s1_slot),
        .rd_data(stage1_header_rd_data)
    );

    pparser_header_bram #(
        .DATA_W(2048),
        .DEPTH(HEADER_BUFFER_DEPTH),
        .ADDR_W(SLOT_W)
    ) u_phv_header_bram (
        .clk(clk),
        .wr_en(s0_ready & in_valid),
        .wr_addr(header_wr_ptr),
        .wr_data(in_header),
        .rd_en(s6_valid),
        .rd_addr(s6_slot),
        .rd_data(phv_header_rd_data)
    );

    pparser_key_extractor #(
        .HEADER_W(2048),
        .OUTPUT_W(32)
    ) u_stage1_key_extractor (
        .header(stage1_header_rd_data),
        .descs_flat(STAGE1_DESC_FLAT),
        .key_bits(stage1_key_from_bram)
    );

    pparser_stage0_tcam u_stage0_tcam (
        .clk(clk),
        .rst(rst),
        .key(s1_stage0_key),
        .ready(stage0_table_ready),
        .hit(stage0_hit_comb),
        .addr(stage0_addr_comb),
        .terminal_after_stage0(terminal_after_stage0_unused)
    );

    pparser_stage1_tcam u_stage1_tcam (
        .clk(clk),
        .rst(rst),
        .key(s4_stage1_key),
        .ready(stage1_table_ready),
        .hit(stage1_hit_comb),
        .addr(stage1_addr_comb)
    );

    pparser_final_resolver u_final_resolver (
        .stage0_hit(s6_stage0_hit),
        .stage0_addr(s6_stage0_addr),
        .stage1_hit(s6_stage1_hit),
        .stage1_addr(s6_stage1_addr),
        .path_id(resolved_path_comb),
        .error(resolved_error_comb)
    );

    pparser_action_table #(
        .DESC_COUNT(ACTION_DESC_COUNT),
        .DESC_W(ACTION_DESC_W),
        .TENANT_W(TENANT_W)
    ) u_action_table (
        .tenant_id(tenant_id_comb),
        .path_id(s7_path_id),
        .action_descs(action_descs_comb)
    );

    pparser_phv_builder u_phv_builder (
        .header(phv_header_rd_data),
        .action_descs(action_descs_comb),
        .path_id(s7_path_id),
        .error(s7_error),
        .phv(s7_phv_comb)
    );

    assign s8_ready = out_ready | ~s8_valid;
    assign s7_ready = ~s7_valid | s8_ready;
    assign s6_ready = ~s6_valid | s7_ready;
    assign s5_ready = ~s5_valid | s6_ready;
    assign s4_ready = ~s4_valid | s5_ready;
    assign s3_ready = ~s3_valid | s4_ready;
    assign s2_ready = ~s2_valid | s3_ready;
    assign s1_ready = ~s1_valid | s2_ready;

    assign output_pop = s8_valid & s8_ready;
    assign header_space_available = (header_count < HEADER_BUFFER_DEPTH) | output_pop;
    assign s0_ready = (~s0_valid | s1_ready) & header_space_available & tables_ready;

    assign in_ready = s0_ready;
    assign out_valid = s8_valid;
    assign out_path_id = s8_path_id;
    assign out_error = s8_error;
    assign out_phv = s8_phv;

    always @(posedge clk) begin
        if (rst) begin
            header_wr_ptr <= {SLOT_W{1'b0}};
            header_rd_ptr <= {SLOT_W{1'b0}};
            header_count <= 6'd0;

            s0_valid <= 1'b0;
            s1_valid <= 1'b0;
            s2_valid <= 1'b0;
            s3_valid <= 1'b0;
            s4_valid <= 1'b0;
            s5_valid <= 1'b0;
            s6_valid <= 1'b0;
            s7_valid <= 1'b0;
            s8_valid <= 1'b0;
            s8_path_id <= PATH_ERROR;
            s8_error <= 1'b0;
            s8_phv <= {512{1'b0}};
        end else begin
            if (s8_ready) begin
                s8_valid <= s7_valid;
                if (s7_valid) begin
                    s8_path_id <= s7_path_id;
                    s8_error <= s7_error;
                    s8_phv <= s7_phv_comb;
                end
            end

            if (s7_ready) begin
                s7_valid <= s6_valid;
                if (s6_valid) begin
                    s7_slot <= s6_slot;
                    s7_path_id <= resolved_path_comb;
                    s7_error <= resolved_error_comb;
                end
            end

            if (s6_ready) begin
                s6_valid <= s5_valid;
                if (s5_valid) begin
                    s6_slot <= s5_slot;
                    s6_stage0_hit <= s5_stage0_hit;
                    s6_stage0_addr <= s5_stage0_addr;
                    s6_stage1_hit <= stage1_hit_comb;
                    s6_stage1_addr <= stage1_addr_comb;
                end
            end

            if (s5_ready) begin
                s5_valid <= s4_valid;
                if (s4_valid) begin
                    s5_slot <= s4_slot;
                    s5_stage0_hit <= s4_stage0_hit;
                    s5_stage0_addr <= s4_stage0_addr;
                end
            end

            if (s4_ready) begin
                s4_valid <= s3_valid;
                if (s3_valid) begin
                    s4_slot <= s3_slot;
                    s4_stage0_hit <= s3_stage0_hit;
                    s4_stage0_addr <= s3_stage0_addr;
                    s4_stage1_key <= stage1_key_from_bram;
                end
            end

            if (s3_ready) begin
                s3_valid <= s2_valid;
                if (s2_valid) begin
                    s3_slot <= s2_slot;
                    s3_stage0_hit <= stage0_hit_comb;
                    s3_stage0_addr <= stage0_addr_comb;
                end
            end

            if (s2_ready) begin
                s2_valid <= s1_valid;
                if (s1_valid) begin
                    s2_slot <= s1_slot;
                end
            end

            if (s1_ready) begin
                s1_valid <= s0_valid;
                if (s0_valid) begin
                    s1_slot <= s0_slot;
                    s1_stage0_key <= s0_stage0_key;
                end
            end

            if (s0_ready) begin
                s0_valid <= in_valid;
                if (in_valid) begin
                    s0_slot <= header_wr_ptr;
                    s0_stage0_key <= stage0_key_from_input;
                end
            end

            case ({(s0_ready & in_valid), output_pop})
                2'b10: begin
                    header_wr_ptr <= header_wr_ptr + 1'b1;
                    header_count <= header_count + 1'b1;
                end
                2'b01: begin
                    header_rd_ptr <= header_rd_ptr + 1'b1;
                    header_count <= header_count - 1'b1;
                end
                2'b11: begin
                    header_wr_ptr <= header_wr_ptr + 1'b1;
                    header_rd_ptr <= header_rd_ptr + 1'b1;
                end
                default: begin
                end
            endcase
        end
    end
endmodule
