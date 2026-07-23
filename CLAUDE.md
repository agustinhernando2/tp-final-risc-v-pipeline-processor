# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a RISC-V 5-stage pipelined processor implemented in SystemVerilog, targeting the **Basys-3 FPGA** board. The design follows the classic Patterson & Hennessy pipeline: **IF → ID → EX → MEM → WB**. The datapath is 32-bit (`DATA_WIDTH=32`, RV32); the PC is kept 64-bit (`NB_PC=64`). The synthesis top (`RiscvTop`) exposes a UART interface (`i_rx`/`o_tx`) for loading programs and interacting with the processor.

## Toolchain

The project uses **Xilinx Vivado** for synthesis, simulation, and FPGA programming. There is no Makefile; all build/sim operations go through the Vivado GUI or `vivado -mode tcl`.

**Running a simulation (Vivado GUI):**
1. Open `project_1/project_1.xpr` in Vivado.
2. Set the desired testbench as the active simulation source.
3. Run Simulation → Run Behavioral Simulation.

**Running a specific testbench from CLI:**
```bash
mkdir -p sim_out && cd sim_out
xvlog --sv ../src/sources_1/**/*.sv ../src/sim_1/<tb_dir>/<tb_file>.sv
xelab -debug typical <top_module> -s sim_snapshot
xsim sim_snapshot --runall
```

All build artifacts (`xsim.dir/`, `work/`, `*.log`, `*.pb`, `webtalk*`) land in `sim_out/` and are git-ignored.

The `program.hex` file loaded into `InstructionMemory` at simulation start must be present in the xsim working directory (Vivado copies it automatically when launched from the project).

### Key Design Conventions

- **Language:** SystemVerilog. Use `logic` instead of `reg`/`wire`, `always_ff` for sequential, `always_comb` for combinational. Never use plain `always`.
- **Port naming:** `i_` prefix for inputs, `o_` prefix for outputs, `w_` prefix for internal wires, `r_` prefix for registers/state.
- **Parameterization:** All widths (PC, instruction, register address, data) are parameters; default is 32-bit. Do not hardcode widths.
- **Instruction memory:** array of `2^NB_ADDR` 32-bit words. The PC is **byte-addressed**, so the fetch indexes the array with `PC >> 2` (`i_PC[NB_ADDR+1:2]`). Loaded from `program.hex` via `$readmemh` at simulation init (debug write port still uses word indices); in hardware the program is loaded over UART. **The memories are not cleared on reset** — the synchronous reset branch was removed from `InstructionMemory.sv`/`DataMemory.sv` so the arrays infer BRAM (this is what closed timing at 75 MHz; see Timing below).
- **PC increment unit:** Adds 4 (byte-addressed), aligned with Patterson & Hennessy — the PC indexes bytes. Branch/jump immediates from `ImmediateExtend` are byte offsets and are added to the PC directly (no shift). 

## Git Conventions

Commits go directly to `master`. Commit messages must be brief and in English, using the conventional commit format:

```
type(scope): short description
```

Common types: `feat`, `fix`, `refactor`, `test`, `chore`, `docs`.

Do not add `Co-Authored-By` or any mention that the commit was written by Claude.

### Branch naming → versioning

| Branch prefix | Effect |
|---------------|--------|
| `feature/*`, `feat/*` | minor version bump |
| `fix/*`, `hotfix/*` | patch version bump |
| `release/*` | major version bump |
| `doc/*`, `docs/*` | no version change or release (documentation only) |
| `chore/*` | patch version bump (minor maintenance) |
| `test/*` | test cases added |

### Project tracking

The plan files are the single source of truth for progress. Keep them in sync with the code — a stage is not "done" until its tracking is updated.

- **Where progress lives:** `plans/plan.md` holds the deliverables table with a `Status` column (`DONE` / `IN PROGRESS` / `PENDING`) per stage. Each stage also has a `plans/stageN.md` detail file with its own `**Status:**` header, files touched, design notes, and pasted test output.
- **Before starting work:** read `plans/plan.md` and pick the first stage that is not `DONE`. Stages are ordered by dependency (bottom-up, simplest instruction first) — do not skip. Then read that stage's `plans/stageN.md` for the exact contract (modules, ports, truth tables) before writing any code.
- **When closing a stage:** update its `plans/stageN.md` — set `**Status:** DONE`, list files created/modified, paste the verbatim `run-tests` output in *Test results*, and fill the *Next: Stage N+1* handoff paragraph. Then flip that stage's row in `plans/plan.md` to `DONE`.
- **Acceptance gate:** never mark a stage `DONE` with failing tests. The simulation must end in `ALL TESTS PASSED` (run via the `run-tests` skill). Physical-board validation (`program-board` / `board-test`) happens at integration milestones, not every stage.
- **When the user asks for project status:** report from `plans/plan.md` (the Status column) and the `**Status:**` headers of the `stageN.md` files — do not infer progress from the code or git history alone.
