`timescale 1ns / 1ps

module parser_slot_store #(
    parameter HEADER_BITS = 1024,
    parameter PKT_HDR_LEN = 1124,
    parameter SLOT_COUNT = 16,
    parameter SLOT_WIDTH = 4,
    parameter C_S_AXIS_DATA_WIDTH = 512,
    parameter SUBGRAPH_COUNT = 4
)(
    input                                      axis_clk,
    input                                      aresetn,

    input                                      capture_init_en,
    input      [SLOT_WIDTH-1:0]                capture_init_slot_id,
    input      [C_S_AXIS_DATA_WIDTH-1:0]       capture_init_data,

    input                                      capture_write_en,
    input      [SLOT_WIDTH-1:0]                capture_write_slot_id,
    input      [7:0]                           capture_write_beat_index,
    input      [C_S_AXIS_DATA_WIDTH-1:0]       capture_write_data,

    input                                      ctx_clear_en,
    input      [SLOT_WIDTH-1:0]                ctx_clear_slot_id,

    input                                      ctx_set_subgraph_en,
    input      [SLOT_WIDTH-1:0]                ctx_set_subgraph_slot_id,
    input      [1:0]                           ctx_set_subgraph_id,

    input      [SUBGRAPH_COUNT-1:0]            subgraph_goto_en_flat,
    input      [SUBGRAPH_COUNT*SLOT_WIDTH-1:0] subgraph_goto_slot_flat,
    input      [SUBGRAPH_COUNT*2-1:0]          subgraph_goto_id_flat,
    input      [SUBGRAPH_COUNT*8-1:0]          subgraph_goto_partial_ctx_flat,
    input      [SUBGRAPH_COUNT-1:0]            subgraph_goto_continue_flat,
    input      [SUBGRAPH_COUNT*2-1:0]          subgraph_goto_cascade_flat,

    input      [SUBGRAPH_COUNT-1:0]            subgraph_build_en_flat,
    input      [SUBGRAPH_COUNT*SLOT_WIDTH-1:0] subgraph_build_slot_flat,
    input      [SUBGRAPH_COUNT-1:0]            subgraph_build_path_valid_flat,
    input      [SUBGRAPH_COUNT*4-1:0]          subgraph_build_path_id_flat,
    input      [SUBGRAPH_COUNT*4-1:0]          subgraph_build_extract_profile_flat,
    input      [SUBGRAPH_COUNT*4-1:0]          subgraph_build_deparse_profile_flat,
    input      [SUBGRAPH_COUNT*8-1:0]          subgraph_build_partial_ctx_flat,
    input      [SUBGRAPH_COUNT-1:0]            subgraph_build_continue_flat,

    input                                      phv_write_en,
    input      [SLOT_WIDTH-1:0]                phv_write_slot_id,
    input      [PKT_HDR_LEN-1:0]               phv_write_data,

    input      [SLOT_WIDTH-1:0]                preprocess_slot_id,
    output     [HEADER_BITS-1:0]               preprocess_header_window,

    input      [SUBGRAPH_COUNT*SLOT_WIDTH-1:0] subgraph_slot_ids_flat,
    output     [SUBGRAPH_COUNT*HEADER_BITS-1:0] subgraph_header_windows_flat,
    output     [SUBGRAPH_COUNT*2-1:0]          subgraph_cascade_depths_flat,

    input      [SLOT_WIDTH-1:0]                build_slot_id,
    output     [HEADER_BITS-1:0]               build_header_window,
    output                                     build_path_valid,
    output     [3:0]                           build_path_id,
    output                                     build_continue_flag,
    output     [7:0]                           build_partial_ctx,
    output     [3:0]                           build_deparse_profile_id,
    output     [3:0]                           build_extract_profile_id
);

reg [HEADER_BITS-1:0] header_mem [0:SLOT_COUNT-1];
reg [1:0]             current_subgraph_mem [0:SLOT_COUNT-1];
reg                   path_valid_mem [0:SLOT_COUNT-1];
reg [3:0]             path_id_mem [0:SLOT_COUNT-1];
reg [3:0]             extract_profile_mem [0:SLOT_COUNT-1];
reg [3:0]             deparse_profile_mem [0:SLOT_COUNT-1];
reg [7:0]             partial_ctx_mem [0:SLOT_COUNT-1];
reg                   continue_flag_mem [0:SLOT_COUNT-1];
reg [1:0]             cascade_depth_mem [0:SLOT_COUNT-1];
reg [PKT_HDR_LEN-1:0] phv_mem [0:SLOT_COUNT-1];

integer idx;
integer lane_idx;
genvar gi;

assign preprocess_header_window = header_mem[preprocess_slot_id];
assign build_header_window = header_mem[build_slot_id];
assign build_path_valid = path_valid_mem[build_slot_id];
assign build_path_id = path_id_mem[build_slot_id];
assign build_continue_flag = continue_flag_mem[build_slot_id];
assign build_partial_ctx = partial_ctx_mem[build_slot_id];
assign build_deparse_profile_id = deparse_profile_mem[build_slot_id];
assign build_extract_profile_id = extract_profile_mem[build_slot_id];

generate
    for (gi = 0; gi < SUBGRAPH_COUNT; gi = gi + 1) begin : g_subgraph_reads
        wire [SLOT_WIDTH-1:0] subgraph_slot_id_w;
        assign subgraph_slot_id_w = subgraph_slot_ids_flat[gi*SLOT_WIDTH +: SLOT_WIDTH];
        assign subgraph_header_windows_flat[gi*HEADER_BITS +: HEADER_BITS] = header_mem[subgraph_slot_id_w];
        assign subgraph_cascade_depths_flat[gi*2 +: 2] = cascade_depth_mem[subgraph_slot_id_w];
    end
endgenerate

always @(posedge axis_clk or negedge aresetn) begin
    if (!aresetn) begin
        for (idx = 0; idx < SLOT_COUNT; idx = idx + 1) begin
            header_mem[idx] <= {HEADER_BITS{1'b0}};
            current_subgraph_mem[idx] <= 2'd0;
            path_valid_mem[idx] <= 1'b0;
            path_id_mem[idx] <= 4'd0;
            extract_profile_mem[idx] <= 4'd0;
            deparse_profile_mem[idx] <= 4'd0;
            partial_ctx_mem[idx] <= 8'd0;
            continue_flag_mem[idx] <= 1'b0;
            cascade_depth_mem[idx] <= 2'd0;
            phv_mem[idx] <= {PKT_HDR_LEN{1'b0}};
        end
    end else begin
        if (capture_init_en) begin
            header_mem[capture_init_slot_id] <= {HEADER_BITS{1'b0}};
            header_mem[capture_init_slot_id][0 +: C_S_AXIS_DATA_WIDTH] <= capture_init_data;
            current_subgraph_mem[capture_init_slot_id] <= 2'd0;
            path_valid_mem[capture_init_slot_id] <= 1'b0;
            path_id_mem[capture_init_slot_id] <= 4'd0;
            extract_profile_mem[capture_init_slot_id] <= 4'd0;
            deparse_profile_mem[capture_init_slot_id] <= 4'd0;
            partial_ctx_mem[capture_init_slot_id] <= 8'd0;
            continue_flag_mem[capture_init_slot_id] <= 1'b0;
            cascade_depth_mem[capture_init_slot_id] <= 2'd0;
            phv_mem[capture_init_slot_id] <= {PKT_HDR_LEN{1'b0}};
        end

        if (capture_write_en) begin
            header_mem[capture_write_slot_id][capture_write_beat_index*C_S_AXIS_DATA_WIDTH +: C_S_AXIS_DATA_WIDTH] <= capture_write_data;
        end

        if (ctx_clear_en) begin
            current_subgraph_mem[ctx_clear_slot_id] <= 2'd0;
            path_valid_mem[ctx_clear_slot_id] <= 1'b0;
            path_id_mem[ctx_clear_slot_id] <= 4'd0;
            extract_profile_mem[ctx_clear_slot_id] <= 4'd0;
            deparse_profile_mem[ctx_clear_slot_id] <= 4'd0;
            partial_ctx_mem[ctx_clear_slot_id] <= 8'd0;
            continue_flag_mem[ctx_clear_slot_id] <= 1'b0;
            cascade_depth_mem[ctx_clear_slot_id] <= 2'd0;
        end

        if (ctx_set_subgraph_en) begin
            current_subgraph_mem[ctx_set_subgraph_slot_id] <= ctx_set_subgraph_id;
        end

        for (lane_idx = 0; lane_idx < SUBGRAPH_COUNT; lane_idx = lane_idx + 1) begin
            if (subgraph_goto_en_flat[lane_idx]) begin
                current_subgraph_mem[subgraph_goto_slot_flat[lane_idx*SLOT_WIDTH +: SLOT_WIDTH]] <= subgraph_goto_id_flat[lane_idx*2 +: 2];
                partial_ctx_mem[subgraph_goto_slot_flat[lane_idx*SLOT_WIDTH +: SLOT_WIDTH]] <= subgraph_goto_partial_ctx_flat[lane_idx*8 +: 8];
                continue_flag_mem[subgraph_goto_slot_flat[lane_idx*SLOT_WIDTH +: SLOT_WIDTH]] <= subgraph_goto_continue_flat[lane_idx];
                cascade_depth_mem[subgraph_goto_slot_flat[lane_idx*SLOT_WIDTH +: SLOT_WIDTH]] <= subgraph_goto_cascade_flat[lane_idx*2 +: 2];
            end

            if (subgraph_build_en_flat[lane_idx]) begin
                path_valid_mem[subgraph_build_slot_flat[lane_idx*SLOT_WIDTH +: SLOT_WIDTH]] <= subgraph_build_path_valid_flat[lane_idx];
                path_id_mem[subgraph_build_slot_flat[lane_idx*SLOT_WIDTH +: SLOT_WIDTH]] <= subgraph_build_path_id_flat[lane_idx*4 +: 4];
                extract_profile_mem[subgraph_build_slot_flat[lane_idx*SLOT_WIDTH +: SLOT_WIDTH]] <= subgraph_build_extract_profile_flat[lane_idx*4 +: 4];
                deparse_profile_mem[subgraph_build_slot_flat[lane_idx*SLOT_WIDTH +: SLOT_WIDTH]] <= subgraph_build_deparse_profile_flat[lane_idx*4 +: 4];
                partial_ctx_mem[subgraph_build_slot_flat[lane_idx*SLOT_WIDTH +: SLOT_WIDTH]] <= subgraph_build_partial_ctx_flat[lane_idx*8 +: 8];
                continue_flag_mem[subgraph_build_slot_flat[lane_idx*SLOT_WIDTH +: SLOT_WIDTH]] <= subgraph_build_continue_flat[lane_idx];
            end
        end

        if (phv_write_en) begin
            phv_mem[phv_write_slot_id] <= phv_write_data;
        end
    end
end

endmodule
