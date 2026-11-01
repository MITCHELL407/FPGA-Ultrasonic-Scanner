// 超声波测距系统顶层模块
module ultrasound_meter (
    input                   sys_clk,             // 100 MHz
    input                   sys_rst_n,           // 低电平复位
    input                   echo,                // 超声波回响信号
    output                  trig,                // 超声波触发信号
    input                   ultrasound_switch,
    output                  beep,
    output                  led1,

    input                   key_in,
    input                   key_cnt_in,

    input                   confirm,
    output                  led_warning,

    input                   key_pwn_req,
    output                  pwm,

    input                   key_scan,            // Max / Min 显示切换

    output      [7:0]       an,                  // 数码管片选信号
    output      [15:0]      seg                  // 数码管段选信号
);

    //============================================================
    // 内部信号
    //============================================================

    wire                led2;
    wire [12:0]         key_cnt;
    wire [15:0]         key_bcd;

    wire                data_flag;
    wire [12:0]         data_bin;
    wire [12:0]         data_ave;
    wire [15:0]         data_bcd;

    wire [15:0]         Max;
    wire [15:0]         Min;

    wire                key_flag;
    wire                key_state;
    wire                key_cnt_flag;
    wire                key_cnt_state;

    wire [15:0]         L_show_num;
    wire [15:0]         H_show_num;

    //============================================================
    // 按键检测与距离阈值设置
    //============================================================

    // 功能按键消抖。
    key_filter key_filter_u0 (
        .sys_clk    (sys_clk),
        .sys_rst_n  (sys_rst_n),
        .key_in     (key_in),
        .key_flag   (key_flag),
        .key_state  (key_state),
        .led        (led1)
    );

    // 距离设置按键消抖。
    key_filter key_filter_u1 (
        .sys_clk    (sys_clk),
        .sys_rst_n  (sys_rst_n),
        .key_in     (key_cnt_in),
        .key_flag   (key_cnt_flag),
        .key_state  (key_cnt_state),
        .led        (led2)
    );

    // 根据按键操作生成设定距离。
    CNT_KEY CNT_KEY_u0 (
        .sys_clk    (sys_clk),
        .sys_rst_n  (sys_rst_n),
        .key_flag   (key_cnt_flag),
        .key_state  (key_cnt_state),
        .key_cnt    (key_cnt)
    );

    //============================================================
    // 超声波测距与均值滤波
    //============================================================

    ultrasound_ctrl u_ultrasound_ctrl (
        .sys_clk      (sys_clk),
        .sys_rst_n    (sys_rst_n),
        .key_flag     (key_flag),
        .key_state    (key_state),
        .switch       (ultrasound_switch),
        .echo         (echo),
        .fall_flag_r1 (data_flag),       // 测量完成标志
        .data_bin     (data_bin),        // 原始测量数据
        .trig         (trig)
    );

    // 对测量数据进行均值滤波。
    ave_filter u_ave_filter (
        .sys_clk    (sys_clk),
        .sys_rst_n  (sys_rst_n),
        .data_bin   (data_bin),
        .data_flag  (data_flag),
        .data_ave   (data_ave)
    );

    //============================================================
    // 数码管数据选择、编码与显示
    //============================================================

    // key_scan 有效时显示最大值和最小值，否则显示当前测量值。
    assign L_show_num = key_scan ? Max : data_bcd;
    assign H_show_num = key_scan ? Min : key_bcd;

    // 当前测量值：二进制转 BCD。
    bin_to_bcd u_bin_to_bcd (
        .sys_clk    (sys_clk),
        .sys_rst_n  (sys_rst_n),
        .data_ave   (data_ave),
        .data_bcd   (data_bcd)
    );

    // 数码管低四位显示。
    display display_u0 (
        .sys_clk    (sys_clk),
        .sys_rst_n  (sys_rst_n),
        .data_bcd   (L_show_num),
        .an         (an[3:0]),
        .seg        (seg[7:0])
    );

    // 设定距离乘以 10 后转换为 BCD。
    bin_to_bcd bin_to_bcd_u1 (
        .sys_clk    (sys_clk),
        .sys_rst_n  (sys_rst_n),
        .data_ave   (key_cnt * 10),
        .data_bcd   (key_bcd)
    );

    // 数码管高四位显示。
    display display_u1 (
        .sys_clk    (sys_clk),
        .sys_rst_n  (sys_rst_n),
        .data_bcd   (H_show_num),
        .an         (an[7:4]),
        .seg        (seg[15:8])
    );

    // 记录测量过程中的最大值和最小值。
    Max_Min Max_Min_u0 (
        .sys_clk    (sys_clk),
        .sys_rst_n  (sys_rst_n),
        .data_bcd   (data_bcd),
        .data_flag  (data_flag),
        .Max        (Max),
        .Min        (Min)
    );

    //============================================================
    // 超限报警
    //============================================================

    LED_warning LED_warning_u0 (
        .sys_clk      (sys_clk),
        .sys_rst_n    (sys_rst_n),
        .key_cnt      (key_cnt),
        .data_ave     (data_ave),
        .confirm      (confirm),         // 开始比较
        .led_warning  (led_warning),
        .beep         (beep)
    );

    //============================================================
    // 舵机角度控制与 PWM 输出
    //============================================================

    reg [7:0]  angle;       // 舵机当前角度
    reg [25:0] angle_cnt;   // 角度更新计数器
    reg        updown;      // 1：角度递增；0：角度递减

    // 每隔 0.1 s 更新一次角度。
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            angle_cnt <= 26'd0;
        end
        else if (angle_cnt == 9_999_999) begin
            angle_cnt <= 26'd0;
        end
        else begin
            angle_cnt <= angle_cnt + 1'b1;
        end
    end

    // 到达角度边界时改变运动方向。
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            updown <= 1'b1;
        end
        else if ((angle_cnt == 9_999_999) && (angle == 30)) begin
            updown <= 1'b0;
        end
        else if ((angle_cnt == 9_999_999) && (angle == 0)) begin
            updown <= 1'b1;
        end
        // 未到达边界时保持原方向。
    end

    // 根据当前方向调整角度。
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            angle <= 8'd15;
        end
        else if ((angle_cnt == 9_999_999) && updown) begin
            angle <= angle + 1'b1;
        end
        else if ((angle_cnt == 9_999_999) && !updown) begin
            angle <= angle - 1'b1;
        end
        // 未到达更新时间时保持当前角度。
    end

    // 根据角度生成 PWM 信号。
    PWM PWM_u0 (
        .sys_clk    (sys_clk),
        .sys_rst_n  (sys_rst_n),
        .angle      (angle),
        .pwm_req    (key_pwn_req),
        .pwm        (pwm)
    );

endmodule
