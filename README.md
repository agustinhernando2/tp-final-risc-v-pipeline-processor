# RISC-V 5-Stage Pipelined Processor

A 5-stage pipelined RISC-V processor implemented in SystemVerilog, targeting the **Basys-3 FPGA** board. The design follows the classic Patterson & Hennessy pipeline: **IF → ID → EX → MEM → WB**, with full data-hazard handling (forwarding + load-use stall).

---

## Architecture Overview

The top-level module (`RISCV`) exposes a UART interface (`i_rx` / `o_tx`) for loading programs and interacting with the processor via a host PC. All five stages are wired end-to-end with forwarding and hazard detection.

---

## Implementation Progress

The full staged plan lives in [`plans/plan.md`](plans/plan.md). Current status:

| Stage | Title | Status |
|-------|-------|--------|
| 0 | Fix existing bugs (`RegisterFile`, `InstructionDecode`) | ✅ Done |
| 1 | Immediate extension (I/S/B/U/J types) | ✅ Done |
| 2 | Control Unit | ✅ Done |
| 3 | EX / ALU | ✅ Done |
| 4 | Pipeline buffers (ID_EX, EX_MEM, MEM_WB) | ✅ Done |
| 5 | Data Memory | ✅ Done |
| 6 | WB + full pipeline wired end-to-end | ✅ Done |
| 7 | Hazard detection + forwarding | ✅ Done |
| 8 | Branch & jump handling | ⬜ Pending |
| 9 | UART & debug unit | ⬜ Pending |
| 10 | Operating modes (continuous / step-by-step) | ⬜ Pending |
| 11 | Timing analysis & frequency optimization | ⬜ Pending |

---

## Module Map

### Pipeline Stages

| Stage | Module | File |
|-------|--------|------|
| IF — Instruction Fetch | `InstructionFetch` | `src/sources_1/IF/InstructionFetch.sv` |
| ID — Instruction Decode | `instructionDecode` | `src/sources_1/ID/InstructionDecode.sv` |
| EX — Execute | `ExecuteStage` | `src/sources_1/EX/ExecuteStage.sv` |
| MEM — Memory Access | `MemoryStage` | `src/sources_1/MEM/MemoryStage.sv` |
| WB — Write Back | `WriteBackStage` | `src/sources_1/WB/WriteBackStage.sv` |

Top level: `src/sources_1/Top/riscv.sv` — `RISCV` module wiring all stages.

### Pipeline Buffers

| Buffer | File |
|--------|------|
| `IF_ID_Buffer` | `src/sources_1/Buffers/IF_ID_Buffer.sv` |
| `ID_EX_Buffer` | `src/sources_1/Buffers/ID_EX_Buffer.sv` |
| `EX_MEM_Buffer` | `src/sources_1/Buffers/EX_MEM_Buffer.sv` |
| `MEM_WB_Buffer` | `src/sources_1/Buffers/MEM_WB_Buffer.sv` |

### Sub-modules

| Module | File |
|--------|------|
| `InstructionMemory` | `src/sources_1/IF/InstructionMemory.sv` |
| `RegisterFile` | `src/sources_1/ID/RegisterFile.sv` |
| `ImmediateExtend` | `src/sources_1/ID/ImmediateExtend.sv` |
| `ControlUnit` | `src/sources_1/ID/ControlUnit.sv` |
| `ALU` | `src/sources_1/EX/ALU.sv` |
| `ALUControl` | `src/sources_1/EX/ALUControl.sv` |
| `DataMemory` | `src/sources_1/MEM/DataMemory.sv` |
| `ForwardingUnit` | `src/sources_1/Hazard/ForwardingUnit.sv` |
| `HazardDetectionUnit` | `src/sources_1/Hazard/HazardDetectionUnit.sv` |

### Generic Building Blocks

| Module | Description |
|--------|-------------|
| `PosEdgeRegister` | Parameterized FF with sync reset and enable |
| `Adder` | Parameterized combinational adder (PC+1) |
| `mux1_2` | 2-input parameterized mux |
| `mux2_4` | 4-input parameterized mux |
| `mux3_8` | 8-input parameterized mux |

---

## Instruction Set Coverage

