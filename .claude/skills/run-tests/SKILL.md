---
name: run-tests
description: >
  Run the RISC-V pipeline processor test suite using Vivado's xvlog/xelab/xsim
  toolchain. Use this skill whenever the user says "run tests", "run all tests",
  "run only X", "test DataMemory", "check tests pass", "do tests pass",
  "run simulations", or after implementing or modifying any pipeline stage.
  Also use it proactively after any source file edit to verify nothing regressed.
---

# Run Tests

Two scripts are available. Both auto-discover sources and require no edits when new
stages are added.

---

## Script 1 — Run all testbenches

```bash
bash .claude/skills/run-tests/scripts/run_tests.sh
```

Compiles every `src/sources_1/**/*.sv` (excluding `Top/`) then runs every
`src/sim_1/**/tb_*.sv`, printing a coloured summary. Exits 1 if anything fails.

---

## Script 2 — Run a single testbench

```bash
bash .claude/skills/run-tests/scripts/run_one.sh <name>
```

`<name>` is matched loosely — use any of:

| Invocation | Resolves to |
|-----------|-------------|
| `tb_DataMemory` | `src/sim_1/MEM/tb_DataMemory.sv` |
| `DataMemory` | same (prepends `tb_`) |
| `MEM/tb_DataMemory` | partial path match |

Sources are still compiled in full so cross-module dependencies work. If the name
doesn't match, the script lists all available testbenches and exits 1.

**Use `run_one.sh` when:**
- iterating on a single module during development
- writing or proving a new testbench before running the full suite
- a previous full-suite run failed and you are debugging a specific testbench

---

## Adding a new stage

Drop source files under `src/sources_1/<STAGE>/` and testbenches as
`src/sim_1/<STAGE>/tb_<ModuleName>.sv`. Both scripts pick them up automatically.

---

## Writing a new testbench

Read the canonical template first, then adapt it:

```
.claude/skills/run-tests/references/tb_template.sv
```

Key rules:

- Use `int pass_count` / `int fail_count` — not `integer`.
- The `check(label, got, expected)` task prints `  PASS  label: 0x…` or
  `  FAIL  label: expected 0x…, got 0x…` — keep this exact format so the
  scripts can tally results.
- End every testbench with the fixed summary block:
  ```systemverilog
  $display("\n--- Results: %0d passed, %0d failed ---", pass_count, fail_count);
  if (fail_count == 0)
      $display("ALL TESTS PASSED");
  else
      $display("SOME TESTS FAILED");
  $finish;
  ```
- Sequential DUTs: keep `CLK_PERIOD`, the clock generator, and `tick()`.
- Combinational DUTs: remove all three; use `#1` to let outputs settle.

### Workflow for a new testbench

1. Write `src/sim_1/<STAGE>/tb_<Module>.sv` following the template.
2. Prove it compiles and runs clean:
   ```bash
   bash .claude/skills/run-tests/scripts/run_one.sh <Module>
   ```
3. Once passing, run the full suite to confirm no regressions:
   ```bash
   bash .claude/skills/run-tests/scripts/run_tests.sh
   ```

---

## Reporting results to the user

After the script finishes, report:
- Which script was used (all vs. single).
- The count of testbenches that ran.
- Total pass / fail counts.
- Any elaboration or compile errors, with the relevant ERROR lines quoted.
- If everything passed: confirm clearly with the total test count.
