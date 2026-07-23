# RISC-V 5-Stage Pipelined Processor

A 5-stage pipelined RISC-V processor implemented in SystemVerilog, targeting the **Basys-3 FPGA** board. The design follows the classic Patterson & Hennessy pipeline: **IF → ID → EX → MEM → WB**, with full data-hazard handling (forwarding + load-use stall) and branch/jump control-hazard handling (assume-not-taken + flush, 2-cycle penalty). The datapath is **32-bit** wide (`DATA_WIDTH = 32`, RV32); the PC is kept 64-bit (`NB_PC = 64`). RISC-V instructions are 32-bit.

**Status: complete and validated on the physical Basys-3.** UART program loading, continuous and step-by-step debug, and timing closure are all working on hardware. The SoC is clocked by a Clock Wizard IP at **75 MHz** with full setup **and** hold closure (WNS +0.634 ns, WHS +0.074 ns; see the timing reports under `docs/reports/`).

---

## Architecture Overview

The pipeline core (`RISCV`) is wrapped by `RiscvTop`, the synthesis top, which adds the UART, the `DebugUnit` FSM, and the Clock Wizard IP clocking the whole SoC at 75 MHz. The UART interface (`i_rx` / `o_tx`) lets a host PC load programs and drive the processor. All five stages are wired end-to-end with forwarding, load-use stall detection, and branch/jump flushing. Branches and jumps are resolved at the EX/MEM boundary (start of MEM); on a taken branch/jump the `IF/ID` and `ID/EX` buffers are flushed (2-cycle penalty).

Programs are driven over UART by the host tooling in `tools/gui/` (assembler + debug GUI/CLI). Programs must end with the dedicated `HALT` instruction (custom-0 opcode `0x0000000B`); the loader zero-pads the rest of memory and zeros decode as NOPs.

---

## Implementation Progress

The processor is built in staged increments. **All stages (0–11) are done and validated on hardware:**

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
| 8 | Branch & jump handling | ✅ Done |
| 9 | UART & debug unit (program load, HALT) | ✅ Done |
| 10 | Operating modes (continuous / step-by-step) | ✅ Done (DebugUnit FSM) |
| 11 | Timing analysis & frequency optimization (Clock Wizard @ 75 MHz) | ✅ Done |

---

## Getting Started from Scratch

The whole processor was built following a **staged, plan-driven workflow**, and that same workflow is how you should extend or rebuild it. The design is grown **bottom-up, simplest instruction first**: a single `ADD` is made to flow through all five stages before any complexity is added. If you are picking this repo up cold, start here.

### 1. The `plans/` folder is the source of truth for *what* to do

Everything is tracked in [`plans/`](plans/):

- **[`plans/plan.md`](plans/plan.md)** — the master plan. It holds the *Current State Audit* (what's done / what's buggy), the *Resources* table, and the **Deliverables by Stage** table (stages 0–11: bug fixes → Control Unit → ALU/EX → Buffers → MEM → WB → Hazard/Forwarding → Branch/Jump → UART/Debug → Operating Modes → Timing). Read this first to see where things stand.
- **`plans/stageN.md`** — one detail file per stage (`stage0.md` … `stage11.md`), each following [`plans/stage_template.md`](plans/stage_template.md): *files created/modified*, *design notes* (encoding tables, port lists, truth tables), *test results pasted verbatim*, and a *one-paragraph handoff* to the next stage.

> `plans/` is working notes rather than part of the design itself. The project convention (see `CLAUDE.md` → *Git Conventions*) is to **not** commit changes under `plans/` — update the relevant `stageN.md` as you work, but keep those edits out of your commits.

### 2. The skills are *how* to do it

Each step of the loop is backed by a Claude Code skill. Invoke them by name (`/skill-name`) or just describe the task and the right one triggers:

