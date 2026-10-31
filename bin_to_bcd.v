`timescale 1ns / 1ps

module bin_to_bcd(
    input  wire [12:0] binary_in,  // 输入范围：0-8191
    output reg  [15:0] bcd_out     // 千百十个
);

    integer i;

    always @(*) begin  //读binary_in变化
        // 每次重新转换前，先清零
        bcd_out = 16'd0;

        // 从输入的最高位开始，逐位处理，累加
        for (i = 12; i >= 0; i = i - 1) begin

            // 第一步：各十进制数位达到5，就加3
            //5先加3变成 1000，再左移得到 0001 0000
            if (bcd_out[3:0] >= 4'd5)
                bcd_out[3:0] = bcd_out[3:0] + 4'd3;

            if (bcd_out[7:4] >= 4'd5)
                bcd_out[7:4] = bcd_out[7:4] + 4'd3;

            if (bcd_out[11:8] >= 4'd5)
                bcd_out[11:8] = bcd_out[11:8] + 4'd3;

            if (bcd_out[15:12] >= 4'd5)
                bcd_out[15:12] = bcd_out[15:12] + 4'd3;

            // 第二步：左移一位，把当前输入的binary放到bcdout，继续下一轮循环
            bcd_out = {bcd_out[14:0], binary_in[i]};
        end
    end

endmodule