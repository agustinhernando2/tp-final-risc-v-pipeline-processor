# =============================================================================
# build_bitstream.tcl  -  Genera un bitstream para la Basys-3 (flujo batch)
# -----------------------------------------------------------------------------
# El proyecto NO tiene .xpr commiteado (esta en .gitignore), por eso usamos el
# flujo no-proyecto (non-project mode): leemos fuentes + XDC, sintetizamos,
# implementamos y escribimos el .bit, todo desde Tcl.
#
# Parametrizable por variables de entorno (con defaults para el test de UART):
#   TOP        : modulo top                (default UartLoopbackTop)
#   SRC_GLOBS  : globs de fuentes .sv/.v   (default "src/sources_1/UART/*.sv")
#                Separar varios con espacios, ej:
#                  SRC_GLOBS="src/sources_1/**/*.sv"
#   XDC        : archivo de constraints    (default src/constrs_1/new/basys3_uart_loopback.xdc)
#   OUTDIR     : carpeta de salida         (default build_out/<TOP>)
#   PART       : FPGA part                 (default xc7a35tcpg236-1 = Basys-3 Artix-7)
#
# Uso:
#   vivado -mode batch -source <skill>/scripts/build_bitstream.tcl
#   TOP=RISCV SRC_GLOBS="src/sources_1/**/*.sv" XDC=src/constrs_1/new/riscv.xdc \
#     vivado -mode batch -source <skill>/scripts/build_bitstream.tcl
# Salida: $OUTDIR/<TOP>.bit  (+ timing_summary.rpt)
# =============================================================================

proc env_or {name default} {
    if {[info exists ::env($name)] && [string length $::env($name)] > 0} {
        return $::env($name)
    }
    return $default
}

set top       [env_or TOP       "UartLoopbackTop"]
set src_globs [env_or SRC_GLOBS "src/sources_1/UART/*.sv"]
set xdc       [env_or XDC       "src/constrs_1/new/basys3_uart_loopback.xdc"]
set part      [env_or PART      "xc7a35tcpg236-1"]
set outdir    [env_or OUTDIR    "build_out/$top"]

file mkdir $outdir

# --- Leer fuentes (expande cada glob) ---------------------------------------
set files {}
foreach g $src_globs {
    foreach f [glob -nocomplain $g] { lappend files $f }
}
if {[llength $files] == 0} {
    puts "ERROR: SRC_GLOBS no encontro ningun archivo: $src_globs"
    exit 1
}
puts "Leyendo [llength $files] fuente(s) para top '$top' (part $part):"
foreach f $files { puts "  - $f" }
read_verilog -sv $files

# --- Constraints ------------------------------------------------------------
if {[file exists $xdc]} {
    read_xdc $xdc
} else {
    puts "ADVERTENCIA: no existe el XDC '$xdc' (sigo sin constraints de pines)."
}

# --- Sintesis + implementacion ----------------------------------------------
synth_design -top $top -part $part
opt_design
place_design
route_design

# --- Reportes + bitstream ---------------------------------------------------
report_timing_summary -file "$outdir/timing_summary.rpt"
write_bitstream -force "$outdir/$top.bit"

puts "=============================================================="
puts "Bitstream generado: $outdir/$top.bit"
puts "Timing: $outdir/timing_summary.rpt"
puts "=============================================================="