| Group | Instructions | Opcode | Key signals |
|-------|-------------|--------|-------------|
| R-type | ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU | `0110011` | ALUSrc=0, RegWrite=1 |
| I-arith | ADDI, ANDI, ORI, XORI, SLTI, SLTIU | `0010011` | ALUSrc=1, RegWrite=1 |
| Load | LB, LBU, LH, LHU, LW, LWU | `0000011` | MemRead=1, MemToReg=1 |
| Store | SB, SH, SW | `0100011` | MemWrite=1 |
| Branch | BEQ, BNE | `1100011` | Branch=1, ALUSrc=0 |
| LUI | LUI | `0110111` | ALUSrc=1, RegWrite=1 |
| Jump | JAL | `1101111` | Jump=1, RegWrite=1 |
| Jump-reg | JALR | `1100111` | Jump=1, ALUSrc=1, RegWrite=1 |

> Datapath and control for branch/jump are decoded, but flush logic (Stage 8) is not yet implemented — see Known Issues.

---

## Testbenches

Located in `src/sim_1/`. Run them via the `run-tests` skill or the CLI snippet below.

| Testbench | Covers | File |
|-----------|--------|------|
| `tb_RegisterFile` | `RegisterFile` (x0 zero, write/read, reset) | `src/sim_1/ID/tb_RegisterFile.sv` |
| `tb_ImmediateExtend` | I/S/B/U/J immediate decoding | `src/sim_1/ID/tb_ImmediateExtend.sv` |
| `tb_ControlUnit` | Control signals per opcode | `src/sim_1/ID/tb_ControlUnit.sv` |
| `tb_ALU` | All ALU operations + edge cases | `src/sim_1/EX/tb_ALU.sv` |
| `tb_ExecuteStage` | EX stage (ALU + decoder + forwarding muxes) | `src/sim_1/EX/tb_ExecuteStage.sv` |
| `tb_DataMemory` | Byte/halfword/word access | `src/sim_1/MEM/tb_DataMemory.sv` |
| `tb_Buffers` | Pipeline buffers hold/forward | `src/sim_1/Buffers/tb_Buffers.sv` |
| `tb_Forwarding` | Forwarding + load-use stall | `src/sim_1/Hazard/tb_Forwarding.sv` |
| `tb_IF_to_WB` | Full IF→ID→EX→MEM→WB integration (NOP-padded) | `src/sim_1/Integrador/tb_IF_to_WB.sv` |

> Full suite: **100 tests passing across 9 testbenches.** Run via the `run-tests` skill or `bash .claude/skills/run-tests/scripts/run_tests.sh`.

---

## Design Conventions

- **Language:** SystemVerilog (`.sv`). Use `logic`, `always_ff`, `always_comb` — never plain `always`.
- **Port naming:** `i_` inputs, `o_` outputs, `w_` internal wires, `r_` registers/state.
- **Parameterization:** all widths (PC, instruction, data) are parameters; default 32-bit. No hardcoded widths.
- **PC increment:** adds 1 (word-addressed), not 4 — the PC indexes words, not bytes.
- **Instruction memory:** word-addressed array of `2^NB_ADDR` 32-bit words; loaded via `$readmemh("program.hex")` at simulation start; zeroed on reset (program loaded via UART in hardware).

---

## Running Simulations

### Vivado GUI

1. Open `project_1/project_1.xpr` in Vivado.
2. Set the desired testbench as the active simulation source.
3. Run **Simulation → Run Behavioral Simulation**.

### CLI

```bash
mkdir -p sim_out && cd sim_out
xvlog --sv ../src/sources_1/**/*.sv ../src/sim_1/<tb_dir>/<tb_file>.sv
xelab -debug typical <top_module> -s sim_snapshot
xsim sim_snapshot --runall
```

> `program.hex` must be present in the xsim working directory. Vivado copies it automatically when launched from the project.

---

## Known Issues / WIP

- **Branch/jump control hazards** not yet handled (Stage 8). Programs with BEQ/BNE/JAL/JALR require manual NOP padding for now.
- **UART and debug unit** not yet implemented (Stage 9). The `RISCV` module exposes hooks (`i_if_enable`, `i_mem_wr` / `i_mem_addr` / `i_mem_data`) for future program loading via the debug unit.

---

## Constraints

Basys-3 XDC: [Digilent Basys-3 Master XDC](https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc)
