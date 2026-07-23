# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a RISC-V 5-stage pipelined processor implemented in SystemVerilog, targeting the **Basys-3 FPGA** board. The design follows the classic Patterson & Hennessy pipeline: **IF → ID → EX → MEM → WB**. The datapath is 32-bit (`DATA_WIDTH=32`, RV32); the PC is kept 64-bit (`NB_PC=64`). The synthesis top (`RiscvTop`) exposes a UART interface (`i_rx`/`o_tx`) for loading programs and interacting with the processor.

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
- `IF_ID_Buffer` — latches PC+4 and the fetched instruction between IF and ID.
- `ID_EX_Buffer` — latches all ID outputs (PC+4, rs1/rs2 data, immediate, rd, funct3/7, control signals) for the EX stage.
- `EX_MEM_Buffer` — latches ALU result, zero flag, rs2 data (stores), rd, and MEM/WB control signals.
- `MEM_WB_Buffer` — latches ALU result, memory read data, rd, and WB control signals.

**Generic building blocks** (`src/sources_1/Generic/`):
- `PosEdgeRegister` — parameterized `always_ff` flip-flop with synchronous reset and enable; used as the primitive for all pipeline registers and the PC.
- `Adder` — parameterized combinational adder (PC+4 increment and branch-target computation).
- `mux1_2`, `mux2_4`, `mux3_8` — parameterized 2-, 4-, and 8-input muxes.

**Pipeline core:** `src/sources_1/Top/riscv.sv` — `RISCV` module (clock, reset, UART RX/TX); all pipeline stages are instantiated here.
**Synthesis top:** `src/sources_1/Top/RiscvTop.sv` — `RiscvTop` SoC = pipeline core + `Uart` (`src/sources_1/UART/`) + `DebugUnit` (`src/sources_1/Debug/DebugUnit.sv`) + a Clock Wizard IP (`clk_wiz_0`) clocking the SoC at 75 MHz. The `CLK` parameter (`75_000_000`) must match the actual clock output so the UART baud divisor stays calibrated; a reset bridge holds reset asserted until the clock locks.

### Key Design Conventions

- **Language:** SystemVerilog. Use `logic` instead of `reg`/`wire`, `always_ff` for sequential, `always_comb` for combinational. Never use plain `always`.
- **Port naming:** `i_` prefix for inputs, `o_` prefix for outputs, `w_` prefix for internal wires, `r_` prefix for registers/state.
- **Parameterization:** All widths (PC, instruction, register address, data) are parameters; default is 32-bit. Do not hardcode widths.
- **Instruction memory:** array of `2^NB_ADDR` 32-bit words. The PC is **byte-addressed**, so the fetch indexes the array with `PC >> 2` (`i_PC[NB_ADDR+1:2]`). Loaded from `program.hex` via `$readmemh` at simulation init (debug write port still uses word indices); in hardware the program is loaded over UART. **The memories are not cleared on reset** — the synchronous reset branch was removed from `InstructionMemory.sv`/`DataMemory.sv` so the arrays infer BRAM (this is what closed timing at 75 MHz; see Timing below).
- **PC increment unit:** Adds 4 (byte-addressed), aligned with Patterson & Hennessy — the PC indexes bytes. Branch/jump immediates from `ImmediateExtend` are byte offsets and are added to the PC directly (no shift). See [`docs/utils/CONSIDERACIONES.md`](docs/utils/CONSIDERACIONES.md).

### Testbenches

Located in `src/sim_1/` (**138 tests across 14 testbenches**, all passing). The suite auto-discovers sources under `src/sources_1/**/*.sv` and benches under `src/sim_1/**/tb_*.sv` — adding a stage needs no script changes. Run via the `run-tests` skill or `bash .claude/skills/run-tests/scripts/run_tests.sh`:
- `ID/tb_RegisterFile.sv`, `ID/tb_ImmediateExtend.sv`, `ID/tb_ControlUnit.sv` — ID sub-modules.
- `EX/tb_ALU.sv`, `EX/tb_ExecuteStage.sv`, `EX/tb_lui_bug.sv` — EX stage + LUI regression.
- `MEM/tb_DataMemory.sv`, `Buffers/tb_Buffers.sv`, `Hazard/tb_Forwarding.sv` — MEM, buffers, forwarding/stall.
- `Integrador/tb_IF_to_WB.sv`, `Integrador/tb_branch.sv`, `Integrador/tb_step_branch.sv` — full pipeline + branch/jump + step-mode branch integration.
- `Debug/tb_DebugUnit.sv`, `Debug/tb_RiscvDebug.sv` — DebugUnit FSM and `RiscvTop` SoC end-to-end.

## Git Conventions

Commits go directly to `master`. Commit messages must be brief and in English, using the conventional commit format:

```
type(scope): short description
```

Common types: `feat`, `fix`, `refactor`, `test`, `chore`, `docs`.

Do not add `Co-Authored-By` or any mention that the commit was written by Claude.

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

**Current progress:** Stages 0–11 are DONE and **validated on the physical Basys-3** (UART, program load, continuous + step-by-step debug, timing closed). A Clock Wizard IP in `RiscvTop` clocks the whole SoC at **75 MHz** with full setup **and** hold closure (WNS +0.634 ns, WHS +0.074 ns; see `docs/reports/report-timing-75mhz.md`). The datapath is **`DATA_WIDTH=32`** (RV32); the PC stays 64-bit (`NB_PC=64`). Stage 10 operating modes are covered by the DebugUnit FSM (no separate doc).
