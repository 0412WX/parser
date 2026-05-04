`timescale 1ns/1ps

module pparser_hw_static_tb;
    localparam HEADER_W = 2048;
    localparam PHV_W = 512;
    localparam PATH_ERROR = 4'hF;
    localparam MAX_PACKETS = 256;

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
    integer send_count;
    integer recv_count;
    integer packet_total;
    integer drive_index;
    integer expected_paths [0:MAX_PACKETS-1];
    integer accept_cycles [0:MAX_PACKETS-1];
    integer output_cycles [0:MAX_PACKETS-1];
    integer ii;
    integer current_path;
    integer latency;
    reg [HEADER_W-1:0] temp_header;
    reg [HEADER_W-1:0] header_queue [0:MAX_PACKETS-1];
    reg                stream_enable = 1'b0;

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

    task reset_scoreboard;
        begin
            send_count = 0;
            recv_count = 0;
            packet_total = 0;
            drive_index = 0;
            stream_enable = 1'b0;
            in_valid = 1'b0;
            in_header = {HEADER_W{1'b0}};
            for (ii = 0; ii < MAX_PACKETS; ii = ii + 1) begin
                header_queue[ii] = {HEADER_W{1'b0}};
                expected_paths[ii] = -1;
                accept_cycles[ii] = -1;
                output_cycles[ii] = -1;
            end
        end
    endtask

    task enqueue_packet;
        input [HEADER_W-1:0] header;
        input integer expected_path;
        begin
            header_queue[packet_total] = header;
            expected_paths[packet_total] = expected_path;
            packet_total = packet_total + 1;
        end
    endtask

    task wait_for_all_outputs;
        begin
            wait (recv_count == packet_total);
            @(posedge clk);
        end
    endtask

    task prepare_stream;
        begin
            drive_index = 0;
            @(negedge clk);
            stream_enable <= 1'b1;
            in_valid <= (packet_total > 0);
            if (packet_total > 0) begin
                in_header <= header_queue[0];
            end else begin
                in_header <= {HEADER_W{1'b0}};
            end
        end
    endtask

    task check_initiation_interval;
        input integer first_idx;
        input integer second_idx;
        begin
            if (accept_cycles[second_idx] - accept_cycles[first_idx] != 1) begin
                $display(
                    "ERROR: initiation interval mismatch expected=1 got=%0d",
                    accept_cycles[second_idx] - accept_cycles[first_idx]
                );
                $fatal(1);
            end
        end
    endtask

    task run_short_path_suite;
        begin
            out_ready <= 1'b1;
            reset_scoreboard();

            for (current_path = 0; current_path < 2; current_path = current_path + 1) begin
                enqueue_packet(build_header_for_path(current_path), current_path);
            end

            for (current_path = 0; current_path < 32; current_path = current_path + 1) begin
                enqueue_packet(build_header_for_path(current_path % 2), current_path % 2);
            end

            prepare_stream();
            wait_for_all_outputs();
        end
    endtask

    task run_long_path_suite;
        begin
            out_ready <= 1'b1;
            reset_scoreboard();

            for (current_path = 2; current_path < 8; current_path = current_path + 1) begin
                enqueue_packet(build_header_for_path(current_path), current_path);
            end

            temp_header = build_header_for_path(2);
            temp_header = set_u16(temp_header, 18, 16'h1234);
            enqueue_packet(temp_header, PATH_ERROR);

            for (current_path = 0; current_path < 48; current_path = current_path + 1) begin
                enqueue_packet(build_header_for_path(2 + (current_path % 6)), 2 + (current_path % 6));
            end

            prepare_stream();
            wait_for_all_outputs();
        end
    endtask

    task run_mixed_backpressure_suite;
        begin
            reset_scoreboard();

            for (current_path = 0; current_path < 32; current_path = current_path + 1) begin
                enqueue_packet(build_header_for_path(current_path % 8), current_path % 8);
            end

            enqueue_packet(build_header_for_path(15), PATH_ERROR);

            prepare_stream();

            while (recv_count < packet_total) begin
                @(posedge clk);
                case (cycle_count % 6)
                    2,
                    4: out_ready <= 1'b0;
                    default: out_ready <= 1'b1;
                endcase
            end

            out_ready <= 1'b1;
            @(posedge clk);
        end
    endtask

    initial begin
        $dumpfile("pparser_hw_static_tb.vcd");
        $dumpvars(0, pparser_hw_static_tb);
        cycle_count = 0;
        reset_scoreboard();
    end

    always @(posedge clk) begin
        if (rst) begin
            cycle_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
        end

        if (!rst && in_valid && in_ready) begin
            accept_cycles[send_count] <= cycle_count;
            send_count <= send_count + 1;
        end

        if (!rst && out_valid && out_ready) begin
            output_cycles[recv_count] <= cycle_count;

            if (expected_paths[recv_count] == PATH_ERROR) begin
                if (!out_error || out_path_id != PATH_ERROR) begin
                    $display(
                        "ERROR: expected error packet at %0d, got path=%0d error=%0d",
                        recv_count, out_path_id, out_error
                    );
                    $fatal(1);
                end
            end else begin
                if (out_error) begin
                    $display("ERROR: unexpected parse error at packet %0d", recv_count);
                    $fatal(1);
                end

                if (out_path_id !== expected_paths[recv_count][3:0]) begin
                    $display(
                        "ERROR: path mismatch at packet %0d expected=%0d got=%0d",
                        recv_count, expected_paths[recv_count], out_path_id
                    );
                    $fatal(1);
                end

                if (out_phv[303:296] !== {4'h0, expected_paths[recv_count][3:0]}) begin
                    $display("ERROR: PHV path marker mismatch at packet %0d", recv_count);
                    $fatal(1);
                end
            end

            latency = cycle_count - accept_cycles[recv_count];
            if (out_ready && latency < 8) begin
                $display("ERROR: latency underflow at packet %0d got=%0d", recv_count, latency);
                $fatal(1);
            end

            if ((packet_total > 16) && out_ready && (latency != 12)) begin
                $display("ERROR: nominal latency mismatch at packet %0d expected=12 got=%0d", recv_count, latency);
                $fatal(1);
            end

            recv_count <= recv_count + 1;
        end
    end

    always @(negedge clk) begin
        if (rst) begin
            in_valid <= 1'b0;
            in_header <= {HEADER_W{1'b0}};
            drive_index <= 0;
        end else if (!stream_enable) begin
            in_valid <= 1'b0;
            in_header <= {HEADER_W{1'b0}};
        end else begin
            if (in_valid && in_ready) begin
                drive_index <= drive_index + 1;
                if ((drive_index + 1) < packet_total) begin
                    in_valid <= 1'b1;
                    in_header <= header_queue[drive_index + 1];
                end else begin
                    in_valid <= 1'b0;
                    in_header <= {HEADER_W{1'b0}};
                end
            end
        end
    end

    initial begin
        repeat (5) @(posedge clk);
        rst <= 1'b0;

        run_short_path_suite();

        $display("PASS: short-path suite completed");
        $finish;
    end
endmodule
