# Stage 0 — Fix Existing Bugs

## Files created

### `src/sources_1/ID/RegisterFile.sv`
Replaces `RegisterFile.v`. Fixes:
- Array dimensions corrected: `logic [DATA_WIDTH-1:0] r_RF [0:2**NB_REG-1]` (was `reg [2**NB_REG-1:0] r_RF [DATA_WIDTH-1:0]`)
- Missing comma after `NB_REG = 5` added
- Trailing comma in port list removed
- Reset now zeroes all registers including x0 and x1 (previously wrote `32'b10` and `32'b01`)
- Write guarded with `i_write_reg != '0` to enforce x0 hardwired-zero
- Converted to SV: `logic`, `always_ff`, `int` loop variable

### `src/sources_1/ID/InstructionDecode.sv`
Replaces `InstructionDecode.v`. Fixes:
- Duplicate `i_regWrite` port removed
- `i_read_reg_1` / `i_read_reg_2` removed from ports — rs1/rs2 derived internally from `i_instruction[19:15]` and `[24:20]`
- `o_rd` output added, driven by `i_instruction[11:7]`
- `o_immediate` width is now explicit `DATA_WIDTH` (was `2**NB_REG`)
- `SignExtension` instantiated with `#(.IMMEDIATE_SIZE(12), .DATA_SIZE(DATA_WIDTH))` — fixes 64-bit default mismatch
- All trailing commas removed
- Converted to SV

### `src/sim_1/ID/tb_RegisterFile.sv`
Unit testbench for `RegisterFile`. Five tests:
1. x0 reads 0 after reset
2. Write `0xDEADBEEF` to x1, read it back
3. Simultaneous dual-port read (x1 and x2)
4. Write to x0 is ignored (hardwired zero)
5. Reset clears x1 and x2

## How to verify

### Commands used

```bash
mkdir -p sim_out && cd sim_out

# 1. Compile
xvlog --sv ../src/sources_1/ID/RegisterFile.sv ../src/sim_1/ID/tb_RegisterFile.sv
```
`xvlog` is the Vivado SystemVerilog compiler. The `--sv` flag tells it to parse both files as SystemVerilog (required for `always_ff`, `logic`, `int`, etc.). Each file is analyzed into the default `work` library and checked for syntax and semantic errors before any simulation is attempted.

```bash
# 2. Elaborate
xelab -debug typical tb_RegisterFile -s sim_rf
```
`xelab` links the compiled design, resolves all module instantiations, and builds the simulation snapshot named `sim_rf`. `-debug typical` enables signal visibility in the waveform viewer (needed if you later want to inspect signals in the Vivado GUI). The top-level module is `tb_RegisterFile`.

```bash
# 3. Simulate
xsim sim_rf --runall
```
`xsim` loads the snapshot and `--runall` runs the simulation until `$finish` is called. All `$display` output (pass/fail messages) is printed to stdout here.

### Expected output

```
Test 1: x0 reads 0 after reset
  PASS  x0 after reset: got 0x00000000
Test 2: write 0xDEADBEEF to x1, read back
  PASS  x1 read back: got 0xdeadbeef
Test 3: write 0x12345678 to x2, read back
  PASS  x1 still holds: got 0xdeadbeef
  PASS  x2 read back: got 0x12345678
Test 4: attempt to write 0xFFFFFFFF to x0 (must be ignored)
  PASS  x0 hardwired zero: got 0x00000000
Test 5: reset clears x1 and x2
  PASS  x1 after reset: got 0x00000000
  PASS  x2 after reset: got 0x00000000

--- Results: 7 passed, 0 failed ---
ALL TESTS PASSED
$finish called at time : 47 ns : File "src/sim_1/ID/tb_RegisterFile.sv" Line 125
```

## Simulation run (Vivado 2025.2, 2026-05-14)

```
****** xsim v2025.2 (64-bit)
  **** Start of session at: Thu May 14 22:27:26 2026

Test 1: x0 reads 0 after reset
  PASS  x0 after reset: got 0x00000000
Test 2: write 0xDEADBEEF to x1, read back
  PASS  x1 read back: got 0xdeadbeef
Test 3: write 0x12345678 to x2, read back
  PASS  x1 still holds: got 0xdeadbeef
  PASS  x2 read back: got 0x12345678
Test 4: attempt to write 0xFFFFFFFF to x0 (must be ignored)
  PASS  x0 hardwired zero: got 0x00000000
Test 5: reset clears x1 and x2
  PASS  x1 after reset: got 0x00000000
  PASS  x2 after reset: got 0x00000000

--- Results: 7 passed, 0 failed ---
ALL TESTS PASSED
$finish called at time : 47 ns
```
