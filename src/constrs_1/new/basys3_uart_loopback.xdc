# =============================================================================
# Basys-3 constraints para UartLoopbackTop (test de eco UART, Stage 9a)
# -----------------------------------------------------------------------------
# Top: UartLoopbackTop
# Pines tomados del Basys-3 Master XDC (Digilent). Clock de 100 MHz en W5.
# UART por el puente USB-UART (FT2232): RsRx=B18 (entra al FPGA = i_rx),
# RsTx=A18 (sale del FPGA = o_tx).
# =============================================================================

# --- Reloj 100 MHz -----------------------------------------------------------
set_property PACKAGE_PIN W5 [get_ports i_clk]
    set_property IOSTANDARD LVCMOS33 [get_ports i_clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports i_clk]

# --- Reset (boton central btnC = U18) ----------------------------------------
set_property PACKAGE_PIN U18 [get_ports i_reset]
    set_property IOSTANDARD LVCMOS33 [get_ports i_reset]

# --- USB-UART (puente FT2232) ------------------------------------------------
# RsRx: dato serie que entra al FPGA
set_property PACKAGE_PIN B18 [get_ports i_rx]
    set_property IOSTANDARD LVCMOS33 [get_ports i_rx]
# RsTx: dato serie que sale del FPGA
set_property PACKAGE_PIN A18 [get_ports o_tx]
    set_property IOSTANDARD LVCMOS33 [get_ports o_tx]

# --- LEDs (espejo del ultimo byte recibido) ----------------------------------
set_property PACKAGE_PIN U16 [get_ports {o_led[0]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {o_led[0]}]
set_property PACKAGE_PIN E19 [get_ports {o_led[1]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {o_led[1]}]
set_property PACKAGE_PIN U19 [get_ports {o_led[2]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {o_led[2]}]
set_property PACKAGE_PIN V19 [get_ports {o_led[3]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {o_led[3]}]
set_property PACKAGE_PIN W18 [get_ports {o_led[4]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {o_led[4]}]
set_property PACKAGE_PIN U15 [get_ports {o_led[5]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {o_led[5]}]
set_property PACKAGE_PIN U14 [get_ports {o_led[6]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {o_led[6]}]
set_property PACKAGE_PIN V14 [get_ports {o_led[7]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {o_led[7]}]

# --- Opciones de configuracion (validas para todos los disenos) --------------
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
