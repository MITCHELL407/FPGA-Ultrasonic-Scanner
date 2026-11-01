`timescale 1ns / 1ps

// 100 MHz 时钟下生成舵机控制 PWM 信号。
// PWM 周期为 20 ms（50 Hz），高电平宽度由 angle 决定。
module PWM (
    input               sys_clk,
    input               sys_rst_n,
    input       [7:0]   angle,
    input               pwm_req,

    output reg          pwm
);

    // 计数与脉宽参数。
    localparam [20:0] PWM_PERIOD      = 21'd1999999;
    localparam [31:0] PWM_BASE_COUNT  = 32'd50000;
    localparam [31:0] PWM_ANGLE_STEP  = 32'd1111;

    reg [20:0] cnt;

    // PWM 周期计数：请求有效时计数，到达周期末尾后清零。
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            cnt <= 21'd0;
        end
        else if (cnt == PWM_PERIOD) begin
            cnt <= 21'd0;
        end
        else if (pwm_req) begin
            cnt <= cnt + 1'b1;
        end
        // 其他情况下保持当前计数值。
    end

    // 根据 angle 设置 PWM 高电平持续时间。
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            pwm <= 1'b0;
        end
        else if (!pwm_req) begin
            pwm <= 1'b0;
        end
        else if (cnt <= (PWM_BASE_COUNT + angle * PWM_ANGLE_STEP)) begin
            pwm <= 1'b1;
        end
        else begin
            pwm <= 1'b0;
        end
    end

endmodule
