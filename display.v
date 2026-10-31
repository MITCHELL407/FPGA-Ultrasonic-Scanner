`timescale 1ns / 1ps

module display(
    input  wire        sys_clk,     // 100MHz时钟
    input  wire        sys_rst_n,   // 低电平复位
    input  wire [15:0] data_bcd,     // 四位BCD数字

    output reg  [3:0]  an,          // 位选：选择哪一位数码管
    output reg  [7:0]  seg          // 段选：决定显示哪个数字
);

    // 100MHz时钟：100000个周期等于1ms
    localparam SCAN_MAX = 100_000;

    reg [16:0] scan_cnt;            // 1ms计数器
    reg [1:0]  digit_index;         // 当前显示第几位：0、1、2、3
    reg [3:0]  digit;               // 当前位要显示的数字
    reg        dp;                 // 小数点

    // 第一部分：每隔1ms切换到下一位
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (sys_rst_n == 1'b0) begin   //复位变0，直接清0
            scan_cnt    <= 17'd0;
            digit_index <= 2'd0;
        end
        else if (scan_cnt == SCAN_MAX - 1) begin
            scan_cnt    <= 17'd0;  //计数满了，某位已经显示了1ms
            digit_index <= digit_index + 1'b1;//看下一位
        end
        else begin
            scan_cnt <= scan_cnt + 1'b1;  //不满1ms，继续显示该位
        end
    end

    // 第二部分：选择数码管和对应的BCD数字
    always @(*) begin
        an    = 4'b0000;  //位选信号，现在不选中
        digit = 4'd0;
        dp    = 1'b0;

        case (digit_index)  //这里读取了digit_index和data_bcd
            2'd0: begin
                an    = 4'b0001; //现在选中第一位，最右边
                digit = data_bcd[3:0];  //显示第4位数字（一共16位，每4位表示一个数字,第四个是3-0）
            end

            2'd1: begin
                an    = 4'b0010;
                digit = data_bcd[7:4];
                dp    = 1'b1;
            end

            2'd2: begin
                an    = 4'b0100;
                digit = data_bcd[11:8];
            end

            2'd3: begin
                an    = 4'b1000;
                digit = data_bcd[15:12];
            end
        endcase
    end

    // 第三部分：把数字转换成七段数码管的点亮方式
    // seg[0]~seg[6]分别对应A~G7个对应段，seg[7]对应小数点
    always @(*) begin
        case (digit)
            4'd0: seg[6:0] = 7'b0111111;  //digit对应0时，控制对应段使显示出0
            4'd1: seg[6:0] = 7'b0000110;
            4'd2: seg[6:0] = 7'b1011011;
            4'd3: seg[6:0] = 7'b1001111;
            4'd4: seg[6:0] = 7'b1100110;
            4'd5: seg[6:0] = 7'b1101101;
            4'd6: seg[6:0] = 7'b1111101;
            4'd7: seg[6:0] = 7'b0000111;
            4'd8: seg[6:0] = 7'b1111111;
            4'd9: seg[6:0] = 7'b1101111;
            default: seg[6:0] = 7'b0000000;
        endcase

        seg[7] = dp;
    end

endmodule