| When you want to… | Use the skill | Notes |
|-------------------|---------------|-------|
| **Understand the architecture** — a hazard, forwarding path, control signal, the datapath, why a stage looks the way it does | **`riscv-expert`** | Grounded in Patterson & Hennessy, *Computer Organization and Design: RISC-V Edition* (Ch. 4 + Appendix A). Ask it **before** writing RTL when the microarchitecture is unclear — e.g. "which forwarding path covers a load-use hazard?", "how is a taken branch flushed?" |
| **Write / migrate RTL** — `logic`, `always_ff`/`always_comb`, packed structs, avoiding inferred latches, parameterized buffers, formatting with verible | **`systemverilog`** | The house style: `.sv` only, `i_`/`o_`/`w_`/`r_` prefixes, no plain `always`, no hardcoded widths. |
| **Verify a change** — after every module or edit | **`run-tests`** | Auto-discovers all sources and `tb_*.sv`. Also loads `references/tb_template.sv` when you ask it to write a new testbench. Expected tail: `ALL TESTS PASSED`. |
| **Build the bitstream & flash the board** | **`program-board`** | Batch Vivado flow (no committed `.xpr`) + UART echo/loopback check. |
| **Run a program on the already-programmed board** — load, run, read PC/regs/memory, step | **`board-test`** | Drives `tools/gui/riscv_debug.py` over UART. Assumes the board is already flashed with `RiscvTop`. |
| **Board won't connect** — "no hardware target", JTAG/cable drivers on Linux | **`vivado-linux-debug`** | Digilent cable driver setup, `lsusb` checks. |

### 3. The per-stage loop

For each stage (and for any new instruction or feature):

1. **Read** `plans/stageN.md` and the relevant `plans/plan.md` row to see the deliverables and the handoff from the previous stage.
2. **Resolve the microarchitecture** with **`riscv-expert`** if anything about the datapath/hazards/control is unclear — cheaper than debugging wrong RTL later.
3. **Implement** the module with **`systemverilog`** conventions.
4. **Write a testbench** from `tb_template.sv` (the **`run-tests`** skill provides it) and **run the suite** — nothing advances until it's green.
5. **Record** the outcome in `plans/stageN.md` (files touched, design notes, pasted test output) and write the one-paragraph handoff to the next stage.
6. **On hardware**, once the RTL is proven in simulation: **`program-board`** to flash, then **`board-test`** to validate on the physical Basys-3.

This is exactly the sequence that produced the 138-test suite and the hardware-validated design; following it keeps the plan, the code, and the tests in sync.

---

## Module Map

### Pipeline Stages

| Stage | Module | File |
|-------|--------|------|
| IF — Instruction Fetch | `InstructionFetch` | `src/sources_1/IF/InstructionFetch.sv` |
| ID — Instruction Decode | `instructionDecode` | `src/sources_1/ID/InstructionDecode.sv` |
| EX — Execute | `ExecuteStage` | `src/sources_1/EX/ExecuteStage.sv` |
| MEM — Memory Access | `MemoryAccessStage` | `src/sources_1/MEM/MemoryAccessStage.sv` |
| WB — Write Back | `WriteBackStage` | `src/sources_1/WB/WriteBackStage.sv` |

Pipeline core: `src/sources_1/Top/riscv.sv` — `RISCV` module wiring all stages.
Synthesis top: `src/sources_1/Top/RiscvTop.sv` — `RiscvTop` SoC (pipeline core + UART + DebugUnit + Clock Wizard IP @ 75 MHz).

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
| `DebugUnit` | `src/sources_1/Debug/DebugUnit.sv` |
| `Uart` / `UartRx` / `UartTx` / `BaudRateGenerator` | `src/sources_1/UART/` |

### Generic Building Blocks

| Module | Description |
|--------|-------------|
| `PosEdgeRegister` | Parameterized FF with sync reset and enable |
| `Adder` | Parameterized combinational adder (PC+4, branch target) |
| `mux1_2` | 2-input parameterized mux |
| `mux2_4` | 4-input parameterized mux |
| `mux3_8` | 8-input parameterized mux |

---

## Instruction Set Coverage

