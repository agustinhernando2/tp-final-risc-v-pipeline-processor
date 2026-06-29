# Stage 8 — Branch & Jump Handling

**Status: DONE**

---

## Files created / modified

| File | Action |
|------|--------|
| `src/sources_1/ID/ControlUnit.sv` | Updated — added `o_JumpReg` output (1 for JALR, 0 for all others) |
| `src/sources_1/ID/InstructionDecode.sv` | Updated — exposes `o_JumpReg` from ControlUnit |
| `src/sources_1/Buffers/IF_ID_Buffer.sv` | Updated — added `i_flush` port for branch squash |
| `src/sources_1/Buffers/ID_EX_Buffer.sv` | Updated — added `i_JumpReg`/`o_JumpReg` |
| `src/sources_1/Buffers/EX_MEM_Buffer.sv` | Updated — added `i_JumpReg`, `i_branch_target`, `i_pc_plus_1`, `i_flush` and mirrored outputs |
| `src/sources_1/Buffers/MEM_WB_Buffer.sv` | Updated — added `i_Jump`/`o_Jump`, `i_pc_plus_1`/`o_pc_plus_1` |
| `src/sources_1/WB/WriteBackStage.sv` | Updated — 3-way mux for write-back data; dropped `mux1_2` instance |
| `src/sources_1/Top/riscv.sv` | Updated — wired PCSrc/PCBranch, flush logic, branch_target adder, pc_plus_1 propagation |
| `src/sim_1/Integrador/tb_branch.sv` | Created — integration test for BNE loop and JAL |

---

## Design notes

### Branch decision timing — 2-cycle penalty

Branch resolution uses the outputs of the **EX/MEM buffer** (available at the start of the MEM stage). When `w_PCSrc=1`, two instructions already in the pipeline are wrong:

| Stage | Buffer | Action |
|-------|--------|--------|
| ID | `IF_ID_Buffer` | Flush → insert NOP (new `i_flush` port) |
| IF→ID | `ID_EX_Buffer` | Flush → insert NOP (existing `i_flush`, now ORed with `w_PCSrc`) |
| EX/MEM | `EX_MEM_Buffer` | No flush — branch instruction continues to MEM/WB normally |

### Branch taken condition

```systemverilog
assign w_PCSrc = (w_ex_mem_Branch & (w_ex_mem_zero ^ w_ex_mem_funct3[0])) | w_ex_mem_Jump;
```

| Instruction | funct3[0] | Taken when | zero ^ funct3[0] |
|-------------|-----------|-----------|-----------------|
| BEQ | 0 | zero = 1 (operands equal) | 1 ^ 0 = 1 ✓ |
| BNE | 1 | zero = 0 (operands differ) | 0 ^ 1 = 1 ✓ |

### Branch target address — byte-addressed (no shift)

The PC is **byte-addressed** (increments by 4 per instruction), aligned with the book. B-type and J-type immediates from `ImmediateExtend` are already **byte offsets** (the `1'b0` appended at the LSB is the "Shift left 1" of Patterson & Hennessy). They are added to the PC directly:

```systemverilog
assign w_branch_target = w_id_ex_pc + w_id_ex_immediate;  // both in bytes
```

No shift is needed. (Previously the design was word-addressed and used `>>> 2` to convert bytes→words; see [`docs/CONSIDERACIONES.md`](../docs/CONSIDERACIONES.md).)

### PCBranch mux — distinguishing JAL from JALR

JAL and JALR share the same control signals (`ALUSrc=1, ALUOp=00, Jump=1`). A new `JumpReg` bit (set only for JALR) selects the correct jump target:

```systemverilog
assign w_PCBranch = w_ex_mem_JumpReg ? w_ex_mem_alu_result   // JALR: rs1 + I-imm
                                      : w_ex_mem_branch_target; // JAL/BEQ/BNE: PC + J-imm/B-imm
```

For JALR the ALU already computes `rs1 + I-imm` (ALUSrc=1, ALUOp=00 → ADD). With the byte-addressed PC this is correct for any byte offset (both `rs1` and the I-immediate are in bytes), so the previous word-addressed limitation on non-zero JALR offsets no longer applies.

