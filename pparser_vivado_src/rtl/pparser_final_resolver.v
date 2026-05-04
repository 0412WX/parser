`timescale 1ns/1ps

module pparser_final_resolver (
    input  wire       stage0_hit,
    input  wire [1:0] stage0_addr,
    input  wire       stage1_hit,
    input  wire [2:0] stage1_addr,
    output reg  [3:0] path_id,
    output reg        error
);
    localparam PATH_ERROR            = 4'hF;
    localparam STAGE1_BYPASS         = 3'd0;

    always @* begin
        path_id = PATH_ERROR;
        error = 1'b1;

        if (!stage0_hit || !stage1_hit) begin
            path_id = PATH_ERROR;
            error = 1'b1;
        end else begin
            case (stage0_addr)
                2'd0: begin
                    if (stage1_addr == STAGE1_BYPASS) begin
                        path_id = 4'd0;
                        error = 1'b0;
                    end
                end
                2'd1: begin
                    if (stage1_addr == STAGE1_BYPASS) begin
                        path_id = 4'd1;
                        error = 1'b0;
                    end
                end
                2'd2,
                2'd3: begin
                    case (stage1_addr)
                        3'd1: begin path_id = 4'd2; error = 1'b0; end
                        3'd2: begin path_id = 4'd3; error = 1'b0; end
                        3'd3: begin path_id = 4'd6; error = 1'b0; end
                        3'd4: begin path_id = 4'd4; error = 1'b0; end
                        3'd5: begin path_id = 4'd5; error = 1'b0; end
                        3'd6: begin path_id = 4'd7; error = 1'b0; end
                        default: begin path_id = PATH_ERROR; error = 1'b1; end
                    endcase
                end
                default: begin
                    path_id = PATH_ERROR;
                    error = 1'b1;
                end
            endcase
        end
    end
endmodule
