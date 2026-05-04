`timescale 1ns/1ps

module pparser_shortpath_gap_tb;
    localparam HEADER_W = 2048;
    localparam PHV_W = 512;
    localparam PATH_ERROR = 4'hF;
    localparam WATCHDOG_CYCLES = 2000;

    reg                 clk = 1'b0;
    reg                 rst = 1'b1;
    reg                 in_valid = 1'b0;
    wire                in_ready;
    reg  [HEADER_W-1:0] in_header = {HEADER_W{1'b0}};
    wire                out_valid;
    reg                 out_ready = 1'b1;
    wire [3:0]          out_path_id;
    wire                out_error;
    wire [PHV_W-1:0]    out_phv;

    integer cycle_count;
    integer failures;
    integer accept_cycle;
    integer output_cycle;
    integer latency;
    integer idx;

    pparser_hw_static dut (
        .clk(clk),
        .rst(rst),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .in_header(in_header),
        .out_valid(out_valid),
        .out_ready(out_ready),
        .out_path_id(out_path_id),
        .out_error(out_error),
        .out_phv(out_phv)
    );

    always #5 clk = ~clk;

    function [HEADER_W-1:0] set_byte;
        input [HEADER_W-1:0] data;
        input integer byte_idx;
        input [7:0] value;
        begin
            set_byte = data;
            set_byte[HEADER_W - 1 - (byte_idx * 8) -: 8] = value;
        end
    endfunction

    function [HEADER_W-1:0] set_u16;
        input [HEADER_W-1:0] data;
        input integer byte_idx;
        input [15:0] value;
        begin
            set_u16 = data;
            set_u16 = set_byte(set_u16, byte_idx, value[15:8]);
            set_u16 = set_byte(set_u16, byte_idx + 1, value[7:0]);
        end
    endfunction

    function [HEADER_W-1:0] set_u32;
        input [HEADER_W-1:0] data;
        input integer byte_idx;
        input [31:0] value;
        begin
            set_u32 = data;
            set_u32 = set_byte(set_u32, byte_idx, value[31:24]);
            set_u32 = set_byte(set_u32, byte_idx + 1, value[23:16]);
            set_u32 = set_byte(set_u32, byte_idx + 2, value[15:8]);
            set_u32 = set_byte(set_u32, byte_idx + 3, value[7:0]);
        end
    endfunction

    function [HEADER_W-1:0] build_header_for_path;
        input integer path_id;
        reg [HEADER_W-1:0] h;
        begin
            h = {HEADER_W{1'b0}};
            h = set_u32(h, 0, 32'h00112233);
            h = set_u16(h, 4, 16'h4455);
            h = set_u32(h, 6, 32'h66778899);
            h = set_u16(h, 10, 16'hAABB);
            case (path_id)
                0: begin
                    h = set_u16(h, 12, 16'h0800);
                    h = set_u32(h, 14, 32'h45000054);
                end
                1: begin
                    h = set_u16(h, 12, 16'h86DD);
                    h = set_u32(h, 14, 32'h60000000);
                end
                default: begin
                    h = set_u16(h, 12, 16'h9999);
                end
            endcase
            build_header_for_path = h;
        end
    endfunction

    task automatic wait_cycles(input integer count);
        integer j;
        begin
            for (j = 0; j < count; j = j + 1) begin
                @(posedge clk);
            end
        end
    endtask

    task automatic send_packet(
        input integer path_id,
        input integer gap_cycles_after_accept
    );
        begin
            @(negedge clk);
            in_valid <= 1'b1;
            in_header <= build_header_for_path(path_id);
            while (!in_ready) begin
                @(posedge clk);
                @(negedge clk);
            end

            @(posedge clk);
            accept_cycle = cycle_count;
            @(negedge clk);
            in_valid <= 1'b0;
            in_header <= {HEADER_W{1'b0}};

            wait_cycles(gap_cycles_after_accept);
        end
    endtask

    task automatic expect_output(
        input integer expected_path,
        input [8*48-1:0] label
    );
        integer timeout;
        begin
            timeout = 0;
            while (!out_valid) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (timeout > 200) begin
                    failures = failures + 1;
                    $display("ERROR: %0s timed out waiting for output", label);
                    disable expect_output;
                end
            end

            @(posedge clk);
            output_cycle = cycle_count;
            latency = output_cycle - accept_cycle;

            $display(
                "%0s expected_path=%0d got_path=%0d err=%0b latency=%0d",
                label, expected_path, out_path_id, out_error, latency
            );

            if (out_error) begin
                failures = failures + 1;
                $display("ERROR: %0s produced parse error", label);
            end

            if (out_path_id !== expected_path[3:0]) begin
                failures = failures + 1;
                $display("ERROR: %0s expected path %0d got %0d", label, expected_path, out_path_id);
            end

            if (out_phv[303:296] !== {4'h0, expected_path[3:0]}) begin
                failures = failures + 1;
                $display("ERROR: %0s PHV marker mismatch", label);
            end
        end
    endtask

    task automatic run_single_packet_suite;
        begin
            $display("SUITE: single-packet short paths");
            send_packet(0, 2);
            expect_output(0, "single_ipv4");
            send_packet(1, 2);
            expect_output(1, "single_ipv6");
        end
    endtask

    task automatic run_gap_suite(input integer gap_cycles);
        reg [8*48-1:0] label;
        begin
            $display("SUITE: multi-packet short paths gap=%0d", gap_cycles);
            for (idx = 0; idx < 8; idx = idx + 1) begin
                send_packet(idx % 2, gap_cycles);
                if ((idx % 2) == 0) begin
                    label = "burst_ipv4";
                end else begin
                    label = "burst_ipv6";
                end
                expect_output(idx % 2, label);
            end
        end
    endtask

    initial begin
        $dumpfile("pparser_shortpath_gap_tb.vcd");
        $dumpvars(0, pparser_shortpath_gap_tb);
        cycle_count = 0;
        failures = 0;

        repeat (5) @(posedge clk);
        rst <= 1'b0;

        run_single_packet_suite();
        run_gap_suite(1);
        run_gap_suite(2);

        if (failures == 0) begin
            $display("PASS: short-path single/gap suites completed");
        end else begin
            $display("FAIL: short-path single/gap suites saw %0d failure(s)", failures);
            $fatal(1);
        end
        $finish;
    end

    always @(posedge clk) begin
        if (rst) begin
            cycle_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
            if (cycle_count > WATCHDOG_CYCLES) begin
                $display("ERROR: watchdog timeout");
                $fatal(1);
            end
        end
    end
endmodule
