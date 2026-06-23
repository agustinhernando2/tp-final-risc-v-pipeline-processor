# =============================================================================
# build_uart_loopback.tcl  -  Genera el bitstream de UartLoopbackTop (Stage 9a)
# -----------------------------------------------------------------------------
# Flujo no-proyecto (batch). Basys-3 = Artix-7 xc7a35tcpg236-1.
# Uso:
#   vivado -mode batch -source tools/build_uart_loopback.tcl
# Salida:
#   build_uart/UartLoopbackTop.bit
# =============================================================================

set part   "xc7a35tcpg236-1"
set root   [file normalize [file dirname [info script]]/..]
set srcdir "$root/src"
set outdir "$root/build_uart"
file mkdir $outdir

# --- Leer fuentes y constraints ---------------------------------------------
read_verilog -sv [glob $srcdir/sources_1/UART/*.sv]
read_xdc "$srcdir/constrs_1/new/basys3_uart_loopback.xdc"

# --- Síntesis e implementación ----------------------------------------------
synth_design -top UartLoopbackTop -part $part
opt_design
place_design
route_design

# --- Reporte de timing y bitstream ------------------------------------------
report_timing_summary -file "$outdir/timing_summary.rpt"
write_bitstream -force "$outdir/UartLoopbackTop.bit"

puts "=============================================================="
puts "Bitstream generado: $outdir/UartLoopbackTop.bit"
puts "=============================================================="
