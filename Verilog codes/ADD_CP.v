/*
 * [TX] 循环前缀添加模块
 * 在发送端将每个 OFDM 符号末尾的 LCP 个采样复制到开头，形成循环前缀。
 * CLK_I 用于接收 IFFT 输出数据，CLK_II 用于输出加前缀后的数据。
 *
 * 端口说明:
 *   CLK_I, CLK_II : 输入/输出时钟
 *   RST_I         : 异步复位信号
 *   DAT_I_r/i     : IFFT 输出的实部/虚部
 *   ACK_I         : 输入数据有效指示
 *   DAT_O_r/i     : 添加前缀后的复数数据
 *   dout_r/i      : 输出数据有效指示
 *   delete_en     : 一帧数据写满标志, 供后级删除前缀模块使用
 */
module ADD_CP(
        input                   CLK_I, CLK_II, RST_I,
        input  [15:0]           DAT_I_r, DAT_I_i,
        input                   ACK_I,

        output reg [15:0]       DAT_O_r, DAT_O_i,
        output reg              dout_r, dout_i,
        output reg              delete_en
    );

// 循环前缀长度和有效符号长度
parameter LCP  = 16;
parameter NFFT = 48;

// 双缓冲区用于交替存储两帧数据, 数组第 64 位作为当前缓冲区标志位
reg [15:0] send1_r[64:0], send1_i[64:0];
reg [15:0] send2_r[64:0], send2_i[64:0];

// 输入计数, 分别统计 I/Q 两路写入数量
reg [9:0] dat_cnt_r, dat_cnt_i;

reg [31:0] i; // 复位时的循环变量

// 判断当前写入位置是否处于 CP 或完整符号范围
wire inCP_r  = dat_cnt_r <= NFFT;
wire infrm_r = dat_cnt_r <= NFFT + LCP;
wire inCP_i  = dat_cnt_i <= NFFT;
wire infrm_i = dat_cnt_i <= NFFT + LCP;

// 写入阶段握手: ACK_I 置位后保持, 直至一次写入完成
reg ACK_en = 0;
always @(*) begin
    if (ACK_I)
        ACK_en <= 1;
end

// -----------------------------------------
// 接收 IFFT 输出并存入缓冲区 (CLK_I 时钟域)
// -----------------------------------------
always @(posedge CLK_I or posedge RST_I) begin
    if (RST_I) begin
        dat_cnt_r <= 10'd0;
        dat_cnt_i <= 10'd0;
        for(i = 0; i < 64; i = i + 1) begin
            send1_r[i] <= 0;
            send1_i[i] <= 0;
            send2_r[i] <= 0;
            send2_i[i] <= 0;
        end
        // 初始时交替标志清零
        send1_r[64] <= 0;
        send2_r[64] <= 32'hffffffff;
        send1_i[64] <= 0;
        send2_i[64] <= 32'hffffffff;
    end else if (ACK_en) begin
        delete_en <= ACK_I; // 通知后级可以开始删除前缀
        // ------ 实部写入 ------
        if (inCP_r) begin
            // 写入 CP 区域数据
            if (send1_r[64]) begin
                send1_r[dat_cnt_r] <= DAT_I_r;
                dat_cnt_r <= dat_cnt_r + 1'b1;
            end else if (send2_r[64]) begin
                send2_r[dat_cnt_r] <= DAT_I_r;
                dat_cnt_r <= dat_cnt_r + 1'b1;
            end
        end else if (infrm_r) begin
            // 写入完整符号
            if (dat_cnt_r < NFFT + LCP) begin
                if (send1_r[64]) begin
                    send1_r[dat_cnt_r] <= DAT_I_r;
                    dat_cnt_r <= dat_cnt_r + 1;
                end else if (send2_r[64]) begin
                    send2_r[dat_cnt_r] <= DAT_I_r;
                    dat_cnt_r <= dat_cnt_r + 1;
                end
                if (dat_cnt_r == NFFT + LCP - 1) begin
                    dat_cnt_r <= 10'd0;
                    send1_r[64] <= ~send1_r[64];
                    send2_r[64] <= ~send2_r[64];
                end
            end
        end
        // ------ 虚部写入 ------
        if (inCP_i) begin
            if (send1_i[64]) begin
                send1_i[dat_cnt_i] <= DAT_I_i;
                dat_cnt_i <= dat_cnt_i + 1'b1;
            end else if (send2_i[64]) begin
                send2_i[dat_cnt_i] <= DAT_I_i;
                dat_cnt_i <= dat_cnt_i + 1'b1;
            end
        end else if (infrm_i) begin
            if (dat_cnt_i < NFFT + LCP) begin
                if (send1_i[64]) begin
                    send1_i[dat_cnt_i] <= DAT_I_i;
                    dat_cnt_i <= dat_cnt_i + 1;
                end else if (send2_i[64]) begin
                    send2_i[dat_cnt_i] <= DAT_I_i;
                    dat_cnt_i <= dat_cnt_i + 1;
                end
                if (dat_cnt_i == NFFT + LCP - 1) begin
                    dat_cnt_i <= 10'd0;
                    send1_i[64] <= ~send1_i[64];
                    send2_i[64] <= ~send2_i[64];
                end
            end
        end
    end else begin
        dat_cnt_r <= 10'd0;
        dat_cnt_i <= 10'd0;
    end
