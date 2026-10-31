`timescale 1ns / 1ps

module ultrasound_ctrl(
    input  wire        sys_clk,        // 100MHz系统时钟，一个时钟周期是10ns
    input  wire        sys_rst_n,      // 低电平有效复位

    input  wire        echo,           // 超声波模块返回的信号。高电平持续时间计算距离
    input  wire        continuous_en,  // 连续测量开关。=1时，每100ms启动一次测量
    input  wire        single_start,   // 如下
 //按一次键→产生一次single_start→控制模块依次发出8次trig→完成8次测距

    output wire        trig,           // 发给超声波模块的触发信号
    output reg  [12:0] distance_mm,    // 二进制距离，单位毫米
    output reg         distance_valid  // 新测量结果有效标志
);

    // 100MHz下，100ms对应10000000个时钟周期 100ms/10ns=10000000
    localparam PERIOD_COUNT = 10_000_000;

    // 100MHz下，10us对应1000个时钟周期
    localparam HIGH_COUNT = 1_000;

    // 一次按键安排8次测量，供后面的均值滤波使用
    localparam BURST_COUNT = 8;




    // trig部分
    
    reg [23:0] period_cnt;   // 记录100ms(10 000 000个时钟)内经过的时钟数
    reg [3:0]  burst_left;   // 本组还剩几个测量周期,还要测几次
    reg        measuring;   //是否正在运行测量周期

    // 每个测量周期的前10us，trig输出高电平
    assign trig = measuring && (period_cnt < HIGH_COUNT);

    always @(posedge sys_clk or negedge sys_rst_n) begin  //每来一个时钟上升沿or要复位
        if (!sys_rst_n) begin  //1.复位时清0
            period_cnt <= 24'd0;
            burst_left <= 4'd0; 
            measuring  <= 1'b0;
        end
        else if (single_start) begin
            // 2.收到启动脉冲，即将开始一组8次测量
            period_cnt <= 24'd0;
            burst_left <= BURST_COUNT;
            measuring  <= 1'b1;
        end
         else if (measuring) begin
         //3.正在测量
            if (period_cnt == PERIOD_COUNT - 1) begin  //每100ms测，一共8次
                period_cnt <= 24'd0;

                if (burst_left > 0)
                    burst_left <= burst_left - 1'b1;

                // 连续模式开启，或者本组还没测完，就继续
                if (continuous_en || (burst_left > 1))
                    measuring <= 1'b1;
                else
                    measuring <= 1'b0;
             end
            else begin
            
                period_cnt <= period_cnt + 1'b1;
            end
        end
        else if (continuous_en) begin
            // 4.空闲时开启连续测量
            period_cnt <= 24'd0;
            measuring  <= 1'b1;
        end
    end


    // echo同步和历史值保存
    reg echo_sync1;
    reg echo_sync2;
    reg echo_last;

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin  //复位
            echo_sync1 <= 1'b0;
            echo_sync2 <= 1'b0;
            echo_last  <= 1'b0;
        end
        else begin
            echo_sync1 <= echo;
            echo_sync2 <= echo_sync1;
            echo_last  <= echo_sync2;
        end
    end

    // 检测同步后的echo是否发生变化
    wire echo_rise;
    wire echo_fall;


   //开始/结束标志
    assign echo_rise =  echo_sync2 && !echo_last;  //上升，现在为1且之前为0
    assign echo_fall = !echo_sync2 &&  echo_last;  //下降，现在为0且之前为1
    
    
    
    //发trig→等echo→统计时间→输出毫米值和有效脉冲
    
        // 最多统计约30ms，避免无效回波导致一直计数
    localparam ECHO_TIMEOUT = 3_000_000;

    reg [21:0] echo_cnt;  // echo高电平持续的时钟数
    reg        counting; // 是否正在统计

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin  //复位
            echo_cnt      <= 22'd0;
            counting      <= 1'b0;
            distance_mm   <= 13'd0;
            distance_valid <= 1'b0;  //告知新结果
        end
        else begin
            // 默认无新结果；测量完成时才置1
            distance_valid <= 1'b0;

            if (echo_rise) begin  //回波开始
                // 已检测到第一个高电平周期
                echo_cnt <= 22'd1;  //计数设1，开始计数
                counting <= 1'b1;
            end
            else if (counting) begin
                if (echo_fall) begin
                    // 回波结束，换算成毫米
                    distance_mm <= (echo_cnt * 32'd17)
                                   / 32'd10000;

                    distance_valid <= 1'b1;
                    counting       <= 1'b0;
                end
                else if (echo_cnt >= ECHO_TIMEOUT) begin
                    // 高电平持续过久，放弃本次结果
                    echo_cnt <= 22'd0;
                    counting <= 1'b0;
                end
                else begin
                    echo_cnt <= echo_cnt + 1'b1;  //计数+1
                end
            end
        end
    end
    
    
endmodule