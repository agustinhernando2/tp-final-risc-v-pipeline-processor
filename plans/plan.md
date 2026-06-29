# Plan: RISC-V Pipeline Processor — Implementation Breakdown

## Context

The goal is to implement a complete 5-stage RISC-V pipeline processor (IF→ID→EX→MEM→WB) on a Basys-3 FPGA, programmable via UART, with a debug unit and two operating modes (continuous / step-by-step). The existing codebase has the IF stage and generic building blocks done; ID is partial and buggy; EX, MEM, WB, and the full top-level integration are missing.

We will proceed **bottom-up, simplest instruction first**: get a single ADD instruction flowing through all 5 stages before adding complexity.

---

## Current State Audit

### Done (working or nearly so)
| File | Status |
|------|--------|
| `Generic/posEdgeRegister.v` | OK |
| `Generic/adder.v` | OK |
| `Generic/mux*.v` | OK |
| `IF/InstructionMemory.v` | OK |
| `IF/InstructionFetch.v` | OK |
| `Buffers/IF_ID_Buffer.v` | OK |

### Needs fixes before use
| File | Bug |
|------|-----|
| `ID/RegisterFile.v` | Array dimensions swapped (`r_RF[2**NB_REG-1:0] [DATA_WIDTH-1:0]` → should be `r_RF[DATA_WIDTH-1:0] [2**NB_REG-1:0]`, i.e., 32 entries × 32 bits); missing comma after first parameter; reset writes non-zero values to x0 and x1 (RISC-V x0 must be hardwired zero) |
| `ID/InstructionDecode.v` | Duplicate `i_regWrite` port; trailing comma in parameter list; trailing comma in `RegisterFile` instantiation; register-address fields should be extracted *inside* the module from `i_instruction` (rs1=inst[19:15], rs2=inst[24:20], rd=inst[11:7]), not taken as external inputs |
| `Buffers/ID_EX_Buffer.v` | Is a copy of `IF_ID_Buffer`; needs correct fields for the ID→EX boundary |

---

## Resources

| File | Purpose |
|------|---------|
| `.claude/skills/run-tests/references/tb_template.sv` | Testbench skeleton — copy for every new module. Covers both combinational and sequential DUTs. Remove the clock block and `tick` task for combinational modules. The `run-tests` skill loads this automatically when asked to write a testbench. |
| `.claude/skills/run-tests/scripts/run_tests.sh` | Runs the full test suite (auto-discovers all sources and `tb_*.sv` files). Invoke via the `run-tests` skill or directly with `bash`. |

---

## Stage Detail Template

Each stage has a corresponding `plans/stageN.md` file with the full record. See [`plans/stage_template.md`](stage_template.md) for the canonical structure.


---

## Deliverables by Stage

| Stage | Title | Key deliverables | Detail file | Status |
|-------|-------|-----------------|-------------|--------|
| 0 | Fix existing bugs | `RegisterFile.sv`, `InstructionDecode.sv` fixed; `tb_RegisterFile.sv` passing | `plans/stage0.md` | DONE |
| 1 | Immediate extension | `ImmediateExtend.sv` (I/S/B/U/J types); `InstructionDecode.sv` updated; `tb_ImmediateExtend.sv` 10/10 | `plans/stage1.md` | DONE |
| 2 | Control Unit | `ControlUnit.sv` with full opcode truth table; `tb_ControlUnit.sv` | `plans/stage2.md` | DONE |
| 3 | EX / ALU | `ALU.sv`, `ALUDecoder.sv`, `ExecuteStage.sv`; ALU testbench | `plans/stage3.md` | DONE |
| 4 | Pipeline buffers | `ID_EX_Buffer.sv`, `EX_MEM_Buffer.sv`, `MEM_WB_Buffer.sv` | `plans/stage4.md` | DONE |
| 5 | Data Memory | `DataMemory.sv` with byte/halfword/word access; testbench | `plans/stage5.md` | DONE |
| 6 | WB + full pipeline | `WriteBackStage.sv`; `riscv.sv` wired end-to-end; NOP-padded integration test | `plans/stage6.md` | DONE |
| 7 | Hazard + Forwarding | `ForwardingUnit.sv`, `HazardDetectionUnit.sv`; back-to-back dependency test | `plans/stage7.md` | DONE |
| 8 | Branch & Jump | Flush logic for BEQ/BNE/JAL/JALR in `riscv.sv`; loop and jump test programs | `plans/stage8.md` | DONE |
| 9a | UART (SystemVerilog) | `BaudRateGenerator.sv`, `UartRx.sv`, `UartTx.sv`, `Uart.sv`; `UartLoopbackTop.sv` + `.xdc`; build/program/test vía skill `program-board` | `plans/stage9a.md` | DONE (validado en placa: PASS 256/256) |
| 9b | Debug Unit & GUI | `DebugUnit.sv`, `RiscvTop.sv` (SoC), HALT, GUI Python (`tools/gui/`) | `plans/stage9b.md` | DONE (validado en placa) |
| 10 | Operating modes | Continuous / step-by-step via clock enable (`i_if_enable`) gateado por la DebugUnit | *(sin archivo propio — cubierto por la FSM)* | DONE (validado en placa: paso a paso OK) |
| 11 | Timing & synthesis | MMCM 100→60 MHz en `RiscvTop`; timing cierra (WNS +0.704 ns); Fmax confiable 60 MHz | `plans/stage11.md` | DONE (validado en placa) |

