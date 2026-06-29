---
name: program-board
description: >
  Genera el bitstream (binario) del procesador RISC-V y lo carga en la placa
  Basys-3, y corre la prueba de eco de la UART. Usar esta skill SIEMPRE que el
  usuario pida "generar el binario/bitstream", "crear el .bit", "sintetizar para
  la placa", "cargar/programar/flashear la FPGA", "subir el diseño a la Basys-3",
  "probar la UART", "test de eco", "loopback", o cuando quiera validar cualquier
  top module en hardware real. También aplica al construir el RISCV completo, no
  solo el UartLoopbackTop. Cubre el flujo batch de Vivado (no hay .xpr commiteado)
  y el chequeo previo del entorno serie.
---

# Programar la Basys-3 y probar la UART

Flujo validado en hardware para **construir un bitstream, cargarlo en la Basys-3
y probar la UART**. El proyecto **no tiene `.xpr` commiteado** (está en
`.gitignore`), así que todo va por **Vivado en modo batch con Tcl** — reproducible
y sin depender de la GUI.

**Placa:** Basys-3 (Artix-7 `xc7a35tcpg236-1`), clock 100 MHz en W5. El puente
USB-UART es un **FT2232** que expone dos canales: **`/dev/ttyUSB0` = JTAG**
(programación) y **`/dev/ttyUSB1` = UART** (datos).

**Todos los artefactos van a `build_out/<TOP>/`** (gitignored, igual que
`sim_out/`): el `.bit`, el `timing_summary.rpt` y hasta el `vivado.jou`/`.log`.
La raíz del repo queda limpia.

Scripts en `scripts/` (parametrizables por variables de entorno, con defaults
para el test de UART loopback):

| Script | Qué hace |
|--------|----------|
| `build.sh` | Wrapper: corre el build y deja todo en `build_out/<TOP>/` |
| `program.sh` | Wrapper: programa la placa y deja los logs en `build_out/<TOP>/` |
| `build_bitstream.tcl` | Sintetiza + implementa + escribe el `.bit` (lo llama `build.sh`) |
| `program_board.tcl` | Carga el `.bit` por JTAG, config volátil (lo llama `program.sh`) |
| `uart_echo_test.py` | Envía bytes por serie y verifica el eco |
| `check_board.sh` | Chequeo previo: USB, puertos serie, pyserial |

---

## Paso a paso (orden exacto que funciona)

### Paso 0 — (opcional pero recomendado) Chequear HDL antes del build

Un build completo tarda minutos; un error de sintaxis se detecta en segundos.
Antes de sintetizar, elaborar con el toolchain de simulación para fallar rápido:

```bash
mkdir -p /tmp/elabchk && cd /tmp/elabchk
xvlog --sv <fuentes .sv>            # analiza; debe terminar sin errores
xelab -debug typical <TOP> -s snap  # elabora la jerarquía; sin latches/errores
```

Si compila y elabora limpio, recién ahí conviene gastar tiempo en el build.

### Paso 1 — Chequear el entorno y la placa

```bash
bash .claude/skills/program-board/scripts/check_board.sh
```

Confirma que: (a) la placa enumera en USB (`0403:6010`), (b) hay
`/dev/ttyUSB0`/`ttyUSB1`, (c) `pyserial` está en el `python3` correcto.

**Dos trampas habituales** (las dos aparecieron en la práctica):
- **Cable Digilent sin drivers:** si la placa no sale en `lsusb` o Vivado no abre
  el hw_target → usar la skill `vivado-linux-debug`.
- **pyserial en otro Python:** puede haber varios `python3` (ej. linuxbrew vs
  sistema). `pip` puede instalar en uno y el script correr en otro. Instalar
  siempre con el **mismo** intérprete que corre el test:
  ```bash
  python3 -m pip install --break-system-packages pyserial
  ```
  (El flag `--break-system-packages` es por PEP 668 en entornos gestionados por
  el SO; es seguro para esta herramienta.)

### Paso 2 — Generar el bitstream

Para el test de UART loopback (defaults):

```bash
bash .claude/skills/program-board/scripts/build.sh
```

Para otro top (ej. el procesador completo) se parametriza por entorno:

```bash
TOP=RISCV \
SRC_GLOBS="src/sources_1/**/*.sv" \
XDC=src/constrs_1/new/riscv.xdc \
bash .claude/skills/program-board/scripts/build.sh
```

El build tarda algunos minutos y **no necesita la placa** — conviene lanzarlo en
segundo plano. Al terminar imprime `Bitstream generado: build_out/<TOP>/<TOP>.bit`
y debe decir **0 Errors** (idealmente 0 warnings). Mirar también
`build_out/<TOP>/timing_summary.rpt` (el slack debe ser positivo / WNS ≥ 0).

### Paso 3 — Programar la placa

Con la placa conectada y enumerada (Paso 1 OK):

```bash
bash .claude/skills/program-board/scripts/program.sh
# o, para otro bitstream:
BIT=build_out/RISCV/RISCV.bit bash .claude/skills/program-board/scripts/program.sh
```

Éxito = aparece `End of startup status: HIGH` y `Placa programada`. La config es
**volátil**: se borra al apagar; reprogramar es solo correr de nuevo este paso.

### Paso 4 — Probar la UART (eco / loopback)

Identificar el puerto UART (el **segundo** canal del FT2232, normalmente
`ttyUSB1`) y correr el test:

```bash
ls /dev/ttyUSB*
python3 .claude/skills/program-board/scripts/uart_echo_test.py --port /dev/ttyUSB1
```

- Sin `--text`, manda el barrido completo `0x00..0xFF` y verifica el eco byte a
  byte. Resultado esperado: **`RESULTADO: PASS`** con `256/256`.
- `--text "hola"` envía ese texto; `--baud N` cambia el baud (default 19200, 8N1).
- En `UartLoopbackTop` el último byte recibido se refleja en los 8 LEDs (chequeo
  visual extra).

---

## Cómo reportar al usuario

Después de correr, informar de forma clara:
- Resultado del build: **Errors / Warnings** y el slack de timing (WNS).
- Resultado del programado: si la placa quedó programada (`startup HIGH`).
- Resultado del test de UART: `N/256` bytes correctos y **PASS/FAIL**.
- Si algo falla, citar la línea de error relevante y mapear a la causa
  (drivers → `vivado-linux-debug`, puerto/permisos, baud, pyserial en otro Python).

## Si el test de UART falla

- `TIMEOUT (no llegó eco)`: ¿bitstream cargado? ¿puerto correcto (probar el otro
  `ttyUSB`)? ¿el top realmente hace eco?
- `MISMATCH`: casi siempre **baud mal** (el baud gen asume clock de 100 MHz) o
  pines RX/TX cruzados en el XDC (Basys-3: `i_rx`=B18, `o_tx`=A18).
- `ModuleNotFoundError: serial`: pyserial está en otro intérprete → Paso 1.