| Group | Instructions | Opcode | Key signals |
|-------|-------------|--------|-------------|
| R-type | ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU | `0110011` | ALUSrc=0, RegWrite=1 |
| I-arith | ADDI, ANDI, ORI, XORI, SLTI, SLTIU, SLLI, SRLI, SRAI | `0010011` | ALUSrc=1, RegWrite=1 |
| Load | LB, LBU, LH, LHU, LW, LWU | `0000011` | MemRead=1, MemToReg=1 |
| Store | SB, SH, SW | `0100011` | MemWrite=1 |
| Branch | BEQ, BNE | `1100011` | Branch=1, ALUSrc=0 |
| LUI | LUI | `0110111` | ALUSrc=1, RegWrite=1 |
| Jump | JAL | `1101111` | Jump=1, RegWrite=1 |
| Jump-reg | JALR | `1100111` | Jump=1, ALUSrc=1, RegWrite=1 |

> This set covers every instruction required by the TP. The TP lists them in **MIPS** mnemonics (`SLLV`, `ADDU`, `SUBU`, `ADDIU`, `J`, `JR`, `NOR`); they map onto the RISC-V equivalents above (`NOR` has no RISC-V equivalent and is not applicable). `J` and `JR` need no dedicated hardware: the assembler emits them as `JAL x0` / `JALR x0`. Branch coverage is `BEQ`/`BNE` only (resolved via `funct3[0]`), as required.

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
| `tb_branch` | BNE loop + JAL with flush (Stage 8) | `src/sim_1/Integrador/tb_branch.sv` |
| `tb_step_branch` | Branch/jump resolution under step-by-step mode | `src/sim_1/Integrador/tb_step_branch.sv` |
| `tb_lui_bug` | LUI regression (`rd = imm`) | `src/sim_1/EX/tb_lui_bug.sv` |
| `tb_DebugUnit` | DebugUnit FSM (program load, run, step) | `src/sim_1/Debug/tb_DebugUnit.sv` |
| `tb_RiscvDebug` | `RiscvTop` SoC end-to-end via UART/debug | `src/sim_1/Debug/tb_RiscvDebug.sv` |

> Full suite: **138 tests passing across 14 testbenches.** Run via the `run-tests` skill or `bash .claude/skills/run-tests/scripts/run_tests.sh`.

---

## Design Conventions

- **Language:** SystemVerilog (`.sv`). Use `logic`, `always_ff`, `always_comb` — never plain `always`.
- **Port naming:** `i_` inputs, `o_` outputs, `w_` internal wires, `r_` registers/state.
- **Parameterization:** all widths (PC, instruction, data) are parameters; default 32-bit. No hardcoded widths.
- **PC increment:** adds 4 (byte-addressed), aligned with Patterson & Hennessy — the PC indexes bytes. Branch/jump immediates are byte offsets added to the PC directly (no shift).
- **Instruction memory:** array of `2^NB_ADDR` 32-bit words; fetch indexes with `PC >> 2`. Loaded via `$readmemh("program.hex")` at simulation start (program loaded via UART in hardware). The memories are **not** cleared on reset — the synchronous reset branch was removed so the arrays infer BRAM (see the Timing section).

---

## Learning Resources