---

## Staged Implementation Plan

### Stage 0 — Fix existing bugs (prerequisite for everything)

`Status: DONE` — see `plans/stage0.md`

**Files edited:**
- `src/sources_1/ID/RegisterFile.sv` — fixed array declaration, reset, x0 hardwired zero
- `src/sources_1/ID/InstructionDecode.sv` — removed duplicate port, derive rs1/rs2/rd internally

**Verification:** `tb_RegisterFile.sv` — 5 tests, all passing.

---

### Stage 1 — Complete ID: Sign Extension for all RISC-V immediate types

`Status: DONE` — see `plans/stage1.md`

**Files created/edited:**
- `src/sources_1/ID/ImmediateExtend.sv` — I/S/B/U/J formats via `ImmSrc[2:0]`
- `src/sources_1/ID/InstructionDecode.sv` — uses `ImmediateExtend`, new `i_ImmSrc` port

**Verification:** `tb_ImmediateExtend.sv` — 10 tests, all passing.

---

### Stage 2 — Control Unit

`Status: DONE` — see `plans/stage2.md`

**File to create:** `src/sources_1/ID/ControlUnit.sv`
- Input: `i_opcode[6:0]` only — funct3/funct7 are forwarded separately to `ALUDecoder` in Stage 3
- Outputs: `o_RegWrite`, `o_ALUSrc`, `o_ALUOp[1:0]`, `o_MemRead`, `o_MemWrite`, `o_MemToReg`, `o_Branch`, `o_Jump`, `o_ImmSrc[2:0]`
- ALUOp: `2'b10`=R-type, `2'b11`=I-type ALU, `2'b00`=forced ADD, `2'b01`=forced SUB
- Truth table covers: R (0110011), I-arith (0010011), Load (0000011), Store (0100011), Branch (1100011), JAL (1101111), JALR (1100111), LUI (0110111)

**Verification:** Directed testbench — feed each opcode, check all control outputs.

---

### Stage 3 — EX Stage: ALU

`Status: DONE` — see `plans/stage3.md`

**Files to create:**
- `src/sources_1/EX/ALU.sv`
  - Inputs: `i_a [31:0]`, `i_b [31:0]`, `i_ALUControl [3:0]`
  - Outputs: `o_result [31:0]`, `o_zero`
  - Operations: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
  - LUI no necesita op propia: usa ADD con operando A forzado a 0 en ExecuteStage (señal `LUI`), ver BUG-001 en `docs/known-bugs.md`
- `src/sources_1/EX/ALUDecoder.sv`
  - Inputs: `ALUOp[1:0]` from control unit + `funct3` + `funct7[5]`
  - Output: `ALUControl[3:0]`
- `src/sources_1/EX/ExecuteStage.sv`
  - Instantiates ALU + ALUDecoder
  - Mux: ALU input B = register or immediate (ALUSrc)
  - Computes branch target: PC + imm

**Verification:** ALU testbench covering all 10 operations with edge cases (overflow, shifts by 0 and 31, SLT signed vs SLTU unsigned).

