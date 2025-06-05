# File Overview

This document summarizes the purpose of each source file in this project. It also lists the main inputs, outputs and module dependencies. The HDL source is located in the `Verilog codes` folder. The top level of the hardware design is `OFDM.v`.

## Verilog Modules

| File | Module | Description | Key Inputs | Key Outputs | Depends on |
| ---- | ------ | ----------- | ---------- | ----------- | ---------- |
| `ADD_CP.v` | `ADD_CP` | Adds cyclic prefix to IFFT output | `CLK_I`, `CLK_II`, `RST_I`, `DAT_I_r/i`, `ACK_I` | `DAT_O_r/i`, `dout_r/i`, `delete_en` | internal registers |
| `CP_TEST.v` | `CP_test` | Example that chains `ADD_CP` and `DELETE_CP` | `sysclk`, `RST_I`, `DAT1_I_r/i`, `ACK_I` | `DAT2_O_r/i`, `ACK_O` | `CLK`, `ADD_CP`, `DELETE_CP` |
| `Decoder.v` | `Decoder` | Decodes demodulated bits | `clk`, `reset`, `in[1:0]`, `demod_en` | `out[3:0]` | internal state |
| `DELETE_CP.v` | `DELETE_CP` | Removes cyclic prefix | `CLK_I`, `CLK_II`, `RST_I`, `DAT_I_r/i`, `din_r/i` | `DAT_O_r/i`, `ACK_O` | internal FIFOs |
| `DelayBuffer.v` | `DelayBuffer` | Fixed length delay line | `clock`, `di_re/im` | `do_re/im` | none |
| `FFT64.v` | `FFT64` | 64‑point FFT using radix‑2² SDF | `clock`, `reset`, `di_en`, `di_re/im` | `do_en`, `do_re/im` | `SdfUnit` |
| `IFFT64.v` | `IFFT64` | 64‑point IFFT built from `FFT64` | `clock`, `reset`, `di_en`, `di_re/im` | `do_en`, `do_re/im` | `FFT64` |
| `Multiply.v` | `Multiply` | Complex multiplier used inside FFT | `a_re/im`, `b_re/im` | `m_re/im` | none |
| `Twiddle64.v` | `Twiddle` | Lookup table of 64 twiddle factors | `clock`, `addr[5:0]` | `tw_re/im` | none |
| `Butterfly.v` | `Butterfly` | Basic add/sub stage of FFT | `x0_re/im`, `x1_re/im` | `y0_re/im`, `y1_re/im` | none |
| `SdfUnit.v` | `SdfUnit` | Radix‑2² single‑path delay feedback processing unit | `clock`, `reset`, `di_en`, `di_re/im` | `do_en`, `do_re/im` | `Butterfly`, `Multiply`, `DelayBuffer`, `Twiddle64` |
| `fft_register.v` | `FFT_Register` | Captures 64 QPSK symbols before IFFT | `clk`, `reset`, `inx`, `iny`, `mod_en` | `out_en`, `outx`, `outy` | none |
| `Mod.v` | `Mod` | QPSK modulator | `clk`, `reset`, `in`, `encoder_en` | `en`, `outx`, `outy` | none |
| `De_Mod.v` | `De_Mod` | QPSK demodulator | `clk`, `reset`, `inx`, `iny`, `fft_en` | `en`, `out[1:0]` | none |
| `Encoder.v` | `Encoder` | Convolutional encoder for input bits | `clk`, `reset`, `in` | `out`, `out_esig` | internal matrices |
| `CLK.v` | `CLK` | Simple clock divider used by CP testbench | `sys_clk`, `reset` | `clk` | none |
| `OFDM.v` | `OFDM` | **Top level OFDM transmitter/receiver** | `clk`, `reset`, `x_in` | `x_out[3:0]` | `Encoder`, `Mod`, `FFT_Register`, `IFFT64`, `FFT64`, `De_Mod`, `Decoder` |
| `tb_OFDM.v` | `tb_ofdm` | Testbench for `OFDM` | simulation signals | none | `OFDM` |

## MATLAB and Simulink

The `MATLAB CODE` folder contains MATLAB scripts (`ofdm_final2.m`, `recive1.m`, `test1_all.m`, `transmit1.m`) used for algorithm simulation. The `Simulink files` folder provides a Simulink model `OFDM.slx` that corresponds to the HDL design.

## Top Level

The design’s top level RTL module is `OFDM.v`. All other Verilog files either implement lower‑level processing blocks (FFT, modulation, cyclic prefix processing) or are helper test modules. The provided testbench `tb_OFDM.v` instantiates this top level.

