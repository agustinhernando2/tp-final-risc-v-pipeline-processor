---
name: board-test
description: >
  Conduce y verifica pruebas del procesador RISC-V sobre la Basys-3 YA programada,
  usando el CLI de host de `tools/gui` (`riscv_debug.py`) sobre la UART: carga un
  programa, lo ejecuta, lee el estado (PC, registros, memoria, latches de pipeline)
  y compara contra el resultado esperado reportando PASS/FAIL. Usar SIEMPRE que el
  usuario quiera correr o probar algo en la placa/FPGA/hardware real: "probá esto en
  la placa", "corré el programa en la FPGA", "cargá y ejecutá en la Basys", "qué da
  x5 en hardware", "verificá los registros/la memoria en la placa", "hacé step a step
  en la placa", "test de load-use / branch / forwarding sobre hardware", "fijate si
  da bien en la placa". También aplica cuando se pide validar un cambio de RTL en la
  placa física en vez de en simulación. NO es para generar el bitstream ni flashear
  la FPGA (eso es la skill `program-board`) ni para problemas de conexión JTAG / placa
  no detectada (eso es `vivado-linux-debug`): esta skill ASUME que la placa ya está
  programada con el top `RiscvTop`.
---

# Pruebas sobre la placa (board-test)

Ejercés el procesador RISC-V sobre la **Basys-3 física** desde la PC: ensamblás un
programa, lo cargás por UART, lo ejecutás y leés el estado de vuelta, y **verificás**
que los registros/memoria coincidan con lo esperado. La herramienta de host es el CLI
`tools/gui/riscv_debug.py` (scriptable; la GUI `gui.py` es Tkinter y no se conduce sin
display). El protocolo lo implementa la `DebugUnit` en la FPGA.

**Precondición:** la placa ya está programada con el bitstream cuyo top es `RiscvTop`.
Si no lo está (o no sabés), eso lo hace la skill `program-board`. Si la placa no aparece
o falla la conexión JTAG, es `vivado-linux-debug`. Esta skill empieza con la placa lista
y conectada por USB.

## Workflow

Seguí estos pasos. No saltees la verificación del puerto: si el puerto está mal, todo
lo demás falla con un timeout confuso.

### 1. Confirmá el entorno serie

```bash
ls /dev/ttyUSB*
```

La Basys-3 expone un FT2232 con **dos** canales: `/dev/ttyUSB0` es **JTAG** (programación)
y `/dev/ttyUSB1` es la **UART de datos** — usá **siempre `/dev/ttyUSB1`**. Si solo ves
`ttyUSB0`, o ninguno, la placa no está conectada/programada: pará y derivá a `program-board`
/ `vivado-linux-debug`. Si `Permission denied`, falta el grupo `dialout` (`sudo usermod -aG
dialout "$USER"` y reloguear) — decíselo al usuario, no lo corras vos sin avisar.

Todos los comandos del CLI se corren **desde `tools/gui/`** (los módulos se importan por
nombre) y con `uv run` (gestiona `.venv`/`pyserial`). Si `uv` no está, el fallback es
`source .venv/bin/activate && python3 ...`.

### 2. Conseguí el programa y su resultado esperado

El CLI acepta `.s`/`.asm` (lo ensambla al vuelo) o `.hex` (`$readmemh`, un word de 32 bits
por línea). Tres orígenes típicos:

- **Programa de ejemplo** en `tools/gui/programs/*.s`. Cada uno arranca con una cabecera
  `# Resultado esperado: ...` — **esa es tu fuente de verdad** para la verificación.