---

### Stage 4 — Pipeline Buffers (ID_EX, EX_MEM, MEM_WB)

`Status: DONE` — see `plans/stage4.md`

**Files to create/rewrite:**
- `src/sources_1/Buffers/ID_EX_Buffer.sv`
  - Latches: PC+1, rs1_data, rs2_data, immediate, rd, control signals (all outputs of Stage 2 that survive to EX/MEM/WB)
- `src/sources_1/Buffers/EX_MEM_Buffer.sv`
  - Latches: ALU result, rs2_data (for stores), rd, zero flag, control signals (MemRead, MemWrite, MemToReg, RegWrite, Branch, Jump)
- `src/sources_1/Buffers/MEM_WB_Buffer.sv`
  - Latches: ALU result, mem read data, rd, control signals (MemToReg, RegWrite)

Each buffer uses a single `always_ff` block (inline, not `PosEdgeRegister` — cleaner for multi-signal latches). Synchronous reset, enable for future stalls.

**Verification:** Confirm each buffer holds and forwards values correctly in a short waveform sim.

---

### Stage 5 — MEM Stage: Data Memory

`Status: PENDING` — see `plans/stage5.md`

**File to create:** `src/sources_1/MEM/DataMemory.sv`
- Word-addressed, parameterized depth (default 64 words)
- Supports byte/halfword/word reads: LB, LBU, LH, LHU, LW, LWU
- Supports byte/halfword/word writes: SB, SH, SW
- `funct3` selects width
- Synchronous write, combinational read

**Verification:** Testbench: write a word, read back byte/halfword/word at same and adjacent addresses.

---

### Stage 6 — WB Stage & Full Pipeline Connection

`Status: PENDING` — see `plans/stage6.md`

**File to create:** `src/sources_1/WB/WriteBackStage.sv`
- Mux: write data = ALU result or memory read data (`MemToReg`)
- Output feeds back to `InstructionDecode` `i_write_data` / `i_write_reg` / `i_regWrite`

**File to rewrite:** `src/sources_1/Top/riscv.sv`
- Wire all stages together: IF → IF_ID → ID → ID_EX → EX → EX_MEM → MEM → MEM_WB → WB → back to ID
- No hazard logic yet — test with programs that have no data or control hazards (insert NOPs manually)

**First working program (no hazards):**
```asm
addi x1, x0, 5      # x1 = 5
addi x2, x0, 3      # x2 = 3 (4 NOPs between here and add)
nop; nop; nop; nop
add  x3, x1, x2     # x3 = 8  (should see 8 in x3)
```
Verify in simulation that `x3 == 8` after WB.

---

### Stage 7 — Hazard Detection + Forwarding Unit

`Status: PENDING` — see `plans/stage7.md`

**Files to create:**
- `src/sources_1/Hazard/ForwardingUnit.sv`
  - Inputs: EX/MEM and MEM/WB `rd` and `RegWrite` signals + ID/EX `rs1`, `rs2`
  - Outputs: `ForwardA[1:0]`, `ForwardB[1:0]` (select: from register, from EX/MEM ALU result, from MEM/WB write-back)
- `src/sources_1/Hazard/HazardDetectionUnit.sv`
  - Detects load-use hazard (EX stage is a load and rd matches rs1/rs2 in ID)
  - Outputs: `PCWrite` (freeze PC), `IF_ID_Write` (freeze IF_ID buffer), `ID_EX_flush` (insert bubble)

**Verification:** Test program with back-to-back dependent instructions (no NOPs). Confirm correct results with forwarding; confirm stall on load-use.

---

### Stage 8 — Branch & Jump Handling

`Status: DONE` — see `plans/stage8.md`

- Branch decision computed in EX (BEQ/BNE uses ALU zero flag)
- On taken branch: flush IF and ID stages (insert 2 bubbles), load branch target PC
- JAL: unconditional jump, PC = PC + J-imm, rd = PC+1
- JALR: PC = rs1 + I-imm (truncate bit 0), rd = PC+1

**Verification:** Test with a loop (BNE) and a JAL/JALR sequence. Confirm correct iteration count and return address.

---

### Stage 9 — UART Interface & Debug Unit