- **Verilog → SystemVerilog migration guide** — [`html/verilog-to-sv/verilog_to_sv.html`](html/verilog-to-sv/verilog_to_sv.html) is a self-contained HTML guide (*"De Verilog a SystemVerilog — Guía Completa"*) covering why and how the RTL moved to SystemVerilog: typed `logic`, `always_ff`/`always_comb`, packed structs/enums, and the conventions this repo follows. Open it in a browser. For interactive help while writing RTL, use the **`systemverilog`** skill; for architecture questions, the **`riscv-expert`** skill (see [Getting Started from Scratch](#getting-started-from-scratch)).

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

## Host Tooling (`tools/gui/`)

Board bring-up and program loading are driven from the host with `tools/gui/`:

- `assembler.py` — assembles RISC-V programs to `program.hex`.
- `riscv_debug.py` / `gui.py` — debug GUI/CLI: load a program over UART, run continuously or step-by-step, and dump the PC and register/memory state.
- `uart.py`, `isa.py` — serial transport and ISA tables.

Managed with `uv`; see [`tools/gui/README.md`](tools/gui/README.md) for usage.

---

## Timing

A Clock Wizard IP in `RiscvTop` clocks the whole SoC at **75 MHz**, with full setup **and** hold closure: **WNS +0.634 ns, WHS +0.074 ns, 0 failing endpoints**.

Reaching 75 MHz took two changes (see [`docs/reports/report-timing-75mhz.md`](docs/reports/report-timing-75mhz.md)):

1. **Removed the global synchronous reset from `InstructionMemory` and `DataMemory`.** The `if (i_reset) …` clear-the-whole-array branch forced the memories to synthesize as ~8000 fabric flip-flops (a BRAM can't zero every word in one cycle), which put the program-load path (`DebugUnit → InstructionMemory` enables) into a huge-fanout, routing-dominated critical path. Removing it lets the arrays infer **BRAM**, dropping endpoints from ~37000 to ~7100 and flipping setup from WNS −0.281 → +0.632 ns.
2. **Removed a duplicate `create_clock -add` from the XDC**, which had introduced a false hold violation across the two clock objects.

This **supersedes** the earlier ~75 MHz "ceiling" attributed to the dump path (`docs/reports/report-fmax-sweep-dw32-20260629.md`): that path was slow precisely because the memories were in fabric, and moving them to BRAM resolved it. Earlier history (the 65 MHz MMCM stage and the datapath narrowing from 64→32 bits, which cut LUTs ~32%) is in `docs/reports/report-20260628.md` and `docs/reports/report-fmax-sweep-dw32-20260629.md`.

---

## Known Issues / WIP

- **`DataMemory` is word-addressed**, an independent addressing axis from the byte-addressed PC — known debt if end-to-end byte addressing is desired.
- Programs **must end with `HALT`** (custom-0 opcode `0x0000000B`); the loader zero-pads memory and zeros decode as NOPs. See `docs/utils/CONSIDERACIONES.md` C-004.
- The memories **infer BRAM and are not cleared on reset** (this is what closed timing at 75 MHz — see **Timing** above); in hardware the program is (re)loaded over UART before each run.

---

## Constraints

Basys-3 XDC: [Digilent Basys-3 Master XDC](https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc)

---

### 🧩 Datos técnicos de la Basys 3

- **Familia:** Artix-7
- **Dispositivo (FPGA):** `XC7A35T`
- **Package:** `CPG236`
- **Velocidad (Speed Grade):** `-1`

---

### ⚙️ Configuración paso a paso en Vivado

- **Nuevo Proyecto → New Project Wizard**
  - Nombre: `Basys3_Project` (por ejemplo)
  - Tipo: **RTL Project**
- **Default Part**

  En la pestaña **Parts** seleccioná:

  | Campo | Valor |
  |---|---|
  | **Family** | Artix-7 |
  | **Package** | CPG236 |
  | **Speed** | -1 |
  | **Part** | xc7a35tcpg236-1 |

---

### 💡 Consejo

Si no ves la placa **Basys 3** en la lista de *Boards*, necesitás instalar los archivos de soporte de Digilent.

Podés hacerlo así:

- Descargá el archivo desde 🔗 [https://digilent.com/reference/programmable-logic/vivado-board-files](https://digilent.com/reference/programmable-logic/vivado-board-files)
- Extraé el contenido en la carpeta:

  ```
  C:\Xilinx\Vivado\<version>\data\boards\board_files\
  ```
- Reiniciá Vivado y la Basys 3 aparecerá en la lista.

---

### Referencias

- [HDLBits — Verilog Practice](https://hdlbits.01xz.net/wiki/Main_Page)
- [Basys 3 AMD Artix™ 7 FPGA Trainer Board: Recommended for Introductory Users](https://digilent.com/shop/basys-3-amd-artix-7-fpga-trainer-board-recommended-for-introductory-users/)