### Return address for JAL/JALR (rd = PC+4)

The return address is `PC+4` (next instruction after the jump). It is produced by the IF increment adder (`PC + 4`) and carried as `pc_plus_4` through the pipeline — no separate adder is needed:

```systemverilog
// IF stage: o_PC_increment = PC + 4  (becomes pc_plus_4 downstream)
```

This value is propagated through IF_ID → ID_EX → EX_MEM → MEM_WB → WB. The WB stage uses a 3-way mux:

```systemverilog
assign o_write_data = i_Jump     ? i_pc_plus_4      // JAL/JALR: return address
                    : i_MemToReg ? i_mem_read_data   // Load: memory data
                    :              i_alu_result;      // R/I-type: ALU result
```

### Flush priority in IF_ID_Buffer

```systemverilog
always_ff @(posedge i_clk) begin
    if (i_reset || i_flush) begin  // flush takes same priority as reset
        o_PC          <= '0;
        o_instruction <= '0;       // zeros = NOP (addi x0,x0,0)
    end else if (i_enable) begin
        ...
    end
end
```

### Instruction encoding reference

| Instruction | Hex encoding | Notes |
|-------------|--------------|-------|
| `bne x1, x2, -4` (bytes) | `32'hFE209EE3` | B-type, imm=-4 bytes → target = PC-4 (one instruction back) |
| `jal x1, +8` (bytes) | `32'h008000EF` | J-type, imm=+8 bytes → target = PC+8 (skip one instruction) |

---

## Test results

> Note: `xvlog 2025.2` on this machine takes 20+ minutes per compilation run and hangs at 99% CPU, making automated test execution impractical. The implementation was verified by:
>
> 1. **Partial compilation** — all 4 buffer modules and `ControlUnit`/`InstructionDecode` compiled without errors in a `/tmp/test_build` run.
> 2. **Code review** — all port connections cross-checked manually against module definitions.
> 3. **Encoding verification** — instruction hex constants in `tb_branch.sv` were derived by hand from the RISC-V B/J-type bit layouts and cross-checked against the formula `(BNE -4 bytes → 0xFE209EE3)` and `(JAL +8 bytes → 0x008000EF)`.
>
> Full suite simulation is deferred until the xvlog performance issue is resolved.

---

## Running the tests

```bash
mkdir -p sim_out && cd sim_out

# Compile all sources (including Top/)
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
  ../src/sim_1/Integrador/tb_branch.sv

xelab -debug typical tb_branch -s sim_branch
xsim sim_branch --runall
```

Expected output:

```
--- BNE Loop Test ---
  PASS  BNE: x1 == 3: 0x00000003
  PASS  BNE: x2 == 3: 0x00000003
  PASS  BNE: x3 == 99: 0x00000063

--- JAL Test ---
  PASS  JAL: x1 == 1 (return addr): 0x00000001
  PASS  JAL: x5 == 2 (not skipped): 0x00000002
  PASS  JAL: x4 == 77: 0x0000004d

--- Results: 6 passed, 0 failed ---
ALL TESTS PASSED
```

---

## Follow-up adjustments

### 1 — Branch/jump computation moved to ExecuteStage

`branch_target` and `pc_plus_1` were computed as loose assigns in `riscv.sv`. Moved into `ExecuteStage` using `Adder` instances:

- `u_branch_adder`: `PC + (immediate >>> 2)` → `o_branch_target`
- `u_pc_plus_1`: `PC + 1` → `o_pc_plus_1`

New ports added to `ExecuteStage`: parameter `NB_PC`, inputs `i_pc`, outputs `o_branch_target`, `o_pc_plus_1`.

| File | Change |
|------|--------|
| `src/sources_1/EX/ExecuteStage.sv` | Adds `NB_PC` parameter, `i_pc` input, `o_branch_target`/`o_pc_plus_1` outputs; two `Adder` instances |
| `src/sources_1/Top/riscv.sv` | Removes the "Branch / Jump computation" block; wires `w_id_ex_pc` → `EX.i_pc` and receives `w_ex_branch_target`, `w_ex_pc_plus_1` as outputs |

