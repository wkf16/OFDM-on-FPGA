# 文件概览

本文档总结了项目中各个源文件的作用，并列出主要输入、输出以及模块间的依赖关系。
HDL 源文件位于 `Verilog codes` 文件夹中，整体设计的最高层模块为 `OFDM.v`。

## Verilog 模块

| 文件 | 模块 | 功能说明 | 主要输入 | 主要输出 | 依赖 |
| ---- | ------ | ---------- | ---------- | ---------- | ------ |
| `ADD_CP.v` | `ADD_CP` | 给 IFFT 输出添加循环前缀 | `CLK_I`, `CLK_II`, `RST_I`, `DAT_I_r/i`, `ACK_I` | `DAT_O_r/i`, `dout_r/i`, `delete_en` | 内部存储器 |
| `CP_TEST.v` | `CP_test` | 将 `ADD_CP` 与 `DELETE_CP` 串接的示例 | `sysclk`, `RST_I`, `DAT1_I_r/i`, `ACK_I` | `DAT2_O_r/i`, `ACK_O` | `CLK`, `ADD_CP`, `DELETE_CP` |
| `Decoder.v` | `Decoder` | 解码解调后的信号 | `clk`, `reset`, `in[1:0]`, `demod_en` | `out[3:0]` | 内部状态 |
| `DELETE_CP.v` | `DELETE_CP` | 去除循环前缀 | `CLK_I`, `CLK_II`, `RST_I`, `DAT_I_r/i`, `din_r/i` | `DAT_O_r/i`, `ACK_O` | 内部 FIFO |
| `DelayBuffer.v` | `DelayBuffer` | 固定长度的延时线 | `clock`, `di_re/im` | `do_re/im` | 无 |
| `FFT64.v` | `FFT64` | 基于 radix-2^2 SDF 的 64 点 FFT | `clock`, `reset`, `di_en`, `di_re/im` | `do_en`, `do_re/im` | `SdfUnit` |
| `IFFT64.v` | `IFFT64` | 由 `FFT64` 构建的 64 点 IFFT | `clock`, `reset`, `di_en`, `di_re/im` | `do_en`, `do_re/im` | `FFT64` |
| `Multiply.v` | `Multiply` | FFT 内部使用的复数乘法器 | `a_re/im`, `b_re/im` | `m_re/im` | 无 |
| `Twiddle64.v` | `Twiddle` | 64 个旋转因子查找表 | `clock`, `addr[5:0]` | `tw_re/im` | 无 |
| `Butterfly.v` | `Butterfly` | FFT 的基本加/减操作阶段 | `x0_re/im`, `x1_re/im` | `y0_re/im`, `y1_re/im` | 无 |
| `SdfUnit.v` | `SdfUnit` | Radix-2^2 单路延时反馈处理单元 | `clock`, `reset`, `di_en`, `di_re/im` | `do_en`, `do_re/im` | `Butterfly`, `Multiply`, `DelayBuffer`, `Twiddle64` |
| `fft_register.v` | `FFT_Register` | IFFT 前缓存 64 个 QPSK 符号 | `clk`, `reset`, `inx`, `iny`, `mod_en` | `out_en`, `outx`, `outy` | 无 |
| `Mod.v` | `Mod` | QPSK 调制器 | `clk`, `reset`, `in`, `encoder_en` | `en`, `outx`, `outy` | 无 |
| `De_Mod.v` | `De_Mod` | QPSK 解调器 | `clk`, `reset`, `inx`, `iny`, `fft_en` | `en`, `out[1:0]` | 无 |
| `Encoder.v` | `Encoder` | 卷积编码器 | `clk`, `reset`, `in` | `out`, `out_esig` | 内部矩阵 |
| `CLK.v` | `CLK` | CP 测试使用的简易分频时钟 | `sys_clk`, `reset` | `clk` | 无 |
| `OFDM.v` | `OFDM` | **顶层 OFDM 收发器** | `clk`, `reset`, `x_in` | `x_out[3:0]` | `Encoder`, `Mod`, `FFT_Register`, `IFFT64`, `FFT64`, `De_Mod`, `Decoder` |
| `tb_OFDM.v` | `tb_ofdm` | `OFDM` 的测试平台 | 模拟信号 | 无 | `OFDM` |

## MATLAB 与 Simulink

`MATLAB CODE` 文件夹提供用于算法仿真的脚本（`ofdm_final2.m`，`recive1.m`，`test1_all.m`，`transmit1.m`）。`Simulink files` 文件夹中包含与 HDL 设计对应的模型 `OFDM.slx`。

## 顶层模块

本设计的顶层 RTL 模块为 `OFDM.v`。其他 Verilog 文件实现下级处理块（FFT、调制、循环前缀处理等）或用作测试程序。提供的测试文件 `tb_OFDM.v` 用于实例化该顶层模块进行仿真。

