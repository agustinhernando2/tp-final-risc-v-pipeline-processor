#!/usr/bin/env bash
# =============================================================================
# build.sh  -  Wrapper de build_bitstream.tcl que mantiene todo en build_out/
# -----------------------------------------------------------------------------
# Corre Vivado en batch y manda el bitstream, los reportes Y el journal/log de
# Vivado a build_out/<TOP>/ (en vez de ensuciar la raiz del repo).
#
# Acepta las mismas variables de entorno que build_bitstream.tcl:
#   TOP, SRC_GLOBS, XDC, PART, OUTDIR
#
# Uso:
#   bash .claude/skills/program-board/scripts/build.sh
#   TOP=RISCV SRC_GLOBS="src/sources_1/**/*.sv" XDC=src/constrs_1/new/riscv.xdc \
#     bash .claude/skills/program-board/scripts/build.sh
# =============================================================================
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOP="${TOP:-UartLoopbackTop}"
OUTDIR="${OUTDIR:-build_out/$TOP}"
export TOP OUTDIR

mkdir -p "$OUTDIR"
exec vivado -mode batch \
    -journal "$OUTDIR/vivado.jou" \
    -log     "$OUTDIR/vivado.log" \
    -source  "$SKILL_DIR/build_bitstream.tcl"
