# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a RISC-V 5-stage pipelined processor implemented in Verilog, targeting the **Basys-3 FPGA** board. The design follows the classic Patterson & Hennessy pipeline: **IF → ID → EX → MEM → WB**. The top-level module (`RISCV`) exposes a UART interface (`i_rx`/`o_tx`) for loading programs and interacting with the processor.

## Toolchain

The project uses **Xilinx Vivado** for synthesis, simulation, and FPGA programming. There is no Makefile; all build/sim operations go through the Vivado GUI or `vivado -mode tcl`.

**Running a simulation (Vivado GUI):**
1. Open `project_1/project_1.xpr` in Vivado.
2. Set the desired testbench as the active simulation source.
3. Run Simulation → Run Behavioral Simulation.

**Running a specific testbench from CLI:**
```bash
mkdir -p sim_out && cd sim_out
xvlog --sv ../src/sources_1/**/*.sv ../src/sim_1/<tb_dir>/<tb_file>.sv
xelab -debug typical <top_module> -s sim_snapshot
xsim sim_snapshot --runall
```

All build artifacts (`xsim.dir/`, `work/`, `*.log`, `*.pb`, `webtalk*`) land in `sim_out/` and are git-ignored.

The `program.hex` file loaded into `InstructionMemory` at simulation start must be present in the xsim working directory (Vivado copies it automatically when launched from the project).

## Architecture

### Pipeline Stages & Module Map

| Stage | Module | File |
|-------|--------|------|
| IF | `InstructionFetch` | `src/sources_1/IF/InstructionFetch.sv` |
| ID | `instructionDecode` | `src/sources_1/ID/InstructionDecode.sv` |
| EX | `ExecuteStage` | `src/sources_1/EX/ExecuteStage.sv` |
| MEM | `MemoryAccessStage` | `src/sources_1/MEM/MemoryAccessStage.sv` |
| WB | `WriteBackStage` | `src/sources_1/WB/WriteBackStage.sv` |

**Pipeline buffers** (in `src/sources_1/Buffers/`):
- `IF_ID_Buffer` — latches PC+1 and the fetched instruction between IF and ID.
- `ID_EX_Buffer` — latches all ID outputs (PC+1, rs1/rs2 data, immediate, rd, funct3/7, control signals) for the EX stage.
- `EX_MEM_Buffer` — latches ALU result, zero flag, rs2 data (stores), rd, and MEM/WB control signals.
- `MEM_WB_Buffer` — latches ALU result, memory read data, rd, and WB control signals.

**Generic building blocks** (`src/sources_1/Generic/`):
- `PosEdgeRegister` — parameterized `always_ff` flip-flop with synchronous reset and enable; used as the primitive for all pipeline registers and the PC.
- `Adder` — parameterized combinational adder (used for PC+1 increment).
- `mux1_2`, `mux2_4`, `mux3_8` — parameterized 2-, 4-, and 8-input muxes.

**Pipeline core:** `src/sources_1/Top/riscv.sv` — `RISCV` module (clock, reset, UART RX/TX); all pipeline stages are instantiated here.
**Synthesis top:** `src/sources_1/Top/RiscvTop.sv` — `RiscvTop` SoC = pipeline core + `Uart` (`src/sources_1/UART/`) + `DebugUnit` (`src/sources_1/Debug/DebugUnit.sv`) + MMCM clocking the SoC at 65 MHz.

### Key Design Conventions

- **Language:** SystemVerilog. Use `logic` instead of `reg`/`wire`, `always_ff` for sequential, `always_comb` for combinational. Never use plain `always`.
- **Port naming:** `i_` prefix for inputs, `o_` prefix for outputs, `w_` prefix for internal wires, `r_` prefix for registers/state.
- **Parameterization:** All widths (PC, instruction, register address, data) are parameters; default is 32-bit. Do not hardcode widths.
- **Instruction memory:** array of `2^NB_ADDR` 32-bit words. The PC is **byte-addressed**, so the fetch indexes the array with `PC >> 2` (`i_PC[NB_ADDR+1:2]`). Loaded from `program.hex` via `$readmemh` at simulation init (debug write port still uses word indices). At reset, the memory is zeroed (program re-loaded via UART in hardware).
- **PC increment unit:** Adds 4 (byte-addressed), aligned with Patterson & Hennessy — the PC indexes bytes. Branch/jump immediates from `ImmediateExtend` are byte offsets and are added to the PC directly (no shift). See [`docs/CONSIDERACIONES.md`](docs/CONSIDERACIONES.md).

