# Stage 4 — Pipeline Buffers (ID_EX, EX_MEM, MEM_WB)

**Status: DONE**

---

## Files created / modified

| File | Action |
|------|--------|
| `src/sources_1/Buffers/ID_EX_Buffer.sv` | Rewritten (was broken copy of IF_ID_Buffer) |
| `src/sources_1/Buffers/EX_MEM_Buffer.sv` | Created |
| `src/sources_1/Buffers/MEM_WB_Buffer.sv` | Created |

Note: `ID_EX_Buffer.v` currently contains a copy of `IF_ID_Buffer` (wrong module). Delete it and create `ID_EX_Buffer.sv` from scratch.

---

## Design notes

All buffers use a single `always_ff @(posedge i_clk)` block. On reset, all outputs go to `'0`. Otherwise latch inputs when `i_enable = 1` (stalls will deassert enable later). No `PosEdgeRegister` instantiations — inline `always_ff` is cleaner for multi-signal buffers.

### ID_EX_Buffer.sv

Latches all ID outputs needed by EX, MEM, and WB stages.

```
module ID_EX_Buffer #(
    parameter NB_PC      = 32,
    parameter DATA_WIDTH = 32,
    parameter NB_REG     = 5
)(
    input  logic                   i_clk,
    input  logic                   i_reset,
    input  logic                   i_enable,
    // data signals
    input  logic [NB_PC-1:0]      i_PC,
    input  logic [DATA_WIDTH-1:0] i_read_data_1,
    input  logic [DATA_WIDTH-1:0] i_read_data_2,
    input  logic [DATA_WIDTH-1:0] i_immediate,
    input  logic [NB_REG-1:0]     i_rd,
    input  logic [2:0]            i_funct3,
    input  logic                  i_funct7_5,
    // control signals
    input  logic                  i_ALUSrc,
    input  logic [1:0]            i_ALUOp,
    input  logic                  i_RegWrite,
    input  logic                  i_MemRead,
    input  logic                  i_MemWrite,
    input  logic                  i_MemToReg,
    input  logic                  i_Branch,
    input  logic                  i_Jump,
    // outputs (mirror)
    output logic [NB_PC-1:0]      o_PC,
    output logic [DATA_WIDTH-1:0] o_read_data_1,
    output logic [DATA_WIDTH-1:0] o_read_data_2,
    output logic [DATA_WIDTH-1:0] o_immediate,
    output logic [NB_REG-1:0]     o_rd,
    output logic [2:0]            o_funct3,
    output logic                  o_funct7_5,
    output logic                  o_ALUSrc,
    output logic [1:0]            o_ALUOp,
    output logic                  o_RegWrite,
    output logic                  o_MemRead,
    output logic                  o_MemWrite,
    output logic                  o_MemToReg,
    output logic                  o_Branch,
    output logic                  o_Jump
);
```

### EX_MEM_Buffer.sv

Latches EX outputs needed by MEM and WB stages.

```
module EX_MEM_Buffer #(
    parameter DATA_WIDTH = 32,
    parameter NB_REG     = 5
)(
    input  logic                   i_clk,
    input  logic                   i_reset,
    input  logic                   i_enable,
    // data
    input  logic [DATA_WIDTH-1:0] i_alu_result,
    input  logic                  i_zero,
    input  logic [DATA_WIDTH-1:0] i_read_data_2,  // store data
    input  logic [NB_REG-1:0]     i_rd,
    // control
    input  logic                  i_RegWrite,
    input  logic                  i_MemRead,
    input  logic                  i_MemWrite,
    input  logic                  i_MemToReg,
    input  logic                  i_Branch,
    input  logic                  i_Jump,
    // outputs (mirror)
    output logic [DATA_WIDTH-1:0] o_alu_result,
    output logic                  o_zero,
    output logic [DATA_WIDTH-1:0] o_read_data_2,
    output logic [NB_REG-1:0]     o_rd,
    output logic                  o_RegWrite,
    output logic                  o_MemRead,
    output logic                  o_MemWrite,
    output logic                  o_MemToReg,
    output logic                  o_Branch,
    output logic                  o_Jump
);
```

### MEM_WB_Buffer.sv

Latches MEM outputs needed by WB stage.

```
module MEM_WB_Buffer #(
    parameter DATA_WIDTH = 32,
    parameter NB_REG     = 5
)(
    input  logic                   i_clk,
    input  logic                   i_reset,
    input  logic                   i_enable,
    // data
    input  logic [DATA_WIDTH-1:0] i_alu_result,
    input  logic [DATA_WIDTH-1:0] i_mem_read_data,
    input  logic [NB_REG-1:0]     i_rd,
    // control
    input  logic                  i_RegWrite,
    input  logic                  i_MemToReg,
    // outputs (mirror)
    output logic [DATA_WIDTH-1:0] o_alu_result,
    output logic [DATA_WIDTH-1:0] o_mem_read_data,
    output logic [NB_REG-1:0]     o_rd,
    output logic                  o_RegWrite,
    output logic                  o_MemToReg
);
```

---

## Running the tests

Buffers can be verified as part of the Stage 6 integration test. If standalone tests are desired:

```bash
mkdir -p sim_out && cd sim_out
xvlog --sv \
  ../src/sources_1/Buffers/ID_EX_Buffer.sv \
  ../src/sources_1/Buffers/EX_MEM_Buffer.sv \
  ../src/sources_1/Buffers/MEM_WB_Buffer.sv \
  ../src/sim_1/Buffers/tb_Buffers.sv
xelab -debug typical tb_Buffers -s sim_buf
xsim sim_buf --runall
```

---

## Test results

`tb_Buffers.sv` — 30 tests, all passing.

- ID_EX_Buffer: reset clears (3), latch on enable (8), hold on disable (2), sync reset (2)
- EX_MEM_Buffer: latch on enable (6), sync reset (2)
- MEM_WB_Buffer: latch on enable (5), sync reset (2)

---

## Next: Stage 5 — Data Memory

`EX_MEM_Buffer` passes `o_alu_result` (memory address), `o_read_data_2` (store data), `o_MemRead`, `o_MemWrite`, and `o_funct3` (access width) to `DataMemory`.
