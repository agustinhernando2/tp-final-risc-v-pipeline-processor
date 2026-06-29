# Stage 3 — EX Stage: ALU

**Status: DONE**

---

## Files created / modified

| File | Action |
|------|--------|
| `src/sources_1/EX/ALU.sv` | Created |
| `src/sources_1/EX/ALUControl.sv` | Created |
| `src/sources_1/EX/ExecuteStage.sv` | Created |
| `src/sim_1/EX/tb_ALU.sv` | Created |
| `src/sim_1/EX/tb_ExecuteStage.sv` | Created |

---

## Design notes

### ALU.sv

Pure combinational. All 10 RV32I integer operations + zero flag.

```
module ALU #(
    parameter DATA_WIDTH     = 32,
    parameter ALU_CTRL_WIDTH = 4
)(
    input  logic [DATA_WIDTH-1:0]     i_operand_a,
    input  logic [DATA_WIDTH-1:0]     i_operand_b,
    input  logic [ALU_CTRL_WIDTH-1:0] i_ALUCtrl,
    output logic [DATA_WIDTH-1:0]     o_result,
    output logic                      o_zero
);
```

ALUCtrl encoding:

| ALUCtrl | Operation | Notes |
|---------|-----------|-------|
| `4'b0000` | ADD | |
| `4'b0001` | SUB | |
| `4'b0010` | SLL | shift by `i_operand_b[4:0]` |
| `4'b0011` | SLT | `$signed(a) < $signed(b)`, result is 0 or 1 |
| `4'b0100` | SLTU | unsigned compare |
| `4'b0101` | XOR | |
| `4'b0110` | SRL | logical shift right |
| `4'b0111` | SRA | `$signed(a) >>> b[4:0]` (arithmetic, sign-extends) |
| `4'b1000` | OR | |
| `4'b1001` | AND | |

Key: use `$signed()` for SLT and SRA; do **not** declare ports as `signed`. `o_zero = (o_result == '0)`.

### ALUControl.sv

Pure combinational. Maps `{ALUOp, funct3, funct7_5}` → `ALUCtrl`.

```
module ALUControl #(
    parameter ALU_CTRL_WIDTH = 4
)(
    input  logic [1:0]              i_ALUOp,
    input  logic [2:0]              i_funct3,
    input  logic                    i_funct7_5,
    output logic [ALU_CTRL_WIDTH-1:0] o_ALUCtrl
);
```

Decode table:

| ALUOp | funct3 | funct7[5] | ALUCtrl | Instruction |
|-------|--------|-----------|---------|-------------|
| 00 | — | — | 0000 | ADD (load/store address) |
| 01 | — | — | 0001 | SUB (branch compare) |
| 10 | 000 | 0 | 0000 | ADD |
| 10 | 000 | 1 | 0001 | SUB |
| 10 | 001 | — | 0010 | SLL |
| 10 | 010 | — | 0011 | SLT |
| 10 | 011 | — | 0100 | SLTU |
| 10 | 100 | — | 0101 | XOR |
| 10 | 101 | 0 | 0110 | SRL |
| 10 | 101 | 1 | 0111 | SRA |
| 10 | 110 | — | 1000 | OR |
| 10 | 111 | — | 1001 | AND |
| 11 | 000 | — | 0000 | ADDI |
| 11 | 001 | — | 0010 | SLLI |
| 11 | 010 | — | 0011 | SLTI |
| 11 | 011 | — | 0100 | SLTIU |
| 11 | 100 | — | 0101 | XORI |
| 11 | 101 | 0 | 0110 | SRLI |
| 11 | 101 | 1 | 0111 | SRAI |
| 11 | 110 | — | 1000 | ORI |
| 11 | 111 | — | 1001 | ANDI |

Use `unique case ({i_ALUOp, i_funct3, i_funct7_5})` with wildcard don't-cares where funct7_5 is irrelevant (use `casez` with `?` for don't-cares, or case with explicit both values).

### ExecuteStage.sv

Pure combinational. Instantiates ALUControl + mux1_2 + ALU.

```
module ExecuteStage #(
    parameter DATA_WIDTH     = 32,
    parameter NB_REG         = 5,
    parameter ALU_CTRL_WIDTH = 4
)(
    // from ID_EX_Buffer
    input  logic [DATA_WIDTH-1:0] i_read_data_1,
    input  logic [DATA_WIDTH-1:0] i_read_data_2,
    input  logic [DATA_WIDTH-1:0] i_immediate,
    input  logic [NB_REG-1:0]     i_rd,
    input  logic [2:0]            i_funct3,
    input  logic                  i_funct7_5,
    input  logic                  i_ALUSrc,
    input  logic [1:0]            i_ALUOp,
    // outputs
    output logic [DATA_WIDTH-1:0] o_alu_result,
    output logic                  o_zero,
    output logic [DATA_WIDTH-1:0] o_read_data_2,  // pass-through for stores
    output logic [NB_REG-1:0]     o_rd             // pass-through for WB
);
```

Internal wires: `w_alu_b` (mux output), `w_alu_ctrl`.

Submodule connections:
- `mux1_2`: `a=i_read_data_2`, `b=i_immediate`, `sel=i_ALUSrc` → `w_alu_b`
- `u_alu_control`: `i_ALUOp`, `i_funct3`, `i_funct7_5` → `w_alu_ctrl`
- `ALU`: `i_read_data_1`, `w_alu_b`, `w_alu_ctrl` → `o_alu_result`, `o_zero`

`o_read_data_2 = i_read_data_2` (assign). `o_rd = i_rd` (assign).

---

## Running the tests

```bash
mkdir -p sim_out && cd sim_out

# ALU unit test
xvlog --sv \
  ../src/sources_1/EX/ALU.sv \
  ../src/sim_1/EX/tb_ALU.sv
xelab -debug typical tb_ALU -s sim_alu
xsim sim_alu --runall

# ExecuteStage test (needs ALUControl + mux1_2)
xvlog --sv \
  ../src/sources_1/Generic/mux1_2.v \
  ../src/sources_1/EX/ALU.sv \
  ../src/sources_1/EX/ALUControl.sv \
  ../src/sources_1/EX/ExecuteStage.sv \
  ../src/sim_1/EX/tb_ExecuteStage.sv
xelab -debug typical tb_ExecuteStage -s sim_ex
xsim sim_ex --runall
```

Expected output ends with `ALL TESTS PASSED`.

---

## Test results

- `tb_ALU.sv`: 18/18 PASSED (all operations; edge cases: zero flag, shifts by 0 and 31, SLT signed vs SLTU unsigned)
- `tb_ExecuteStage.sv`: 12/12 PASSED (R-type, I-type, load/store ADD, branch SUB, pass-throughs)

---

## Next: Stage 4 — Pipeline Buffers

`ExecuteStage` outputs (`o_alu_result`, `o_zero`, `o_read_data_2`, `o_rd`) feed into `EX_MEM_Buffer`. The stage also needs `i_rd`, `i_funct3`, `i_funct7_5`, `i_ALUSrc`, `i_ALUOp` which come from `ID_EX_Buffer`.
