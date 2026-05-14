# RISC-V 5-Stage Pipelined Processor

A 5-stage pipelined processor implemented in Verilog, targeting the **Basys-3 FPGA** board.  

---

## Architecture Overview



The top-level module (`RISCV`) exposes a UART interface (`i_rx` / `o_tx`) for loading programs and interacting with the processor via a host PC.

---

## Module Map

### Pipeline Stages

| Stage | Status | Module | File |
|-------|--------|--------|------|
| IF — Instruction Fetch | ✅ Done | `InstructionFetch` | `src/sources_1/IF/InstructionFetch.sv` |
| ID — Instruction Decode | 🔧 WIP | `instructionDecode` | `src/sources_1/ID/InstructionDecode.sv` |
| EX — Execute | ⬜ Pending | — | — |
| MEM — Memory Access | ⬜ Pending | — | — |
| WB — Write Back | ⬜ Pending | — | — |

### Pipeline Buffers

| Buffer | Status | File |
|--------|--------|------|
| `IF_ID_Buffer` | ✅ Done | `src/sources_1/Buffers/IF_ID_Buffer.sv` |
| `ID_EX_Buffer` | 🔧 WIP (needs ID→EX signals) | `src/sources_1/Buffers/ID_EX_Buffer.sv` |
| `EX_MEM_Buffer` | ⬜ Pending | — |
| `MEM_WB_Buffer` | ⬜ Pending | — |

### Generic Building Blocks

| Module | Status | Description |
|--------|--------|-------------|
| `PosEdgeRegister` | ✅ Done | Parameterized FF with sync reset and enable |
| `Adder` | ✅ Done | Parameterized combinational adder (PC+1) |
| `mux1_2` | ✅ Done | 2-input parameterized mux |
| `mux2_4` | ✅ Done | 4-input parameterized mux |
| `mux3_8` | ✅ Done | 8-input parameterized mux |

### Sub-modules

| Module | Status | File |
|--------|--------|------|
| `InstructionMemory` | ✅ Done | `src/sources_1/IF/InstructionMemory.sv` |
| `RegisterFile` | 🔧 WIP (transposed array dims) | `src/sources_1/ID/RegisterFile.sv` |
| `SignExtension` | ✅ Done | `src/sources_1/ID/SignExtension.sv` |
| Control Unit | ⬜ Pending | — |
| ALU | ⬜ Pending | — |
| Data Memory | ⬜ Pending | — |
| UART | ⬜ Pending | — |
| Hazard Detection Unit | ⬜ Pending | — |
| Forwarding Unit | ⬜ Pending | — |

---

## Known Issues

- `instructionDecode`: duplicate `i_regWrite` port declaration — must fix before simulating.
- `RegisterFile`: `r_RF` array dimensions are transposed.
- `ID_EX_Buffer`: currently a copy of `IF_ID_Buffer` — needs update once control unit is designed.
- `RISCV` top module: empty skeleton — pipeline stages not yet wired.

---

## Instruction Set Implementation Progress

### R-Type Instructions

| Instruction | Description | Status |
|-------------|-------------|--------|
| `SLL` | Shift Left Logical | ⬜ Pending |
| `SRL` | Shift Right Logical | ⬜ Pending |
| `SRA` | Shift Right Arithmetic | ⬜ Pending |
| `SLLV` | Shift Left Logical Variable | ⬜ Pending |
| `SRLV` | Shift Right Logical Variable | ⬜ Pending |
| `SRAV` | Shift Right Arithmetic Variable | ⬜ Pending |
| `ADDU` | Add Unsigned | ⬜ Pending |
| `SUBU` | Subtract Unsigned | ⬜ Pending |
| `AND` | Bitwise AND | ⬜ Pending |
| `OR` | Bitwise OR | ⬜ Pending |
| `XOR` | Bitwise XOR | ⬜ Pending |
| `NOR` | Bitwise NOR | ⬜ Pending |
| `SLT` | Set Less Than (signed) | ⬜ Pending |
| `SLTU` | Set Less Than Unsigned | ⬜ Pending |

### I-Type Instructions

| Instruction | Description | Status |
|-------------|-------------|--------|
| `LB` | Load Byte | ⬜ Pending |
| `LH` | Load Halfword | ⬜ Pending |
| `LW` | Load Word | ⬜ Pending |
| `LWU` | Load Word Unsigned | ⬜ Pending |
| `LBU` | Load Byte Unsigned | ⬜ Pending |
| `LHU` | Load Halfword Unsigned | ⬜ Pending |
| `SB` | Store Byte | ⬜ Pending |
| `SH` | Store Halfword | ⬜ Pending |
| `SW` | Store Word | ⬜ Pending |
| `ADDI` | Add Immediate | ⬜ Pending |
| `ADDIU` | Add Immediate Unsigned | ⬜ Pending |
| `ANDI` | AND Immediate | ⬜ Pending |
| `ORI` | OR Immediate | ⬜ Pending |
| `XORI` | XOR Immediate | ⬜ Pending |
| `LUI` | Load Upper Immediate | ⬜ Pending |
| `SLTI` | Set Less Than Immediate (signed) | ⬜ Pending |
| `SLTIU` | Set Less Than Immediate Unsigned | ⬜ Pending |
| `BEQ` | Branch if Equal | ⬜ Pending |
| `BNE` | Branch if Not Equal | ⬜ Pending |

### J-Type Instructions

| Instruction | Description | Status |
|-------------|-------------|--------|
| `J` | Jump | ⬜ Pending |
| `JAL` | Jump and Link | ⬜ Pending |
| `JR` | Jump Register | ⬜ Pending |
| `JALR` | Jump and Link Register | ⬜ Pending |

---

## Testbenches

| Testbench | Covers | File |
|-----------|--------|------|
| `tb_IF` | `InstructionFetch` standalone | `src/sim_1/IF/tb_IF.sv` |
| `tb_IF_ID_Buffer` | IF/ID pipeline register | `src/sim_1/IF/tb_IF_ID_Buffer.sv` |
| `tb_adder` | Generic adder | `src/sim_1/IF/tb_adder.sv` |
| `tb_IF_ID` | IF → IF_ID_Buffer integration | `src/sim_1/Integrador/tb_IF_ID.sv` |

---

## Design Conventions

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
xvlog --sv src/sources_1/**/*.sv src/sim_1/<tb_dir>/<tb_file>.sv
xelab -debug typical <top_module> -s sim_snapshot
xsim sim_snapshot --tclbatch <tcl_script>
```

> `program.hex` must be present in the xsim working directory. Vivado copies it automatically when launched from the project.

---

## Constraints

Basys-3 XDC: [Digilent Basys-3 Master XDC](https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc)
