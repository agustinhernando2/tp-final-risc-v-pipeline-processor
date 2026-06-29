# Stage 1 — Complete ID: Sign Extension for all RISC-V immediate types

**Status: DONE**

---

## Files created / modified

| File | Action |
|------|--------|
| `src/sources_1/ID/ImmediateExtend.sv` | Created — replaces `SignExtension.v` |
| `src/sources_1/ID/InstructionDecode.sv` | Updated — uses `ImmediateExtend`, adds `i_ImmSrc` port |
| `src/sim_1/ID/tb_ImmediateExtend.sv` | Created — 10 directed tests |

---

## ImmediateExtend.sv

Decodes all five RV32I immediate formats. Accepts the full 32-bit instruction and a 3-bit `ImmSrc` selector; sign-extends to `DATA_WIDTH` (default 32).

| `ImmSrc` | Format | Bit extraction |
|----------|--------|----------------|
| `3'b000` | I-type | `inst[31:20]` |
| `3'b001` | S-type | `{inst[31:25], inst[11:7]}` |
| `3'b010` | B-type | `{inst[31], inst[7], inst[30:25], inst[11:8], 1'b0}` |
| `3'b011` | U-type | `{inst[31:12], 12'b0}` |
| `3'b100` | J-type | `{inst[31], inst[19:12], inst[20], inst[30:21], 1'b0}` |

## InstructionDecode.sv changes

- Replaced `SignExtension` instantiation with `ImmediateExtend`.
- Added `input logic [2:0] i_ImmSrc` port — to be driven by the Control Unit (Stage 2).

---

## Test results

```
--- I-type ---
  PASS  addi x1,x0,-1 → -1 : 0xffffffff
  PASS  addi x1,x0, 5 →  5 : 0x00000005
--- S-type ---
  PASS  sw x2,-4(x1) → -4  : 0xfffffffc
  PASS  sw x3, 8(x1) →  8  : 0x00000008
--- B-type ---
  PASS  beq +8        →  8  : 0x00000008
  PASS  bne -4        → -4  : 0xfffffffc
--- U-type ---
  PASS  lui 0x12345   → 0x12345000 : 0x12345000
  PASS  lui 0xFFFFF   → 0xFFFFF000 : 0xfffff000
--- J-type ---
  PASS  jal +4        →  4  : 0x00000004
  PASS  jal -8        → -8  : 0xfffffff8

--- Results: 10 passed, 0 failed ---
ALL TESTS PASSED
```

---

## Running the tests

From the project root:

```bash
mkdir -p sim_out && cd sim_out

# 1. Compile
xvlog --sv \
  ../src/sources_1/ID/ImmediateExtend.sv \
  ../src/sim_1/ID/tb_ImmediateExtend.sv

# 2. Elaborate
xelab -debug typical tb_ImmediateExtend -s sim_imm

# 3. Simulate
xsim sim_imm --runall
```

Expected output ends with `ALL TESTS PASSED`.

---

## Next: Stage 2 — Control Unit

Create `src/sources_1/ID/ControlUnit.sv`:
- Inputs: `opcode[6:0]`, `funct3[2:0]`, `funct7[6:0]`
- Outputs: `RegWrite`, `MemRead`, `MemWrite`, `MemToReg`, `ALUSrc`, `Branch`, `Jump`, `ALUOp[1:0]`, `ImmSrc[2:0]`
- Cover all opcodes: R, I-arith, Load, Store, Branch, JAL, JALR, LUI
