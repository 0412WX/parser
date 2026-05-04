`timescale 1ns/1ps

module pparser_multi_short_tb;
    localparam HEADER_W = 2048;
    localparam PHV_W = 512;
    localparam PACKET_COUNT = 8;
    localparam WATCHDOG_CYCLES = 300;

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

    integer cycle_count = 0;
    integer send_count = 0;
    integer drive_index = 0;
    integer recv_count = 0;
    integer latency;
    integer expected_path [0:PACKET_COUNT-1];
    integer accept_cycle [0:PACKET_COUNT-1];
    integer output_cycle [0:PACKET_COUNT-1];
    integer i;

    reg [HEADER_W-1:0] header_rom [0:PACKET_COUNT-1];

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

    function [HEADER_W-1:0] build_short_header;
        input integer path_id;
        input [31:0] payload_word;
        reg [HEADER_W-1:0] h;
        begin
            h = {HEADER_W{1'b0}};
            h = set_u32(h, 0, 32'h00112233);
            h = set_u16(h, 4, 16'h4455);
            h = set_u32(h, 6, 32'h66778899);
            h = set_u16(h, 10, 16'hAABB);
            if (path_id == 0) begin
                h = set_u16(h, 12, 16'h0800);
                h = set_u32(h, 14, payload_word);
            end else begin
                h = set_u16(h, 12, 16'h86DD);
                h = set_u32(h, 14, payload_word);
            end
            build_short_header = h;
        end
    endfunction

    initial begin
        for (i = 0; i < PACKET_COUNT; i = i + 1) begin
            expected_path[i] = i % 2;
            accept_cycle[i] = -1;
            output_cycle[i] = -1;
            if ((i % 2) == 0) begin
                header_rom[i] = build_short_header(0, 32'h45000054);
            end else begin
                header_rom[i] = build_short_header(1, 32'h60000000);
            end
        end
    end

    initial begin
        repeat (5) @(posedge clk);
        rst <= 1'b0;
    end

    always @(posedge clk) begin
        if (rst) begin
            in_valid <= 1'b0;
            in_header <= {HEADER_W{1'b0}};
            drive_index <= 0;
        end else if (!in_valid && (drive_index < PACKET_COUNT)) begin
            in_valid <= 1'b1;
            in_header <= header_rom[drive_index];
        end else if (in_valid && in_ready) begin
            if ((drive_index + 1) < PACKET_COUNT) begin
                in_valid <= 1'b1;
                in_header <= header_rom[drive_index + 1];
                drive_index <= drive_index + 1;
            end else begin
                in_valid <= 1'b0;
                in_header <= {HEADER_W{1'b0}};
                drive_index <= drive_index + 1;
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            cycle_count <= 0;
            send_count <= 0;
            recv_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;

            if (in_valid && in_ready) begin
                accept_cycle[send_count] <= cycle_count;
                send_count <= send_count + 1;
            end

            if (out_valid && out_ready) begin
                output_cycle[recv_count] <= cycle_count;
                latency = cycle_count - accept_cycle[recv_count];

                $display(
                    "MULTI_SHORT_RESULT cycle=%0d idx=%0d path=%0d err=%0b latency=%0d phv_marker=%02h",
                    cycle_count,
                    recv_count,
                    out_path_id,
                    out_error,
                    latency,
                    out_phv[303:296]
                );

                if (out_error !== 1'b0) begin
                    $display("ERROR: packet %0d produced parse error", recv_count);
                    $fatal(1);
                end

                if (out_path_id !== expected_path[recv_count][3:0]) begin
                    $display(
                        "ERROR: packet %0d expected path %0d got %0d",
                        recv_count, expected_path[recv_count], out_path_id
                    );
                    $fatal(1);
                end

                if (out_phv[303:296] !== {4'h0, expected_path[recv_count][3:0]}) begin
                    $display("ERROR: packet %0d PHV marker mismatch", recv_count);
                    $fatal(1);
                end

                if (latency != 12) begin
                    $display("ERROR: packet %0d expected latency 12 got %0d", recv_count, latency);
                    $fatal(1);
                end

                if ((recv_count > 0) && ((accept_cycle[recv_count] - accept_cycle[recv_count - 1]) != 1)) begin
                    $display(
                        "ERROR: packet %0d initiation interval expected 1 got %0d",
                        recv_count,
                        accept_cycle[recv_count] - accept_cycle[recv_count - 1]
                    );
                    $fatal(1);
                end

                recv_count <= recv_count + 1;
                if ((recv_count + 1) == PACKET_COUNT) begin
                    $display("PASS: multi short-packet stream parsed correctly");
                    $finish;
                end
            end

            if (cycle_count > WATCHDOG_CYCLES) begin
                $display("ERROR: watchdog timeout");
                $fatal(1);
            end

        end
    end
endmodule
