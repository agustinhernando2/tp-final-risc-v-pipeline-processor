# Stage 7 — Hazard Detection + Forwarding Unit

**Status: DONE**

---

## Files created / modified

| File | Action |
|------|--------|
| `src/sources_1/WB/WriteBackStage.sv` | Created (also satisfies Stage 6) |
| `src/sources_1/Hazard/ForwardingUnit.sv` | Created |
| `src/sources_1/Hazard/HazardDetectionUnit.sv` | Created |
| `src/sources_1/Top/riscv.sv` | Created — full 5-stage pipeline |
| `src/sources_1/Buffers/ID_EX_Buffer.sv` | Updated — added `i_flush`, `i_rs1`, `i_rs2`, `o_rs1`, `o_rs2` |
| `src/sources_1/Buffers/EX_MEM_Buffer.sv` | Updated — added `i_funct3`, `o_funct3` |
| `src/sources_1/EX/ExecuteStage.sv` | Updated — added forwarding muxes (ForwardA/B via `mux2_4`) |
| `src/sources_1/ID/RegisterFile.sv` | Updated — added write-through for WB→ID same-cycle bypass |
| `src/sim_1/Integrador/tb_IF_to_WB.sv` | Created — Stage 6 integration test (NOP-padded, no hazards) |
| `src/sim_1/Hazard/tb_Forwarding.sv` | Created — Stage 7 forwarding and load-use stall test |
| `src/sim_1/Buffers/tb_Buffers.sv` | Updated — connected new ports in ID_EX and EX_MEM instantiations |
| `src/sim_1/EX/tb_ExecuteStage.sv` | Updated — tied forwarding inputs to 0 for standalone unit test |

---

## Design notes

### WriteBackStage

Pure combinational 2:1 mux:
- `i_sel = i_MemToReg`: 0 → ALU result (R/I-type), 1 → memory read data (loads)
- Outputs `o_write_data`, `o_write_reg`, `o_RegWrite` feed back to `instructionDecode`.

### ForwardingUnit

Encoding for `o_ForwardA` / `o_ForwardB`:

| Value | Source |
|-------|--------|
| `2'b00` | Register file (ID/EX buffer `read_data`) |
| `2'b01` | MEM/WB write-back data |
| `2'b10` | EX/MEM ALU result |

Priority: EX/MEM takes precedence over MEM/WB (closer instruction wins). x0 writes are never forwarded (rd=0 check).

### HazardDetectionUnit

Detects **load-use hazards** only (structural and control hazards are handled in later stages):

```
if (ID_EX.MemRead == 1 && ID_EX.rd != 0 &&
    (ID_EX.rd == IF_ID.rs1 || ID_EX.rd == IF_ID.rs2)):
    PCWrite     = 0   // freeze PC
    IF_ID_Write = 0   // freeze IF/ID buffer
    ID_EX_flush = 1   // insert NOP bubble into ID/EX
```

### RegisterFile write-through

The RF now forwards on simultaneous write-read of the same register:
```systemverilog
assign o_read_reg_1 = (i_regWrite && i_write_reg != '0 && i_write_reg == i_read_reg_1)
                      ? i_write_data : r_RF[i_read_reg_1];
```
This resolves the WB→ID same-cycle hazard that the ForwardingUnit cannot cover (the MEM/WB buffer is updated at the same posedge that ID reads the register file, so after that posedge MEM/WB has the NEXT instruction's result).

### RISCV top-level

New top-level ports:
- `i_if_enable`: external enable for PC and IF/ID buffer; intended for program loading and future step-by-step mode (Stage 10)
- `i_imem_wr` / `i_imem_addr` / `i_imem_data`: instruction memory write interface for program loading

Hazard unit drives:
- `w_if_pc_enable = i_if_enable & w_PCWrite` → `InstructionFetch.i_enable`
- `w_if_id_enable = i_if_enable & w_IF_ID_Write` → `IF_ID_Buffer.i_enable`
- `w_ID_EX_flush` → `ID_EX_Buffer.i_flush`

EX/MEM buffer now carries `funct3` so `DataMemory` gets the correct byte/halfword/word access width.

---

## Test results

```
--- Test A: back-to-back RAW hazards (forwarding) ---
  PASS  x1 = 10 (addi x1, x0, 10): 0x0000000a
  PASS  x2 = 13 (addi x2, x1, 3):  0x0000000d
  PASS  x3 = 23 (add  x3, x1, x2): 0x00000017
  PASS  x4 = 13 (sub  x4, x3, x1): 0x0000000d
--- Test B: load-use hazard (1-cycle stall) ---
  PASS  x5 = 10 (lw x5, 0(x0)):    0x0000000a
  PASS  x6 = 23 (add x6, x5, x2):  0x00000017
  PASS  x7 = 10 (sub x7, x3, x2):  0x0000000a

--- Results: 7 passed, 0 failed ---
ALL TESTS PASSED
```

Full suite: **100 tests passing across 9 testbenches** — no regressions.

---

## Running the tests

```bash
# Integration test (Stage 6: no hazards)
bash .claude/skills/run-tests/scripts/run_one.sh tb_IF_to_WB

# Stage 7: forwarding + load-use stall
bash .claude/skills/run-tests/scripts/run_one.sh tb_Forwarding

# Full suite
bash .claude/skills/run-tests/scripts/run_tests.sh
```

---

## Next: Stage 8 — Branch & Jump Handling

Now that forwarding and stalls work, the next step is to handle control hazards from branches and jumps. BEQ/BNE resolve in EX (using the ALU zero flag); on a taken branch, the two instructions behind it in the pipeline (in IF and ID) must be flushed (two NOP bubbles inserted). JAL and JALR are unconditional and need similar flushing plus PC redirection.
