`timescale 1ns / 1ps

/*
===============================================================================
模块名称：max_min

说明：
    源码文件为 Max_Min.v，模块名写作 Max_Min。按图片中“模块名统一”的要求，
    改为与 ultrasound_ctrl、bin_to_bcd、display、key_filter、key_cnt 一致的
    小写下划线风格 max_min；逻辑、参数和端口位宽均未改动，只统一了接口。
    顶层例化时写 max_min；若工程里已经按旧名 Max_Min 例化，需同步修改。

模块用途：
    在扫描模式开启期间，记录所有有效距离中的最大值和最小值。

接口对齐（接口说明第 6 节“最值统计”）：
    必须使用均值滤波的输出 avg_mm 和 avg_valid，不能用原始 distance_valid。
    原因：avg_mm 与 avg_valid 由均值模块在同一个时钟上升沿更新，
    avg_valid=1 的那一拍 avg_mm 已经是新平均值，本模块在这一拍采样正好
    得到新值；若改用原始 distance_valid 选通，会在平均值更新之前采样，
    得到的是上一次的平均值（少一拍）。
    因此源码中的 distance_mm / distance_valid 端口改名为 avg_mm / avg_valid，
    条件判断和更新逻辑逐行保持原样。

端口约定：
    scan_enable  高电平 = 本轮扫描统计中；拉低则清零，等待下一轮。
    avg_valid    单周期脉冲，来自均值滤波（为 1 的那一拍 avg_mm 有效）。
    avg_mm       13 位毫米平均值，与 avg_valid 同拍更新。
    max_mm       最大值；复位或 scan_enable=0 时清 0。
    min_mm       最小值；复位或 scan_enable=0 时置为 MAX_VALID_MM。
                 尚未统计到有效样本时 min_mm 会保持 4000mm（显示 400.0），
                 这是源码行为，本次未改动。

关键设计原则：
    本模块比较的是二进制毫米值，而不是 BCD。
    BCD 只用于显示，不适合直接与普通二进制常量比较。

工作过程：
    scan_enable=0：清除本次扫描结果，等待下一次扫描。
    scan_enable=1 且 avg_valid=1：在合法窗口内更新最大值和最小值。
    仅接受 20mm~4000mm 的合理数据，过滤 0（无回波）和明显异常回波。

顶层接法：
    均值滤波的输出 avg_mm / avg_valid 直接接本模块同名端口，不要用原始
    distance_mm / distance_valid；avg_valid 必须只保持一个时钟周期。
===============================================================================
*/

module max_min #(
    parameter [12:0] MIN_VALID_MM = 13'd20,
    parameter [12:0] MAX_VALID_MM = 13'd4000
)(
    input  wire        sys_clk,
    input  wire        sys_rst_n,
    input  wire        scan_enable,
    input  wire        avg_valid,
    input  wire [12:0] avg_mm,
    output reg  [12:0] max_mm,
    output reg  [12:0] min_mm
);

    // 合法性窗口：滤掉 0（无回波）和明显异常的回波。
    wire avg_in_range = (avg_mm >= MIN_VALID_MM) &&
                        (avg_mm <= MAX_VALID_MM);

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            max_mm <= 13'd0;
            min_mm <= MAX_VALID_MM;
        end else if (!scan_enable) begin
            // 每次关闭扫描都清零，下次打开会开始一轮新的统计。
            max_mm <= 13'd0;
            min_mm <= MAX_VALID_MM;
        end else if (avg_valid && avg_in_range) begin
            // 只统计合法样本；avg_mm 与 avg_valid 同拍，采到的就是新平均值。
            if (avg_mm > max_mm)
                max_mm <= avg_mm;
            if (avg_mm < min_mm)
                min_mm <= avg_mm;
        end
    end

endmodule