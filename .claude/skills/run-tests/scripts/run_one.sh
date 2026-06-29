#!/usr/bin/env bash
# run_one.sh — compile all sources and run a single tb_*.sv testbench.
#
# Usage:
#   run_one.sh <name> [PROJECT_ROOT]
#
# <name> is matched loosely against testbench file paths:
#   run_one.sh tb_DataMemory        → exact module name
#   run_one.sh DataMemory           → finds tb_DataMemory.sv
#   run_one.sh MEM/tb_DataMemory    → partial path match
#
# PROJECT_ROOT defaults to four directories above this script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ="${2:-$(cd "$SCRIPT_DIR/../../../.." && pwd)}"
SRC="$PROJ/src/sources_1"
SIM="$PROJ/src/sim_1"
SIMOUT="$PROJ/sim_out"

if [[ $# -lt 1 ]]; then
  echo "Usage: run_one.sh <testbench-name-or-pattern> [PROJECT_ROOT]"
  echo "  Examples:"
  echo "    run_one.sh tb_DataMemory"
  echo "    run_one.sh DataMemory"
  echo "    run_one.sh MEM/tb_DataMemory"
  exit 1
fi

QUERY="$1"

# ── colours ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'
BOLD='\033[1m'; RESET='\033[0m'

# ── find the testbench file ──────────────────────────────────────────────────
# Try exact path first, then progressively looser matches.
resolve_tb() {
  local q="$1"
  # 1. literal path
  [[ -f "$q" ]] && { echo "$q"; return; }
  # 2. relative to sim_1
  [[ -f "$SIM/$q" ]] && { echo "$SIM/$q"; return; }
  # 3. search: exact filename match (tb_<q>.sv or <q>.sv)
  local found
  found=$(find "$SIM" -name "tb_${q}.sv" 2>/dev/null | head -1)
  [[ -n "$found" ]] && { echo "$found"; return; }
  found=$(find "$SIM" -name "${q}.sv" 2>/dev/null | head -1)
  [[ -n "$found" ]] && { echo "$found"; return; }
  # 4. search: partial path/name substring
  found=$(find "$SIM" -name "tb_*.sv" | grep -F "$q" | head -1)
  [[ -n "$found" ]] && { echo "$found"; return; }
  return 1
}

if ! TB_FILE=$(resolve_tb "$QUERY"); then
  echo -e "${RED}ERROR: no testbench found matching '${QUERY}'${RESET}"
  echo "Available testbenches:"
  find "$SIM" -name "tb_*.sv" | sed "s|$SIM/||" | sort | sed 's/^/  /'
  exit 1
fi

echo -e "${CYAN}${BOLD}Testbench: $TB_FILE${RESET}"

# ── compile sources (all stages including Top) ────────────────────────────────
mapfile -t SOURCES < <(find "$SRC" -name "*.sv" | sort)

echo -e "${CYAN}${BOLD}=== Compiling ${#SOURCES[@]} source files ===${RESET}"
mkdir -p "$SIMOUT"
cp "$SRC/IF/program.hex" "$SIMOUT/" 2>/dev/null || true
cd "$SIMOUT"

compile_log=$(xvlog --sv "${SOURCES[@]}" 2>&1)
src_errors=$(echo "$compile_log" | grep -c "^ERROR" || true)
if [[ $src_errors -gt 0 ]]; then
  echo -e "${RED}Source compile FAILED:${RESET}"
  echo "$compile_log" | grep "^ERROR"
  exit 1
fi
echo "Sources OK"

# ── compile testbench ─────────────────────────────────────────────────────────
tb_module() {
  grep -m1 "^module " "$1" | sed 's/module[[:space:]]\+\([^ ;#(]*\).*/\1/'
}

TOP=$(tb_module "$TB_FILE")
SNAP="snap_${TOP}"
LABEL="$(basename "$(dirname "$TB_FILE")")/$(basename "$TB_FILE" .sv)"

echo ""
echo -e "${CYAN}${BOLD}=== Compiling testbench: $LABEL ($TOP) ===${RESET}"

tb_log=$(xvlog --sv "$TB_FILE" 2>&1)
if echo "$tb_log" | grep -q "^ERROR"; then
  echo -e "${RED}Testbench compile FAILED:${RESET}"
  echo "$tb_log" | grep "^ERROR" | head -10
  exit 1
fi
echo "Testbench OK"

# ── elaborate ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}=== Elaborating ===${RESET}"
elab_log=$(xelab -debug off "$TOP" -s "$SNAP" 2>&1)
if echo "$elab_log" | grep -q "^ERROR"; then
  echo -e "${RED}Elaboration FAILED:${RESET}"
  echo "$elab_log" | grep "^ERROR" | head -10
  exit 1
fi
echo "Elaboration OK"

# ── simulate ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}=== Running simulation ===${RESET}"
echo ""

sim_out=$(xsim "$SNAP" --runall 2>&1 | \
  grep -Ev "setValueForKey|_encode|_decode|^$|Time resolution|Vivado Simulator|Copyright|^Running|xsim#|quit_on_elab|run -all|^exit|INFO:|SW Build|IP Build|SharedData|Start of session|source xsim")

echo "$sim_out"

# ── tally ─────────────────────────────────────────────────────────────────────
p=$(echo "$sim_out" | grep -cE "^\s*PASS" || true)
f=$(echo "$sim_out" | grep -cE "^\s*FAIL" || true)

echo ""
echo -e "${BOLD}=============================="
printf "  RESULTS: %d passed, %d failed\n" "$p" "$f"
echo -e "==============================${RESET}"

if echo "$sim_out" | grep -q "ALL TESTS PASSED"; then
  echo -e "${GREEN}ALL TESTS PASSED${RESET}"
  exit 0
elif [[ $f -gt 0 ]]; then
  echo -e "${RED}$f TEST(S) FAILED${RESET}"
  exit 1
elif [[ $p -eq 0 ]]; then
  echo "(no pass/fail assertions detected — waveform-only testbench)"
  exit 0
fi
