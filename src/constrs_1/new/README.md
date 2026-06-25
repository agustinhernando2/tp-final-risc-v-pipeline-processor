# Constraints (XDC) — Basys-3

Archivos de restricciones (`.xdc`) que mapean los **puertos del módulo top** a los
**pines físicos** de la placa Basys-3 (FPGA Artix-7 `xc7a35tcpg236-1`), además de
fijar el período de clock y el estándar de I/O.

## `basys3_uart_loopback.xdc`

Constraints para el top **`UartLoopbackTop`** (test de eco UART, Stage 9a).
Habilita solo los pines que ese diseño usa:

| Puerto del top | Pin | Descripción |
|----------------|-----|-------------|
| `i_clk` | W5 | Clock de 100 MHz on-board (período 10 ns) |
| `i_reset` | U18 | Botón central `btnC` (reset síncrono activo-alto) |
| `i_rx` | B18 | `RsRx`: línea serie que entra al FPGA (puente USB-UART FT2232) |
| `o_tx` | A18 | `RsTx`: línea serie que sale del FPGA hacia el puente USB-UART |
| `o_led[0]` … `o_led[7]` | U16, E19, U19, V19, W18, U15, U14, V14 | LEDs `LD0`–`LD7` (espejo del último byte recibido) |

Todos los I/O usan `LVCMOS33`. El archivo también incluye `create_clock` sobre
`i_clk` (10 ns) y las opciones de configuración (`CONFIG_VOLTAGE 3.3`, `CFGBVS VCCO`).

## `basys3_riscv.xdc`

Constraints para el top **`RiscvTop`** (procesador completo: UART + DebugUnit +
core RISC-V, Stage 9b). Usa **los mismos pines** que el loopback (`i_clk`=W5,
`i_reset`=U18, `i_rx`=B18, `o_tx`=A18, `o_led[0..7]`), pero ahora los LEDs muestran
el **estado one-hot de la DebugUnit** en vez del último byte recibido. Es el XDC que
se usa al sintetizar el procesador para la placa.

### Importante

Los nombres en el XDC (`get_ports i_clk`, `i_rx`, `o_led[0]`, …) tienen que
coincidir **exactamente** con los puertos del módulo top que se sintetiza. Por eso
hay un XDC por top: `basys3_uart_loopback.xdc` para `UartLoopbackTop` y
`basys3_riscv.xdc` para `RiscvTop`.

## Referencia: XDC completo de la Basys-3 (online)

Este archivo es un **subconjunto** del *Basys-3 Master XDC* oficial de Digilent,
que lista **todos** los pines de la placa (switches, botones, 7-seg, VGA, Pmods,
USB-HID, etc.) comentados. Para habilitar un pin nuevo: copiar la línea
correspondiente del master, descomentarla y renombrar `get_ports` al puerto del top.

- **Basys-3 Master XDC (Digilent):**
  <https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc>
- Repo con los master XDC de todas las placas Digilent:
  <https://github.com/Digilent/digilent-xdc>
- Referencia de la placa (pinout, periféricos):
  <https://digilent.com/reference/programmable-logic/basys-3/reference-manual>
