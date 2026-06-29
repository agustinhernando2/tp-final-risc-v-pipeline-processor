# Stage 6 — WB Stage & Full Pipeline Connection

**Status: DONE**

---

## Files created / modified

| File | Action |
|------|--------|
| `src/sources_1/WB/WriteBackStage.sv` | Created |
| `src/sources_1/Top/riscv.sv` | Rewritten (replaces skeleton `riscv.v`) |
| `src/sim_1/Integrador/tb_IF_to_WB.sv` | Created — full pipeline integration test |

---

## Design notes

### WriteBackStage.sv

Pure combinational. Selects write-back data and passes through rd/RegWrite to the register file.

```
module WriteBackStage #(
    parameter DATA_WIDTH = 32,
    parameter NB_REG     = 5
)(
    input  logic [DATA_WIDTH-1:0] i_alu_result,
    input  logic [DATA_WIDTH-1:0] i_mem_read_data,
    input  logic [NB_REG-1:0]     i_rd,
    input  logic                  i_RegWrite,
    input  logic                  i_MemToReg,
    output logic [DATA_WIDTH-1:0] o_write_data,
    output logic [NB_REG-1:0]     o_write_reg,
    output logic                  o_RegWrite
);
```

Instantiate `mux1_2`: `a=i_alu_result` (sel=0, R-type/I-type), `b=i_mem_read_data` (sel=1, loads). `o_write_reg = i_rd`, `o_RegWrite = i_RegWrite` (direct assigns).

### riscv.sv

Replaces `riscv.v`. Convert to SystemVerilog. Fix parameter `OPCODE_SIZE=6` → remove it (not needed). Final parameters: `NB_PC=32, NB_INST=32, NB_REG=5, DATA_WIDTH=32, NB_ADDR=8`.

**Module instantiation order and wire naming:**

```
// Stage outputs follow: w_<stage>_<signal>
// Buffer outputs follow: w_<buf>_<signal>

// IF → IF_ID
InstructionFetch IF (.i_PCSrc(1'b0), .i_PCBranch('0), .i_imem_wr(1'b0), ...)
IF_ID_Buffer     IF_ID (.i_enable(1'b1), ...)

// ID
instructionDecode ID (.i_write_reg(w_wb_write_reg),
                      .i_write_data(w_wb_write_data),
                      .i_regWrite(w_wb_RegWrite), ...)

// ID_EX
ID_EX_Buffer     ID_EX (.i_enable(1'b1), ...)

// EX
ExecuteStage     EX (...)

// EX_MEM
EX_MEM_Buffer    EX_MEM (.i_enable(1'b1), ...)

// MEM (Stage 5 — stub for R-type: MemRead=0, MemWrite=0)
DataMemory       MEM (...)  // o_read_data = '0 when MemRead=0

// MEM_WB
MEM_WB_Buffer    MEM_WB (.i_enable(1'b1), ...)

// WB → back to ID
WriteBackStage   WB (.o_write_data(w_wb_write_data),
                     .o_write_reg(w_wb_write_reg),
                     .o_RegWrite(w_wb_RegWrite))
```

For Stage 6 (R-type only, no hazards): tie all enables to `1'b1`, `PCSrc=1'b0`.

### Integration test (tb_IF_to_WB.sv)

Strategy: use **independent** R-type instructions to avoid data hazards (no forwarding yet). Pre-load x1 and x2 by driving the WB inputs to `instructionDecode` directly for 2 cycles before starting the program.

Test program (encoded as 32-bit hex, word-addressed):
```
ADD x3, x1, x2   →  32'h002081B3   # x3 = x1 + x2
AND x4, x1, x2   →  32'h0020F233   # x4 = x1 & x2
OR  x5, x1, x2   →  32'h0020E2B3   # x5 = x1 | x2
SUB x6, x1, x2   →  32'h40208333   # x6 = x1 - x2
```

With x1=10, x2=3:
- x3 = 13
- x4 = 2  (0b1010 & 0b0011 = 0b0010)
- x5 = 11 (0b1010 | 0b0011 = 0b1011)
- x6 = 7

Run for at least 10 clock cycles after the last instruction enters IF, then read back the register file.

---

## Running the tests

```bash
mkdir -p sim_out && cd sim_out

# Compile all sources needed for integration
xvlog --sv \
  ../src/sources_1/Generic/PosEdgeRegister.sv \
  ../src/sources_1/Generic/Adder.sv \
  ../src/sources_1/Generic/mux1_2.sv \
  ../src/sources_1/Generic/mux2_4.sv \
  ../src/sources_1/Generic/mux3_8.sv \
  ../src/sources_1/IF/InstructionMemory.sv \
  ../src/sources_1/IF/InstructionFetch.sv \
  ../src/sources_1/ID/RegisterFile.sv \
  ../src/sources_1/ID/ImmediateExtend.sv \
  ../src/sources_1/ID/ControlUnit.sv \
  ../src/sources_1/ID/InstructionDecode.sv \
  ../src/sources_1/Buffers/IF_ID_Buffer.sv \
  ../src/sources_1/Buffers/ID_EX_Buffer.sv \
  ../src/sources_1/EX/ALU.sv \
  ../src/sources_1/EX/ALUControl.sv \
  ../src/sources_1/EX/ExecuteStage.sv \
  ../src/sources_1/Buffers/EX_MEM_Buffer.sv \
  ../src/sources_1/MEM/DataMemory.sv \
  ../src/sources_1/Buffers/MEM_WB_Buffer.sv \
  ../src/sources_1/WB/WriteBackStage.sv \
  ../src/sources_1/Hazard/ForwardingUnit.sv \
  ../src/sources_1/Hazard/HazardDetectionUnit.sv \
  ../src/sources_1/Top/riscv.sv \
  ../src/sim_1/Integrador/tb_IF_to_WB.sv

xelab -debug typical tb_IF_to_WB -s sim_full
xsim sim_full --runall
```

Expected output ends with `ALL TESTS PASSED`.

---

## Test results

```
--- Stage 6: full pipeline (no hazards) ---
  PASS  x1 = 10: 0x0000000a
  PASS  x2 =  3: 0x00000003
  PASS  x3 = 13 (ADD): 0x0000000d
  PASS  x4 =  2 (AND): 0x00000002
  PASS  x5 = 11 (OR):  0x0000000b
  PASS  x6 =  7 (SUB): 0x00000007

--- Results: 6 passed, 0 failed ---
ALL TESTS PASSED
```

---

## Next: Stage 7 — Hazard Detection + Forwarding Unit

After this stage the pipeline runs correctly only when instructions have no data dependencies (manual NOPs required). Stage 7 adds `ForwardingUnit.sv` and `HazardDetectionUnit.sv` to handle back-to-back dependent instructions automatically.
