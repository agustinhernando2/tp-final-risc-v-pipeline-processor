# Stage 5 — Data Memory

**Status:** DONE

---

## Files created / modified

| File | Action |
|------|--------|
| `src/sources_1/MEM/DataMemory.sv` | Created |
| `src/sim_1/MEM/tb_DataMemory.sv` | Created |

---

## Design notes

### DataMemory module

- **Location:** `src/sources_1/MEM/DataMemory.sv`
- **Parameters:**
  - `DATA_WIDTH = 32` — word size (bits)
  - `NB_ADDR = 6` — address width; default 64 words (2^6)
- **Ports:**
  - `i_clk`, `i_reset` — clock and reset
  - `i_addr [NB_ADDR-1:0]` — word address
  - `i_write_data [DATA_WIDTH-1:0]` — data to write
  - `i_mem_write` — write enable (synchronous)
  - `i_funct3 [2:0]` — operation selector (width + sign/zero extension)
  - `o_read_data [DATA_WIDTH-1:0]` — combinational read output

### funct3 encoding (RISC-V standard)

| funct3 | Instruction | Operation |
|--------|-------------|-----------|
| `000` | LB / SB | Byte (signed for load, [7:0] for store) |
| `001` | LH / SH | Halfword (signed for load, [15:0] for store) |
| `010` | LW / SW | Word (full 32-bit) |
| `100` | LBU | Byte (zero-extended on load) |
| `101` | LHU | Halfword (zero-extended on load) |
| `110` | LWU | Word (zero-extended on load; same as LW for 32-bit) |

### Write behavior (synchronous)

On each `posedge clk`, if `i_mem_write`:
- funct3[1:0] = `00`: write byte [7:0]
- funct3[1:0] = `01`: write halfword [15:0]
- funct3[1:0] = `10`: write full word [31:0]

Reset zeros all memory. No `initial begin` — synchronous reset is sufficient; the block was redundant and non-synthesizable.

### Read behavior (combinational)

Based on `i_funct3`:
- **LB (000):** Byte [7:0] sign-extended to 32-bit
- **LH (001):** Halfword [15:0] sign-extended to 32-bit
- **LW (010):** Full word [31:0]
- **LBU (100):** Byte [7:0] zero-extended to 32-bit
- **LHU (101):** Halfword [15:0] zero-extended to 32-bit
- **LWU (110):** Full word [31:0] (same as LW for 32-bit data)

---

## Test results

```
--- Full word read/write ---
  PASS  write/read full word: 0xdeadbeef
--- Byte write ---
  PASS  byte write at [7:0]: 0x123456aa
--- Halfword write ---
  PASS  halfword write at [15:0]: 0x1122bbcc
--- Sign extension ---
  PASS  LB sign-extend 0xFF: 0xffffffff
--- Zero extension ---
  PASS  LBU zero-extend 0xFF: 0x000000ff
--- Halfword sign extension ---
  PASS  LH sign-extend 0xFFFF: 0xffffffff
--- Halfword zero extension ---
  PASS  LHU zero-extend 0xFFFF: 0x0000ffff
--- Reset behavior ---
  PASS  memory cleared after reset: 0x00000000
--- Byte write isolation ---
  PASS  byte write preserves upper bits: 0xaabbcc44
--- Positive sign extension ---
  PASS  LB sign-extend 0x7F: 0x0000007f

--- Results: 10 passed, 0 failed ---
ALL TESTS PASSED
```

---

## Running the tests

```bash
mkdir -p sim_out && cd sim_out
cp ../program.hex .

# 1. Compile
xvlog --sv ../src/sources_1/MEM/DataMemory.sv ../src/sim_1/MEM/tb_DataMemory.sv

# 2. Elaborate
xelab -debug typical tb_DataMemory -s sim_snapshot

# 3. Simulate
xsim sim_snapshot --runall
```

Expected output ends with `ALL TESTS PASSED`.

---

## Next: Stage 6 — Write-Back Stage & Full Pipeline

The Write-Back stage (`WriteBackStage.sv`) will mux between ALU result and memory read data based on `MemToReg`. This output feeds back to the Instruction Decode stage's RegisterFile for register write-back. Once WB is complete, all 5 pipeline stages can be wired together in `riscv.sv` to form a complete processor. The first end-to-end test will be a simple ADD followed by NOPs to allow the result to propagate through all stages and confirm correct write-back to the register file.
