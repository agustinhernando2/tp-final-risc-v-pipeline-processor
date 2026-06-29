#!/usr/bin/env bash
# =============================================================================
# program.sh  -  Wrapper de program_board.tcl que deja el journal/log en build_out/
# -----------------------------------------------------------------------------
# Programa la Basys-3 con el bitstream y manda el journal/log de Vivado a
# build_out/<TOP>/ (sin ensuciar la raiz).
#
# Acepta las mismas variables de entorno que program_board.tcl:
#   BIT  (ruta del bitstream)   TOP/OUTDIR (solo para ubicar los logs)
#
# Uso:
#   bash .claude/skills/program-board/scripts/program.sh
#   BIT=build_out/RISCV/RISCV.bit bash .claude/skills/program-board/scripts/program.sh
# =============================================================================
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOP="${TOP:-UartLoopbackTop}"
OUTDIR="${OUTDIR:-build_out/$TOP}"

mkdir -p "$OUTDIR"
exec vivado -mode batch \
    -journal "$OUTDIR/vivado_program.jou" \
    -log     "$OUTDIR/vivado_program.log" \
    -source  "$SKILL_DIR/program_board.tcl"
