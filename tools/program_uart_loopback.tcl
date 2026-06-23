# =============================================================================
# program_uart_loopback.tcl  -  Programa la Basys-3 con el bitstream (Stage 9a)
# -----------------------------------------------------------------------------
# Requiere la placa conectada por USB y los drivers del cable Digilent
# instalados. La config es volátil (se pierde al apagar la placa).
# Uso:
#   vivado -mode batch -source tools/program_uart_loopback.tcl
# =============================================================================

set root [file normalize [file dirname [info script]]/..]
set bit  "$root/build_uart/UartLoopbackTop.bit"

if {![file exists $bit]} {
    puts "ERROR: no existe $bit. Corré primero build_uart_loopback.tcl"
    exit 1
}

open_hw_manager
connect_hw_server
open_hw_target

set dev [lindex [get_hw_devices] 0]
current_hw_device $dev
refresh_hw_device -update_hw_probes false $dev

set_property PROGRAM.FILE $bit $dev
program_hw_devices $dev
refresh_hw_device $dev

puts "=============================================================="
puts "Placa programada con UartLoopbackTop."
puts "=============================================================="

close_hw_target
disconnect_hw_server
close_hw_manager
