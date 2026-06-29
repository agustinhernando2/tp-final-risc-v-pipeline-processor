# =============================================================================
# program_board.tcl  -  Programa la Basys-3 con un bitstream (JTAG, volatil)
# -----------------------------------------------------------------------------
# Carga el .bit en la FPGA via hw_server. La configuracion es VOLATIL: se borra
# al apagar la placa (no escribe la flash QSPI). Suficiente para probar.
#
# Requiere: placa conectada por el puerto PROG/UART + drivers del cable Digilent
# instalados (si "open_hw_target" falla -> skill vivado-linux-debug).
#
# Parametrizable por variable de entorno:
#   BIT : ruta del bitstream (default build_out/UartLoopbackTop/UartLoopbackTop.bit)
#
# Uso:
#   vivado -mode batch -source <skill>/scripts/program_board.tcl
#   BIT=build/RISCV/RISCV.bit vivado -mode batch -source <skill>/scripts/program_board.tcl
# =============================================================================

if {[info exists ::env(BIT)] && [string length $::env(BIT)] > 0} {
    set bit $::env(BIT)
} else {
    set bit "build_out/UartLoopbackTop/UartLoopbackTop.bit"
}

if {![file exists $bit]} {
    puts "ERROR: no existe el bitstream '$bit'. Generalo primero con build_bitstream.tcl"
    exit 1
}

open_hw_manager
connect_hw_server
open_hw_target

# Primer dispositivo de la cadena JTAG (en la Basys-3 es el unico: xc7a35t).
set dev [lindex [get_hw_devices] 0]
current_hw_device $dev
refresh_hw_device -update_hw_probes false $dev

set_property PROGRAM.FILE $bit $dev
program_hw_devices $dev
refresh_hw_device $dev

puts "=============================================================="
puts "Placa programada con: $bit"
puts "(config volatil: se pierde al apagar la placa)"
puts "=============================================================="

close_hw_target
disconnect_hw_server
close_hw_manager
