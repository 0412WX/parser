`timescale 1ns/1ps

module pparser_cam_smoke_tb;
    reg         clk;
    reg         rst;
    reg [16:0]  stage0_cmp_din;
    wire        stage0_ready;
    wire        stage0_match;
    wire [3:0]  stage0_match_addr;
    reg [32:0]  stage1_cmp_din;
    wire        stage1_ready;
    wire        stage1_match;
    wire [3:0]  stage1_match_addr;

    integer failures;

    pparser_stage0_cam_core u_stage0_cam_core (
        .clk(clk),
        .rst(rst),
        .cmp_din(stage0_cmp_din),
        .ready(stage0_ready),
        .match(stage0_match),
        .match_addr(stage0_match_addr)
    );

    pparser_stage1_cam_core u_stage1_cam_core (
        .clk(clk),
        .rst(rst),
        .cmp_din(stage1_cmp_din),
        .ready(stage1_ready),
        .match(stage1_match),
        .match_addr(stage1_match_addr)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst = 1'b1;
        stage0_cmp_din = 17'd0;
        stage1_cmp_din = 33'd0;
        failures = 0;

        repeat (5) @(posedge clk);
        rst <= 1'b0;

        wait (stage0_ready && stage1_ready);
        @(posedge clk);

        $display("CAM wrappers report ready at time %0t", $time);

        check_stage0_hit("stage0_entry0", 17'b10000100000000000, 4'd0);
        check_stage0_hit("stage0_entry1", 17'b11000011011011101, 4'd1);
        check_stage0_hit("stage0_entry2", 17'b11000100010001111, 4'd2);
        check_stage0_hit("stage0_entry3", 17'b11000100010010000, 4'd3);
        check_stage0_miss("stage0_miss", 17'b11111111111111111);

        check_stage1_hit("stage1_entry0", 33'b100000000000000000000000000000000, 4'd0);
        check_stage1_hit("stage1_entry4", 33'b110001000100011100001000000000000, 4'd4);
        check_stage1_hit("stage1_entry5", 33'b110001000100011110000110110111010, 4'd5);
        check_stage1_hit("stage1_entry6", 33'b110001000100011101100101010110000, 4'd6);
        check_stage1_masked_hit("stage1_masked_entry1_exact", 33'b100001000000000000000000000000000, 4'd1);
        check_stage1_masked_hit("stage1_masked_entry1_wild", 33'b100001000000000011111111111111111, 4'd1);
        check_stage1_masked_hit("stage1_masked_entry2_wild", 33'b110000110110111011010101010101010, 4'd2);
        check_stage1_masked_hit("stage1_masked_entry3_wild", 33'b101100101010110001001100110011001, 4'd3);
        check_stage1_miss("stage1_miss", 33'b111111111111111111111111111111111);

        if (failures == 0) begin
            $display("PASS: CAM smoke test completed without mismatches");
        end else begin
            $display("FAIL: CAM smoke test saw %0d mismatches", failures);
            $fatal(1);
        end

        $finish;
    end

    task automatic check_stage0_hit(
        input [8*32-1:0] name,
        input [16:0] query,
        input [3:0] expected_addr
    );
    begin
        stage0_cmp_din <= query;
        @(posedge clk);
        @(posedge clk);
        #1;
        $display("%0s query=%b match=%0b addr=%0d", name, query, stage0_match, stage0_match_addr);
        if (!stage0_match || (stage0_match_addr !== expected_addr)) begin
            failures = failures + 1;
            $display("ERROR: %0s expected hit at addr %0d", name, expected_addr);
        end
    end
    endtask

    task automatic check_stage0_miss(
        input [8*32-1:0] name,
        input [16:0] query
    );
    begin
        stage0_cmp_din <= query;
        @(posedge clk);
        @(posedge clk);
        #1;
        $display("%0s query=%b match=%0b addr=%0d", name, query, stage0_match, stage0_match_addr);
        if (stage0_match) begin
            failures = failures + 1;
            $display("ERROR: %0s expected miss", name);
        end
    end
    endtask

    task automatic check_stage1_hit(
        input [8*32-1:0] name,
        input [32:0] query,
        input [3:0] expected_addr
    );
    begin
        stage1_cmp_din <= query;
        @(posedge clk);
        @(posedge clk);
        #1;
        $display("%0s query=%b match=%0b addr=%0d", name, query, stage1_match, stage1_match_addr);
        if (!stage1_match || (stage1_match_addr !== expected_addr)) begin
            failures = failures + 1;
            $display("ERROR: %0s expected hit at addr %0d", name, expected_addr);
        end
    end
    endtask

    task automatic check_stage1_masked_hit(
        input [8*32-1:0] name,
        input [32:0] query,
        input [3:0] expected_addr
    );
    begin
        stage1_cmp_din <= query;
        @(posedge clk);
        @(posedge clk);
        #1;
        $display("%0s query=%b match=%0b addr=%0d", name, query, stage1_match, stage1_match_addr);
        if (!stage1_match || (stage1_match_addr !== expected_addr)) begin
            failures = failures + 1;
            $display("ERROR: %0s expected masked hit at addr %0d", name, expected_addr);
        end
    end
    endtask

    task automatic check_stage1_miss(
        input [8*32-1:0] name,
        input [32:0] query
    );
    begin
        stage1_cmp_din <= query;
        @(posedge clk);
        @(posedge clk);
        #1;
        $display("%0s query=%b match=%0b addr=%0d", name, query, stage1_match, stage1_match_addr);
        if (stage1_match) begin
            failures = failures + 1;
            $display("ERROR: %0s expected miss", name);
        end
    end
    endtask
endmodule
