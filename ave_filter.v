`timescale 1ns / 1ps

module ave_filter(
    input  wire        sys_clk,
    input  wire        sys_rst_n,

    input  wire [12:0] distance_in,    // 新测量距离，单位mm
    input  wire        distance_valid, // 输入数据有效，持续一个周期

    output reg  [12:0] distance_avg,   // 平均距离，单位mm
    output reg         avg_valid       // 平均结果有效，持续一个周期
);

    // 保存最近8次测量结果
    reg [12:0] samples [0:7];

    // 下一次要写入的位置：0~7
    reg [2:0] write_index;

    // 已收到的有效数据数量：0~8
    reg [3:0] sample_count;

    // 8个13位数相加，最大为65528，需要16位
    reg [15:0] sum;

    // 加入本次测量后，新的总和与数据数量
    wire [15:0] next_sum;
    wire [3:0]  next_count;

    integer i;

    assign next_sum = sum
                    - {3'b000, samples[write_index]}
                    + {3'b000, distance_in};

    assign next_count = (sample_count < 4'd8)
                      ? sample_count + 4'd1
                      : 4'd8;

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            write_index  <= 3'd0;
            sample_count <= 4'd0;
            sum          <= 16'd0;
            distance_avg <= 13'd0;
            avg_valid    <= 1'b0;

            for (i = 0; i < 8; i = i + 1) begin
                samples[i] <= 13'd0;
            end
        end
        else begin
            // 默认没有新的平均结果
            avg_valid <= 1'b0;

            if (distance_valid) begin
                samples[write_index] <= distance_in;

                sum          <= next_sum;
                sample_count <= next_count;

                // 3位计数器从7加1后自动回到0
                write_index <= write_index + 3'd1;

                // 不足8次时除以实际数量，满8次后除以8
                if (sample_count < 4'd8)
                    distance_avg <= next_sum / next_count;
                else
                    distance_avg <= next_sum >> 3;

                avg_valid <= 1'b1;
            end
        end
    end

endmodule