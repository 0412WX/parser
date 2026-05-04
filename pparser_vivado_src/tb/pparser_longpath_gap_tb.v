`timescale 1ns/1ps

module pparser_longpath_gap_tb;
    localparam HEADER_W = 2048;
    localparam PHV_W = 512;
    localparam PATH_ERROR = 4'hF;
    localparam WATCHDOG_CYCLES = 4000;

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
                2: begin
                    h = set_u16(h, 12, 16'h8847);
                    h = set_u32(h, 14, 32'h001000FF);
                    h = set_u16(h, 18, 16'h0800);
                    h = set_u16(h, 20, 16'h4501);
                end
                3: begin
                    h = set_u16(h, 12, 16'h8847);
                    h = set_u32(h, 14, 32'h001000FF);
                    h = set_u16(h, 18, 16'h86DD);
                    h = set_u16(h, 20, 16'h6001);
                end
                4: begin
                    h = set_u16(h, 12, 16'h8847);
                    h = set_u32(h, 14, 32'h001000FF);
                    h = set_u16(h, 18, 16'h8847);
                    h = set_u16(h, 20, 16'h0020);
                    h = set_u16(h, 22, 16'h0800);
                    h = set_u16(h, 24, 16'h4522);
                end
                5: begin
                    h = set_u16(h, 12, 16'h8847);
                    h = set_u32(h, 14, 32'h001000FF);
                    h = set_u16(h, 18, 16'h8847);
                    h = set_u16(h, 20, 16'h0020);
                    h = set_u16(h, 22, 16'h86DD);
                    h = set_u16(h, 24, 16'h6022);
                end
                6: begin
                    h = set_u16(h, 12, 16'h8847);
                    h = set_u32(h, 14, 32'h001000FF);
                    h = set_u16(h, 18, 16'h6558);
                    h = set_u16(h, 20, 16'hABCD);
                end
                7: begin
                    h = set_u16(h, 12, 16'h8847);
                    h = set_u32(h, 14, 32'h001000FF);
                    h = set_u16(h, 18, 16'h8847);
                    h = set_u16(h, 20, 16'h0020);
                    h = set_u16(h, 22, 16'h6558);
                    h = set_u16(h, 24, 16'hEEFF);
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
        input [HEADER_W-1:0] header,
        input integer gap_cycles_after_accept
    );
        begin
            @(negedge clk);
            in_valid <= 1'b1;
            in_header <= header;
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
        input bit expected_error,
        input [8*64-1:0] label
    );
        integer timeout;
        begin
            timeout = 0;
            while (!out_valid) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (timeout > 300) begin
                    failures = failures + 1;
                    $display("ERROR: %0s timed out waiting for output", label);
                    disable expect_output;
                end
            end

            @(posedge clk);
            output_cycle = cycle_count;
            latency = output_cycle - accept_cycle;

            $display(
                "%0s expected_path=%0d expected_err=%0b got_path=%0d err=%0b latency=%0d",
                label, expected_path, expected_error, out_path_id, out_error, latency
            );

            if (out_error !== expected_error) begin
                failures = failures + 1;
                $display("ERROR: %0s error flag mismatch", label);
            end

            if (out_path_id !== expected_path[3:0]) begin
                failures = failures + 1;
                $display("ERROR: %0s expected path %0d got %0d", label, expected_path, out_path_id);
            end

            if (!expected_error && (out_phv[303:296] !== {4'h0, expected_path[3:0]})) begin
                failures = failures + 1;
                $display("ERROR: %0s PHV marker mismatch", label);
            end
        end
    endtask

    task automatic run_single_packet_suite;
        begin
            $display("SUITE: single-packet long paths");
            send_packet(build_header_for_path(2), 2);
            expect_output(2, 1'b0, "single_mpls_ipv4");
            send_packet(build_header_for_path(3), 2);
            expect_output(3, 1'b0, "single_mpls_ipv6");
            send_packet(build_header_for_path(4), 2);
            expect_output(4, 1'b0, "single_mpls_mpls_ipv4");
            send_packet(build_header_for_path(5), 2);
            expect_output(5, 1'b0, "single_mpls_mpls_ipv6");
            send_packet(build_header_for_path(6), 2);
            expect_output(6, 1'b0, "single_mpls_eompls");
            send_packet(build_header_for_path(7), 2);
            expect_output(7, 1'b0, "single_mpls_mpls_eompls");
        end
    endtask

    task automatic run_invalid_single_suite;
        reg [HEADER_W-1:0] bad_header;
        begin
            $display("SUITE: single invalid long path");
            bad_header = build_header_for_path(2);
            bad_header = set_u16(bad_header, 18, 16'h1234);
            send_packet(bad_header, 2);
            expect_output(PATH_ERROR, 1'b1, "single_invalid_mpls");
        end
    endtask

    task automatic run_gap_suite(input integer gap_cycles);
        reg [8*64-1:0] label;
        integer expected_path;
        begin
            $display("SUITE: multi-packet long paths gap=%0d", gap_cycles);
            for (idx = 0; idx < 12; idx = idx + 1) begin
                expected_path = 2 + (idx % 6);
                send_packet(build_header_for_path(expected_path), gap_cycles);
                case (expected_path)
                    2: label = "burst_mpls_ipv4";
                    3: label = "burst_mpls_ipv6";
                    4: label = "burst_mpls_mpls_ipv4";
                    5: label = "burst_mpls_mpls_ipv6";
                    6: label = "burst_mpls_eompls";
                    default: label = "burst_mpls_mpls_eompls";
                endcase
                expect_output(expected_path, 1'b0, label);
            end
        end
    endtask

    initial begin
        $dumpfile("pparser_longpath_gap_tb.vcd");
        $dumpvars(0, pparser_longpath_gap_tb);
        cycle_count = 0;
        failures = 0;

        repeat (5) @(posedge clk);
        rst <= 1'b0;

        run_single_packet_suite();
        run_invalid_single_suite();
        run_gap_suite(1);
        run_gap_suite(2);

        if (failures == 0) begin
            $display("PASS: long-path single/gap suites completed");
        end else begin
            $display("FAIL: long-path single/gap suites saw %0d failure(s)", failures);
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