- **Programa que pide el usuario** (te da el asm o el .hex y qué espera).
- **Programa que escribís vos** para aislar un comportamiento (ej. "probá forwarding de
  ADD"). En ese caso, guardá el `.s` en el scratchpad y derivá vos el resultado esperado
  del código antes de correrlo, así tenés contra qué comparar.

Reglas del programa (si las violás, la corrida falla o cuelga):

- **Tiene que terminar en `halt`.** Sin `halt`, `run` no termina y el dump da timeout.
- **Máximo 64 instrucciones** (`IM_WORDS`); se rellena con NOPs hasta 64.
- **Memoria de datos direccionada por palabra:** el offset de un load/store es el índice
  de word, no bytes — `sw x1, 1(x0)` escribe `mem[1]`, no `mem[4]`.
- Subset RV32I que decodifica el HW; **sin** `auipc` ni `nor`. La sintaxis completa
  (registros, inmediatos, labels, pseudo-instrucciones) está en `tools/gui/README.md`.

Para validar el ensamblado **sin** tocar la placa (chequeo de sintaxis offline):
`uv run assembler.py programs/loquesea.s`.

### 3. Cargá, ejecutá y volcá el estado

| Subcomando | Qué hace |
|------------|----------|
| `loadrun <archivo>` | Carga + ejecuta hasta `HALT` + vuelca. **El caso normal de una prueba.** |
| `load <archivo>` | Solo carga (deja el core en READY). |
| `run` | Ejecución continua del programa ya cargado + vuelca. |
| `step` | Entra en paso a paso, avanza **un ciclo** y vuelca (para inspeccionar latches). |
| `info` | Vuelca el estado actual sin ejecutar. |

```bash
cd tools/gui
uv run riscv_debug.py --port /dev/ttyUSB1 loadrun programs/01_branches.s
```

El dump imprime: `PC`, los **32 registros** (`x0..x31`), los **words de memoria distintos
de 0**, y los **25 latches** de los buffers de pipeline (IF/ID, ID/EX, EX/MEM, MEM/WB).
El estado **vive en la FPGA** y persiste entre invocaciones hasta recargar o resetear la
placa, así que podés encadenar `load` y luego varios `step`/`info`.

### 4. Verificá: comparÁ real vs esperado y reportá PASS/FAIL

Este es el corazón de la skill — no te quedes en imprimir el dump. Para cada valor que la
prueba afirma, buscá la línea correspondiente en el dump y comparala explícitamente.

- **Registros:** buscá `x5 = 0x... (N)` en el bloque "Registros". El CLI imprime hex y
  decimal; compará en decimal contra lo esperado de la cabecera/spec.
- **Memoria:** recordá que el índice es **word** (`[3]` = `mem[3]`). Solo se listan los
  words ≠ 0; si esperabas un 0, su ausencia en la lista **es** el 0.
- **PC final:** suele apuntar a la dirección del `halt` (byte-direccionado).
- **Latches** (solo si la prueba es de pipeline/hazard): el orden y nombre de cada campo
  está en `LATCH_FIELDS` de `tools/gui/uart.py`.

Presentá el veredicto como una tabla compacta, por ejemplo:

```
01_branches.s
  x5  esperado 111  obtenido 111  ✅
  x6  esperado 0    obtenido 0    ✅
Resultado: PASS (2/2)
```

Si **algo no coincide**, no lo maquilles: reportá FAIL con el valor real y, si podés,
una hipótesis del porqué (¿el RTL cambió?, ¿el programa esperaba otra cosa?). Para hazards,
volvé a correr con `step` e inspeccioná los latches ciclo a ciclo para localizar la etapa
donde se desvía.

## Diagnóstico de fallas

El protocolo **no tiene checksum ni reintentos**: un solo byte perdido desalinea toda la
transferencia y el dump sale con basura. Ante cualquier resultado raro, el primer reflejo
es **resetear la placa y recargar** el programa.

> **El reset es manual: la `DebugUnit` no tiene comando de reinicio.** No existe un
> subcomando del CLI ni un byte de protocolo para resetear el core — hay que apretar el
> botón de reset de la Basys-3 físicamente. Cuando una corrida lo necesite, **pedíselo al
> usuario** ("apretá el botón de reset de la placa y avisame") en vez de buscar un comando;
> después recargá el programa con `load`/`loadrun`.

| Síntoma | Causa probable / arreglo |
|---------|--------------------------|
| `timeout leyendo un word del dump` | Programa sin `halt` (nunca para); baud equivocado (default 19200); top incorrecto en la FPGA; o la transferencia se desalineó → resetear y recargar. |
| `could not open port` / no aparece `/dev/ttyUSB1` | Placa desconectada o sin programar → `program-board` / `vivado-linux-debug`. |
| `Permission denied: '/dev/ttyUSB1'` | Falta grupo `dialout` o el puerto está ocupado (¿GUI o miniterm abiertos?). |
| `error de ensamblado: línea N: …` | El mensaje da línea y motivo (registro/inmediato/label/mnemónico). Arreglá el `.s`. |
| Valores del dump sin sentido / corridos | Byte perdido (resetear y recargar) o mismatch entre parámetros del RTL (`IM_WORDS`/`RB_DEPTH`/`DM_DEPTH`) y las constantes de `uart.py`. |
| Un resultado da distinto a simulación | Corré el mismo programa por simulación con la skill `run-tests` para aislar si es la placa o el RTL. |

## Referencias

- `tools/gui/README.md` — sintaxis del ensamblador, formato `.hex`, layout de la GUI, prerrequisitos.
- `tools/gui/uart.py` — protocolo (comandos, geometría del dump, `LATCH_FIELDS`).
- `docs/DEBUG_UNIT.md`, `docs/UART.md` — detalle del protocolo y la capa serie.
- Skills relacionadas: `program-board` (generar/flashear el bitstream), `vivado-linux-debug`
  (conexión JTAG), `run-tests` (la misma lógica pero en simulación).