### Testbenches

Located in `src/sim_1/` (**129 tests across 13 testbenches**, all passing). Run via the `run-tests` skill or `bash .claude/skills/run-tests/scripts/run_tests.sh`:
- `ID/tb_RegisterFile.sv`, `ID/tb_ImmediateExtend.sv`, `ID/tb_ControlUnit.sv` — ID sub-modules.
- `EX/tb_ALU.sv`, `EX/tb_ExecuteStage.sv`, `EX/tb_lui_bug.sv` — EX stage + LUI regression.
- `MEM/tb_DataMemory.sv`, `Buffers/tb_Buffers.sv`, `Hazard/tb_Forwarding.sv` — MEM, buffers, forwarding/stall.
- `Integrador/tb_IF_to_WB.sv`, `Integrador/tb_branch.sv` — full pipeline + branch/jump integration.
- `Debug/tb_DebugUnit.sv`, `Debug/tb_RiscvDebug.sv` — DebugUnit FSM and `RiscvTop` SoC end-to-end.

## Git Conventions

Commits go directly to `master`. Commit messages must be brief and in English, using the conventional commit format:

```
type(scope): short description
```

Common types: `feat`, `fix`, `refactor`, `test`, `chore`, `docs`.

Do not add `Co-Authored-By` or any mention that the commit was written by Claude.

Do not commit files under `plans/` — they are working notes, not part of the source history.

### Branch naming → versioning

| Branch prefix | Effect |
|---------------|--------|
| `feature/*`, `feat/*` | minor version bump |
| `fix/*`, `hotfix/*` | patch version bump |
| `release/*` | major version bump |
| `doc/*`, `docs/*` | no version change or release (documentation only) |
| `chore/*` | patch version bump (minor maintenance) |
| `test/*` | test cases added |

## Implementation Plan

The full staged implementation plan lives in [`plans/plan.md`](plans/plan.md). It covers stages 0–11 (bug fixes → Control Unit → ALU/EX → Buffers → MEM → WB → Hazard/Forwarding → Branch/Jump → UART/Debug → Operating Modes → Timing). Check that file for current stage status, per-stage deliverables, and detail files (`plans/stageN.md`).

**Current progress:** Stages 0–11 are DONE and **validated on the physical Basys-3** (UART, program load, continuous + step-by-step debug, timing closed). The design did not close timing at 100 MHz, so an MMCM in `RiscvTop` clocks the whole SoC at **65 MHz** (the max reliable frequency with the 32-bit datapath; see `docs/report-fmax-sweep-dw32-20260629.md`). 60/50 MHz also work with more margin. The datapath is **`DATA_WIDTH=32`** (RV32); the PC stays 64-bit (`NB_PC=64`). Stage 10 operating modes are covered by the DebugUnit FSM (no separate doc).

## Known Issues / WIP

- Synthesis top is `RiscvTop` (`src/sources_1/Top/RiscvTop.sv`); the bare `RISCV` module is the pipeline core. Board bring-up uses `tools/gui/riscv_debug.py`. UART + DebugUnit + step-by-step are validated on the physical Basys-3.
- HALT is a dedicated custom-0 opcode `0x0000000B`; programs must end with it (loader zero-pads, and zeros decode to NOPs). See `docs/CONSIDERACIONES.md` C-004.
- **Timing (Stage 11, DONE):** the dump path core→DebugUnit crosses `posedge→negedge`, so its budget is **half a period** and it sets the Fmax ceiling (~75 MHz, routing-dominated; see `docs/report-20260628.md`). MMCM in `RiscvTop` runs the whole SoC at **65 MHz** (`CLK` param = 65e6, WNS +0.319 ns). Narrowing the datapath to `DATA_WIDTH=32` cut LUTs ~32% and raised the reliable Fmax from 60→65 MHz, but did **not** reach 100 MHz: the timing ceiling is the dump path (unaffected by data width) and above ~70 MHz timing-driven register replication explodes *control sets* (~8000), saturating slices (~99%) and making placement irreproducible. To push past 75 MHz you must register/re-clock the dump path or move data memory to BRAM, not narrow the datapath. See `docs/report-fmax-sweep-dw32-20260629.md` and `plans/stage11.md`.
