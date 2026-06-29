#!/usr/bin/env bash
# run_tests.sh — compile all RISC-V pipeline sources and run every tb_*.sv testbench.
#
# Auto-discovers:
#   sources  → src/sources_1/**/*.sv  (includes Top/)
#   benches  → src/sim_1/***/tb_*.sv
#
# Adding a new stage (MEM, WB, …) requires no changes here: just drop the
# source .sv files under src/sources_1/<STAGE>/ and testbenches under
# src/sim_1/<STAGE>/tb_*.sv and this script picks them up automatically.
#
# Usage: run_tests.sh [PROJECT_ROOT]
# PROJECT_ROOT defaults to four directories above this script
# (.claude/skills/run-tests/scripts/ → project root).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ="${1:-$(cd "$SCRIPT_DIR/../../../.." && pwd)}"
SRC="$PROJ/src/sources_1"
SIM="$PROJ/src/sim_1"
SIMOUT="$PROJ/sim_out"

# ── colours ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'
BOLD='\033[1m'; RESET='\033[0m'

pass=0; fail=0
errors=()

mkdir -p "$SIMOUT"
cp "$SRC/IF/program.hex" "$SIMOUT/" 2>/dev/null || true

# ── auto-discover sources (all stages including Top) ─────────────────────────
mapfile -t SOURCES < <(find "$SRC" -name "*.sv" | sort)

echo -e "${CYAN}${BOLD}=== Compiling ${#SOURCES[@]} source files ===${RESET}"
cd "$SIMOUT"

compile_log=$(xvlog --sv "${SOURCES[@]}" 2>&1)
src_errors=$(echo "$compile_log" | grep -c "^ERROR" || true)
if [[ $src_errors -gt 0 ]]; then
  echo -e "${RED}Source compile FAILED:${RESET}"
  echo "$compile_log" | grep "^ERROR"
  exit 1
fi
echo "Sources OK"

# ── helper: extract top-module name from a testbench file ────────────────────
tb_module() {
  grep -m1 "^module " "$1" | sed 's/module[[:space:]]\+\([^ ;#(]*\).*/\1/'
}

# ── helper: run one testbench ─────────────────────────────────────────────────
run_tb() {
  local tb_file="$1"
  local top; top=$(tb_module "$tb_file")
  local snap="snap_${top}"
  local label; label="$(basename "$(dirname "$tb_file")")/$(basename "$tb_file" .sv)"

  echo ""
  echo -e "${CYAN}${BOLD}--- $label ($top) ---${RESET}"

  # compile testbench
  local tb_log; tb_log=$(xvlog --sv "$tb_file" 2>&1)
  if echo "$tb_log" | grep -q "^ERROR"; then
    echo -e "${RED}  TB compile ERROR${RESET}"
    echo "$tb_log" | grep "^ERROR" | head -5
    errors+=("$label: TB compile failed")
    return
  fi

  # elaborate
  local elab_log; elab_log=$(xelab -debug off "$top" -s "$snap" 2>&1)
  if echo "$elab_log" | grep -q "^ERROR"; then
    echo -e "${RED}  Elaboration ERROR${RESET}"
    echo "$elab_log" | grep "^ERROR" | head -5
    errors+=("$label: elaboration failed")
    return
  fi

  # simulate — strip Vivado boilerplate
  local sim_out; sim_out=$(xsim "$snap" --runall 2>&1 | \
    grep -Ev "setValueForKey|_encode|_decode|^$|Time resolution|Vivado Simulator|Copyright|^Running|xsim#|quit_on_elab|run -all|^exit|INFO:|SW Build|IP Build|SharedData|Start of session|source xsim")

  echo "$sim_out"

  # tally
  local p f
  p=$(echo "$sim_out" | grep -cE "^\s*(PASS|\s*PASS)" || true)
  f=$(echo "$sim_out" | grep -cE "^\s*(FAIL|\s*FAIL)" || true)
  pass=$(( pass + p ))
  fail=$(( fail + f ))

  if echo "$sim_out" | grep -q "ALL TESTS PASSED"; then
    echo -e "${GREEN}  ✓ ALL PASSED ($p)${RESET}"
  elif [[ $f -gt 0 ]]; then
    echo -e "${RED}  ✗ $f FAILED${RESET}"
    errors+=("$label: $f test(s) failed")
  elif [[ $p -eq 0 ]]; then
    echo -e "  (no pass/fail assertions detected — waveform-only TB)"
  fi
}

# ── auto-discover and run all tb_*.sv testbenches ────────────────────────────
mapfile -t TESTBENCHES < <(find "$SIM" -name "tb_*.sv" | sort)

echo ""
echo -e "${CYAN}${BOLD}=== Running ${#TESTBENCHES[@]} testbench(es) ===${RESET}"
for tb in "${TESTBENCHES[@]}"; do
  run_tb "$tb"
done

# ── summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}=============================="
printf "  RESULTS: %d passed, %d failed\n" "$pass" "$fail"
echo -e "==============================${RESET}"

if [[ ${#errors[@]} -gt 0 ]]; then
  echo -e "${RED}Issues:${RESET}"
  for e in "${errors[@]}"; do echo "  - $e"; done
  exit 1
else
  echo -e "${GREEN}ALL TESTS PASSED${RESET}"
fi