Dividida en dos: **9a — UART** (`Status: DONE` — see `plans/stage9a.md`) y
**9b — Debug Unit & GUI** (`Status: DONE` (HDL+sim) — see `plans/stage9b.md`).

**Files to create:**
- `src/sources_1/UART/UARTRx.sv` + `UARTTx.sv` (standard 8N1 UART; use existing designs as reference)
- `src/sources_1/UART/DebugUnit.sv`
  - **Program loading mode**: receive hex bytes over UART, write to InstructionMemory via `i_imem_wr/i_imem_addr/i_imem_data`
  - **Debug read mode**: on command, transmit:
    - 32 × 32-bit register values
    - Contents of all 4 pipeline latches (IF_ID, ID_EX, EX_MEM, MEM_WB)
    - N × 32-bit data memory words
  - **Mode control**: continuous vs step-by-step (clock enable gating)

**HALT instruction:** RISC-V has no official HALT; use a self-loop (`jal x0, 0`) as the convention. The debug unit detects this (or a special NOP encoding) to signal program end.

---

### Stage 10 — Operating Modes

`Status: DONE — validado en placa` (sin archivo propio: implementado por la FSM de la DebugUnit)

- **Continuous mode**: UART command → deassert reset → run until HALT detected → transmit debug dump
- **Step-by-step mode**: each UART command → enable exactly one clock edge → transmit current pipeline state → pause

Clock enable is the mechanism (never gate the clock directly — meets the "clock must not be manually interrupted" requirement). Se implementa con el enable global `i_if_enable` del core (`src/sources_1/Top/riscv.sv`), que la `DebugUnit` baja/sube para cargar, avanzar un ciclo o congelar en HALT — no hay un `stage10.md` separado. Validado en la Basys-3: el modo paso a paso avanza ciclo a ciclo y vuelca el estado por UART.

---

### Stage 11 — Timing Analysis & Frequency Optimization

`Status: DONE (validado en placa @60 MHz)` — see `plans/stage11.md`

A 100 MHz el diseño **no cerraba timing** (WNS −1.341 ns): el camino crítico no es la
ALU sino los caminos de **dump core→DebugUnit** que cruzan `posedge → negedge` y por eso
tienen solo 5 ns de presupuesto (medio período). Análisis completo en
[`docs/report-20260628.md`](../docs/report-20260628.md).

**Fix:** un MMCM (`MMCME2_BASE`, M=12/O=20) en `RiscvTop.sv` corre todo el SoC a **60 MHz**
(100 MHz de W5 → 60 MHz). Cierra con WNS +0.704 ns; `CLK` de la UART = 60e6 para mantener
19200 baud. **60 MHz es el Fmax confiable**: el barrido de frecuencias
([`docs/report-fmax-sweep-20260628.md`](../docs/report-fmax-sweep-20260628.md)) muestra que
el timing aguanta hasta ~75 MHz pero el device al ~99% hace el placement irreproducible por
encima de 60 MHz. Validado en placa (continuo + paso a paso). Ver `plans/stage11.md`
(incluye qué es el Clock Wizard y cómo correr el análisis de timing a mano en la UI de Vivado).

---

## Instruction Coverage Map

| Group | Instructions | Encoding | Key signals |
|-------|-------------|----------|-------------|
| R-type | ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU | opcode=0110011 | ALUSrc=0, RegWrite=1 |
| I-arith | ADDI, ANDI, ORI, XORI, SLTI, SLTIU | opcode=0010011 | ALUSrc=1, RegWrite=1 |
| Load | LB,LBU,LH,LHU,LW,LWU | opcode=0000011 | MemRead=1, MemToReg=1 |
| Store | SB, SH, SW | opcode=0100011 | MemWrite=1 |
| Branch | BEQ, BNE | opcode=1100011 | Branch=1, ALUSrc=0 |
| LUI | LUI | opcode=0110111 | ALUSrc=1, RegWrite=1, ALUOp=00, LUI=1 (operando A→0 en EX, pasa imm) |
| Jump | JAL | opcode=1101111 | Jump=1, RegWrite=1 |
| Jump-reg | JALR | opcode=1100111 | Jump=1, ALUSrc=1, RegWrite=1 |

