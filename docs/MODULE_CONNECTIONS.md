# 模块连接关系

本文描述 `Verilog codes` 目录下各个模块在完整 OFDM 收发链路中的连接顺序与信号流向，便于理解系统整体结构。顶层模块为 `OFDM.v`，其内部按照发送（TX）与接收（RX）两条路径组织。

## 发送路径（TX）
1. **Encoder**：接收外部输入比特 `x_in`，产生卷积编码后的比特流 `encoder_out`，并输出使能信号 `encoder_esig`。
2. **Mod**：根据编码器输出，在 `encoder_esig` 作用下将比特映射为 QPSK 符号 `(mod_outx, mod_outy)` 并产生 `mod_en`。
3. **FFT_Register**：缓存 64 个调制后的符号，累满后以 `reg_out_en` 使能方式依次输出到 IFFT。
4. **IFFT64**：对缓存数据执行 64 点 IFFT，得到时域复数序列 `(ifft_out_re, ifft_out_im)`，输出使能 `ifft_en`。
5. **ADD_CP**：在 IFFT 结果前端插入循环前缀，输出 `(DAT_O_r, DAT_O_i)`；在示例 `OFDM.v` 中该模块默认处于注释状态，可通过 `CP_TEST.v` 与 `DELETE_CP.v` 配合测试。
6. **(可选) CP_TEST/DELETE_CP**：当包含循环前缀测试链路时，`CP_TEST` 实例内部串联 `ADD_CP` 与 `DELETE_CP`，用于验证前缀添加与去除功能。

## 接收路径（RX）
1. **FFT64**：在示例中直接对 IFFT 输出执行 FFT（若启用循环前缀则应先经过 `DELETE_CP`）。输出复数序列 `(fft_out_re, fft_out_im)` 和使能 `fft_en`。
2. **De_Mod**：将 FFT 输出解映射为 QPSK 符号 `demod_out`，并产生 `demod_en`。
3. **Decoder**：在 `demod_en` 触发下对解调结果执行卷积解码，恢复原始比特流 `x_out`。

## 顶层 `OFDM.v`
- 实例化并按上述顺序连接所有核心模块。
- 时钟、复位等控制信号在顶层统一分配。
- 若需要使用循环前缀功能，可取消对 `CP_TEST` 的注释或直接实例化 `ADD_CP`、`DELETE_CP` 模块。

下图为典型连接关系的文字描述：

```
x_in → Encoder → Mod → FFT_Register → IFFT64 → (ADD_CP → DELETE_CP) → FFT64 → De_Mod → Decoder → x_out
```

文档展示了模块之间的主要数据流向和功能层次，便于进一步理解源码的层次与依赖关系。