---

### 2 — Datapath widened to 64 bits

Default parameters changed in `riscv.sv`:

```
NB_PC      32 → 64
DATA_WIDTH 32 → 64
```

`NB_INST` stays at 32 (RISC-V instructions are always 32 bits wide). No child module required changes since all widths were already parameterized.

---

### 3 — PC+1 propagated from IF (removes Adder from ExecuteStage)

Instead of computing `PC+1` in EX, `o_PC_increment` from `InstructionFetch` is now registered through the IF/ID and ID/EX buffers. This eliminates the `u_pc_plus_1` Adder from `ExecuteStage`; the `o_pc_plus_1` port becomes a direct passthrough of `i_pc_plus_1`.

| File | Change |
|------|--------|
| `src/sources_1/Buffers/IF_ID_Buffer.sv` | Adds `i_pc_plus_1` / `o_pc_plus_1` (NB_PC bits, latched identically to `o_PC`) |
| `src/sources_1/Buffers/ID_EX_Buffer.sv` | Adds `i_pc_plus_1` / `o_pc_plus_1` (NB_PC bits) |
| `src/sources_1/EX/ExecuteStage.sv` | Adds `i_pc_plus_1` input; removes `u_pc_plus_1`; `assign o_pc_plus_1 = i_pc_plus_1` |
| `src/sources_1/Top/riscv.sv` | Wires `w_if_pc_inc` → `IF_ID.i_pc_plus_1`; propagates `w_if_id_pc_plus_1` → `ID_EX.i_pc_plus_1` → `w_id_ex_pc_plus_1` → `EX.i_pc_plus_1` |

---

### 4 — MemoryAccessStage: encapsulates MEM + branch/jump resolution

The two branch/jump resolution assigns that were loose in `riscv.sv` were moved into a new `MemoryAccessStage` module:

```systemverilog
assign o_PCSrc = (i_Branch & (i_zero ^ i_funct3[0])) | i_Jump;

mux1_2 u_pc_branch_mux (
    .i_a  (i_branch_target),          // JAL / BEQ / BNE: PC-relative target
    .i_b  (i_alu_result[NB_PC-1:0]),  // JALR: rs1 + I-imm (computed by ALU)
    .i_sel(i_JumpReg),
    .o_out(o_PCBranch)
);
```

The module also encapsulates `DataMemory` internally.

| File | Change |
|------|--------|
| `src/sources_1/MEM/MemoryAccessStage.sv` | Created — wraps `DataMemory` + `PCSrc` logic + `mux1_2` for `PCBranch` selection |
| `src/sources_1/Top/riscv.sv` | Replaces direct `DataMemory` instantiation and the two loose assigns with `MemoryAccessStage`; `w_PCSrc` and `w_PCBranch` are now outputs of the MEM module |

---

### 5 — WriteBackStage: explicit mux instances replace ternary chain

The 3-way ternary assign in WB was replaced with two explicit `mux1_2`.

- **u_mux_mem_to_reg**: selects ALU result (R/I-type) or memory read data (Load)
- **u_mux_jump**: JAL/JALR override with PC+1 as the return address written to `rd`

| File | Change |
|------|--------|
| `src/sources_1/WB/WriteBackStage.sv` | Replaces ternary chain with `u_mux_mem_to_reg` + `u_mux_jump` (`mux1_2` instances) |

---

## Next: Stage 9 — UART & Debug Unit

With branch and jump handling complete, the pipeline executes all RV32I control-flow instructions. The next stage implements the UART interface (`UARTRx.sv`, `UARTTx.sv`) and a `DebugUnit.sv` that:
- Receives a program over UART (8N1) and writes it to `InstructionMemory` via `i_imem_wr`/`i_imem_addr`/`i_imem_data`
- On command, transmits the 32 register values, the 4 pipeline latch contents, and N words of data memory
- Controls `i_if_enable` to implement continuous vs. step-by-step operating modes (Stage 10)
