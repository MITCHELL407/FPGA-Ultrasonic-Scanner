`timescale 1ns / 1ps

// 根据设定距离与当前平均距离进行比较，控制 LED 和蜂鸣器报警。
module LED_warning (
    input               sys_clk,
    input               sys_rst_n,
    input       [12:0]  key_cnt,
    input       [12:0]  data_ave,
    input               confirm,       // 开始比较

    output reg          led_warning,
    output reg          beep
);

    // 报警距离阈值：设定值乘以 10。
    wire [12:0] lenth_warning;
    assign lenth_warning = key_cnt * 10;

    // 当确认比较且测量距离小于阈值时，启动声光报警。
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            led_warning <= 1'b0;
            beep        <= 1'b1;
        end
        else if (confirm && (data_ave < lenth_warning)) begin
            led_warning <= 1'b1;
            beep        <= 1'b0;
        end
        else begin
            led_warning <= 1'b0;
            beep        <= 1'b1;
        end
    end

endmodule
