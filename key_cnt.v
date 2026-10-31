`timescale 1ns / 1ps

/*
===============================================================================
模块名称：key_cnt

模块用途：
    每确认按下一次阈值设置按键，报警阈值增加 1cm（= 10mm）。

与源码的接口差异（只统一单位，逻辑与源码逐行对应）：
    源码输出 threshold_cm（厘米），约定由顶层乘 10 后再与 distance_mm 比较。
    接口说明第 6 节要求“阈值和被比较距离都用毫米；100cm 存为 13'd1000”，
    因此本版本直接输出毫米值 threshold_mm：
        初值 13'd1000 (100cm)、上限 13'd2000 (200cm)、每次 +13'd10 (1cm)，
        到达上限后下一次按键回到 13'd10 (1cm)。
    递增、回绕、只在“按下”事件时计数这三条逻辑与源码完全一致。

端口约定：
    key_event、key_state 必须接 key_filter 的输出（已经消抖）。
        key_event 为单周期脉冲，按下和松开时都会出现；
        key_event && key_state 才是“按下”，松开时阈值保持不变。
        key_event 必须是单周期脉冲：若人为保持多拍，本模块会连续加多次
        （与源码行为一致，源码也没有做边沿检测）。
    threshold_mm 为 13 位毫米值，可直送报警模块：
        alarm = alarm_enable && (distance_mm < threshold_mm);  // 100cm -> 13'd1000

顶层连接示例：
    wire        key_event_th;      // 阈值按键消抖后的事件脉冲
    wire        key_state_th;      // 阈值按键消抖后的电平
    wire [12:0] threshold_mm;

    key_filter u_key_filter_th (
        .sys_clk    (sys_clk),
        .sys_rst_n  (sys_rst_n),
        .key_in     (key_th),
        .key_event  (key_event_th),
        .key_state  (key_state_th),
        .led_toggle (led_th)
    );

    key_cnt u_key_cnt (
        .sys_clk      (sys_clk),
        .sys_rst_n    (sys_rst_n),
        .key_event    (key_event_th),
        .key_state    (key_state_th),
        .threshold_mm (threshold_mm)
    );
===============================================================================
*/

module key_cnt #(
    parameter [12:0] INITIAL_MM = 13'd1000,   // 上电默认阈值 100cm
    parameter [12:0] MAX_MM     = 13'd2000    // 阈值上限 200cm
)(
    input  wire        sys_clk,
    input  wire        sys_rst_n,
    input  wire        key_event,
    input  wire        key_state,
    output reg  [12:0] threshold_mm
);

    // 每次按键的步进：1cm = 10mm（源码中每按一次阈值 +1cm）。
    localparam [12:0] STEP_MM = 13'd10;

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            threshold_mm <= INITIAL_MM;
        else if (key_event && key_state) begin
            // key_state=1 说明本次事件是“按下”，松开时产生的事件不计数。
            if (threshold_mm >= MAX_MM)
                threshold_mm <= STEP_MM;                  // 到 200cm 后再按回到 1cm
            else
                threshold_mm <= threshold_mm + STEP_MM;   // 每次 +1cm
        end
    end

endmodule