end

// -----------------------------------------
// 输出带循环前缀的数据 (CLK_II 时钟域)
// -----------------------------------------
reg [31:0] word_cnt_r, word_cnt_i;
reg [31:0] sum_r, sum_i; // 输出计数
reg [31:0] sym_r, sym_i; // 帧起始标志

always @(posedge CLK_II or posedge RST_I) begin
    if (RST_I) begin
        word_cnt_r <= 0;
        word_cnt_i <= 0;
        sum_r <= 0;
        sum_i <= 0;
        sym_r <= 0;
        sym_i <= 0;
    end else begin
        // ---------- 实部输出 ----------
        if (dat_cnt_r == 48)
            sym_r <= 1;
        if ((dat_cnt_r > 48 && dat_cnt_r < 64) || (dat_cnt_r == 0 && sym_r)) begin
            if (sum_r == 31) begin
                sum_r <= 0;
                dout_r <= 1;
            end else begin
                DAT_O_r <= DAT_I_r; // 直接透传有效数据
                sum_r <= sum_r + 1;
            end
        end
        if (dout_r) begin
            if (~send1_r[64]) begin
                DAT_O_r <= send1_r[word_cnt_r];
                word_cnt_r <= word_cnt_r + 1;
            end else if (~send2_r[64]) begin
                DAT_O_r <= send2_r[word_cnt_r];
                word_cnt_r <= word_cnt_r + 1;
            end
            if (word_cnt_r == LCP + NFFT - 1) begin
                word_cnt_r <= 10'd0;
                dout_r <= 0;
            end
        end
        // ---------- 虚部输出 ----------
        if (dat_cnt_i == 48)
            sym_i <= 1;
        if ((dat_cnt_i > 48 && dat_cnt_i < 64) || (dat_cnt_i == 0 && sym_i)) begin
            if (sum_i == 31) begin
                sum_i <= 0;
                dout_i <= 1;
            end else begin
                DAT_O_i <= DAT_I_i;
                sum_i <= sum_i + 1;
            end
        end
        if (dout_i) begin
            if (~send1_i[64]) begin
                DAT_O_i <= send1_i[word_cnt_i];
                word_cnt_i <= word_cnt_i + 1;
            end else if (~send2_i[64]) begin
                DAT_O_i <= send2_i[word_cnt_i];
                word_cnt_i <= word_cnt_i + 1;
            end
            if (word_cnt_i == LCP + NFFT - 1) begin
                word_cnt_i <= 10'd0;
                dout_i <= 0;
            end
        end
    end
end

endmodule
