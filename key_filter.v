`timescale 1ns / 1ps

/*
===============================================================================
模块名称：key_filter

模块用途：
    对机械按键进行消抖，并在确认按下或释放时产生一个时钟周期的事件脉冲。

接口约定（依据《超声波测距项目接口说明 v1.0》）：
    sys_clk     100MHz 系统时钟，上升沿更新时序逻辑。
    sys_rst_n   低电平有效、异步复位。
    key_in      异步按键输入；模块内部先做两级同步，再检测边沿。
    key_event   消抖后的单周期事件脉冲：确认按下、确认松开各出现一拍。
    key_state   消抖后的稳定电平：1 = 按下，0 = 松开。
    led_toggle  每确认一次“按下”翻转一次，可直接驱动指示 LED。

顶层怎样得到 single_start（与 ultrasound_ctrl 协作时的关键）：
    key_event 在“按下”和“松开”时都会产生，而 single_start 只应在按下时
    启动一组 8 次触发，所以要先用 key_state 选通，顶层写成：
        wire single_start = key_event & key_state;
    这样送进 ultrasound_ctrl 的是消抖后的单周期脉冲，松开不会误触发，
    也满足接口“single_start 不能直接接原始按键”的要求。
    本模块内部逻辑与源码完全一致，没有改动。

实现方法：
    1. 先用两级寄存器同步按键输入。
    2. 当同步后的电平与当前稳定状态不同时开始计数。
    3. 只有该电平连续保持 20ms，才接受为新的稳定状态。
    4. 更新状态的同时令 key_event=1，持续一个 sys_clk 周期。

计数位宽：
    DEBOUNCE_COUNT = 100_000_000 / 1000 * 20 = 2_000_000，
    21 位计数器最大 2^21-1 = 2_097_151，刚好够用（与源码一致）。

EGO1 通用按键：平时为低，按下为高。
===============================================================================
*/

module key_filter #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer DEBOUNCE_MS = 20
)(
    input  wire sys_clk,
    input  wire sys_rst_n,
    input  wire key_in,
    output reg  key_event,
    output reg  key_state,
    output reg  led_toggle
);

    localparam integer DEBOUNCE_COUNT = CLK_FREQ_HZ / 1000 * DEBOUNCE_MS;

    reg key_meta;
    reg key_sync;
    reg [20:0] debounce_cnt;

    // 两级同步器：把异步的 key_in 同步进 sys_clk 时钟域，避免亚稳态。
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            key_meta <= 1'b0;
            key_sync <= 1'b0;
        end else begin
            key_meta <= key_in;
            key_sync <= key_meta;
        end
    end

    // 稳定计数和事件产生。
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            debounce_cnt <= 21'd0;
            key_event    <= 1'b0;
            key_state    <= 1'b0;
            led_toggle   <= 1'b0;
        end else begin
            key_event <= 1'b0;              // 默认拉低：事件只保持一个时钟周期

            if (key_sync == key_state) begin
                // 输入与已确认状态相同，不需要继续消抖。
                debounce_cnt <= 21'd0;
            end else if (debounce_cnt == DEBOUNCE_COUNT-1) begin
                // 新电平已经连续保持满 20ms，接受为新的稳定状态。
                debounce_cnt <= 21'd0;
                key_state    <= key_sync;
                key_event    <= 1'b1;       // 单周期事件脉冲

                // 只在确认“按下”时翻转指示 LED。
                if (key_sync)
                    led_toggle <= ~led_toggle;
            end else begin
                debounce_cnt <= debounce_cnt + 1'b1;
            end
        end
    end

endmodule