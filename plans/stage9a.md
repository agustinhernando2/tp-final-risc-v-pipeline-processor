# Stage 9a — UART (SystemVerilog) + test de eco en placa

**Status:** DONE (HDL listo; falta validación física en la Basys-3)

---

## Files created / modified

| File | Action |
|------|--------|
| `src/sources_1/UART/BaudRateGenerator.sv` | Created — divisor de clock, genera el tick de oversampling |
| `src/sources_1/UART/UartRx.sv` | Created — receptor 8N1, FSM IDLE/START/DATA/STOP |
| `src/sources_1/UART/UartTx.sv` | Created — transmisor 8N1, FSM IDLE/START/DATA/STOP |
| `src/sources_1/UART/Uart.sv` | Created — wrapper: baud gen + RX + TX (tick compartido) |
| `src/sources_1/UART/UartLoopbackTop.sv` | Created — top de prueba: eco RX→TX + LEDs |
| `src/constrs_1/new/basys3_uart_loopback.xdc` | Created — pines Basys-3 (W5/B18/A18/U18/LEDs) |

Build, programación y test de eco se hacen con la skill local **`program-board`**
(`.claude/skills/program-board/scripts/`: `build_bitstream.tcl`, `program_board.tcl`,
`uart_echo_test.py`, `check_board.sh`).

---

## Design notes

- **Config:** 8N1, 19200 baud, oversampling 16×. Clock 100 MHz (Basys-3, pin W5,
  sin MMCM). `N_CONT = 100e6/(19200·16) = 325` → baud real ≈ 19230 (error < 0,2 %).
- **Reset síncrono activo-alto**, igual que el resto del pipeline.
- **Baud gen:** cuenta 0..N_CONT-1 y pulsa `o_tick` en N_CONT-1 (periodo exacto
  de N_CONT ciclos; se corrigió el off-by-one de la referencia que daba N_CONT+1).
- **RX:** muestrea a mitad del start bit (tick `SB_TICK/2-1`) para alinear al centro
  de cada bit; recibe LSB-first metiendo el bit por el MSB del shift register.
- **TX:** carga el byte en START, emite `shiftreg[0]` en DATA, desplaza `>>1`.
- **Loopback:** `r_pending` + `r_tx_busy` para no perder bytes si llega uno mientras
  el TX transmite (la captura de RX tiene prioridad sobre el clear de `r_pending`).
- **No se necesita la DebugUnit** para este test (queda para 9b).

---

## Test results

Sin testbench (por pedido — se prueba en placa). Verificación de HDL con el
toolchain de Vivado:

- `xvlog --sv src/sources_1/UART/*.sv` → analiza los 5 módulos sin errores ni warnings.
- `xelab -debug typical UartLoopbackTop` → elabora la jerarquía completa
  (`BaudRateGenerator → UartRx/UartTx → Uart → UartLoopbackTop`) sin errores ni
  latches inferidos. Snapshot construido OK.

---

## Running the test (en placa)

Usar la skill **`program-board`** (flujo batch, validado: PASS 256/256):

1. `bash .claude/skills/program-board/scripts/check_board.sh` — chequea USB/puertos/pyserial.
2. `vivado -mode batch -source .claude/skills/program-board/scripts/build_bitstream.tcl` — genera el `.bit` (defaults = UartLoopbackTop).
3. `vivado -mode batch -source .claude/skills/program-board/scripts/program_board.tcl` — programa la Basys-3.
4. `python3 .claude/skills/program-board/scripts/uart_echo_test.py --port /dev/ttyUSB1` — eco 0x00..0xFF.
5. (Opcional) El último byte recibido aparece en los 8 LEDs.

---

## Next: Stage 9b — DebugUnit + GUI

9b agrega `DebugUnit.sv` (FSM de comandos de carga de programa y dump de
PC/registros/memoria/latches), integra la `Uart` en `riscv.sv` (top real, en
lugar de `UartLoopbackTop`), y adapta la GUI Python (hoy MIPS, 32-bit) al ISA
RISC-V y al datapath de 64 bits. Reusa los 4 módulos de UART de esta etapa sin cambios.
