# Herramientas de host RISC-V (`tools/gui`)

Lado-**PC** del procesador RISC-V: ensamblar programas, cargarlos en la placa,
ejecutarlos y leer su estado (PC, banco de registros y memoria de datos) a través de
la **UART**. Es el host del protocolo que implementa la `DebugUnit` en la FPGA.

Tres formas de usarlo, sobre las mismas dos capas base (`uart.py` + `assembler.py`):

| Componente | Para qué |
|------------|----------|
| **GUI** (`gui.py`) | Interfaz gráfica: editor de asm, compilar, enviar, ejecutar y ver registros/memoria/PC. |
| **CLI** (`riscv_debug.py`) | Línea de comandos: `load`/`run`/`step`/`info`, scriptable. |
| **Ensamblador** (`assembler.py`) | Convierte assembly (`.s`) a código máquina; usable como librería o CLI. |

Para el detalle del protocolo (comandos, endianness, FSM, dump) ver
[`docs/DEBUG_UNIT.md`](../../docs/DEBUG_UNIT.md). Para la capa serie ver
[`docs/UART.md`](../../docs/UART.md).

---

## Estructura del código

| Archivo | Qué es |
|---------|--------|
| `gui.py` | Ventana Tkinter. Reutiliza `uart.py` y `assembler.py`; corre las esperas serie en un hilo aparte para no congelar la UI. |
| `riscv_debug.py` | CLI: parseo de argumentos, subcomandos, impresión del dump. Acepta `.hex` o `.s`. |
| `assembler.py` | Ensamblador de dos pasadas: registra labels y luego codifica. API (`assemble`, `assemble_file`) + CLI. |
| `isa.py` | Tablas del set de instrucciones (opcodes, funct3/7, registros) y los codificadores R/I/S/B/U/J. Toda la "matemática" del encoding vive acá. |
| `uart.py` | Capa de comunicación: protocolo de la `DebugUnit` sobre `pyserial`. |
| `pyproject.toml` | Dependencias para `uv` (solo `pyserial`). |
| `programs/*.s` | Ejemplos comentados (assembly). |
| `programs/demo_add.hex` | Ejemplo en código máquina (`x3 = x1 + x2`). |

La separación `isa.py` (tablas + encoders puros) ↔ `assembler.py` (parseo + labels +
errores) mantiene cada parte corta y testeable por separado.

---

## Prerrequisitos

1. **Hardware:** una **Basys-3** programada con el bitstream cuyo top es `RiscvTop`
   (UART + DebugUnit + core). Para generarlo y cargarlo ver la skill `program-board`.
2. **Puerto serie:** la Basys-3 expone un puente USB-UART **FT2232** con dos canales:
   - `/dev/ttyUSB0` → **JTAG** (programación del bitstream)
   - `/dev/ttyUSB1` → **UART** (datos — el que usan estas herramientas)

   Verificalo con `ls /dev/ttyUSB*` después de conectar la placa.
3. **Permisos:** tu usuario debe poder abrir el puerto. En Linux suele requerir estar
   en el grupo `dialout`:
   ```bash
   sudo usermod -aG dialout "$USER"   # cerrá sesión y volvé a entrar para que aplique
   ```
4. **Python ≥ 3.9** con **`pyserial`** (lo maneja `uv`, ver abajo) y, para la GUI,
   **Tkinter** (viene en la stdlib; el Python de `uv` y `/usr/bin/python3` ya lo traen).

---

## Instalación de dependencias (con `uv`)

La única dependencia externa es `pyserial`, declarada en `pyproject.toml`:

```bash
cd tools/gui
uv sync            # crea .venv/ e instala pyserial
```

A partir de ahí ejecutá con `uv run` (usa el entorno gestionado por uv):

```bash
uv run gui.py                                   # interfaz gráfica
uv run riscv_debug.py --port /dev/ttyUSB1 info  # CLI
uv run assembler.py programs/01_branches.s      # ensamblador
```

> Corré los comandos **desde `tools/gui/`**: los módulos se importan por nombre
> (`import uart`, `import assembler`), así que necesitan estar en el directorio actual.

### Sin `uv` (pip + venv)

```bash
cd tools/gui
python3 -m venv .venv && source .venv/bin/activate
pip install pyserial
python3 gui.py
```

---

## La GUI (`gui.py`)

```bash
uv run gui.py
```

Layout:

- **Barra de conexión:** elegí puerto (autodetectado; `↻` refresca) y baud (default
  19200), y tocá **Conectar**. El indicador pasa a verde.
- **Editor de assembly** (izquierda): escribí o cargá un programa. *Abrir…* /
  *Guardar…* y el combo **Ejemplos** levantan los `.s` de `programs/`.
- **Código máquina** (derecha): el resultado de **Compilar** (índice, hex, binario).
- **Botonera:**
  - **Compilar** — ensambla el editor (no necesita placa; útil offline).
  - **Enviar programa** — compila si hace falta y carga en la `InstructionMemory`.
  - **Ejecución continua** — corre hasta `HALT` y vuelca el estado.
  - **Step** — entra en paso a paso y avanza un ciclo (siguientes toques = un ciclo más).
  - **Obtener info** — vuelca el estado sin ejecutar.
- **Banco de registros / Memoria de datos / PC** (abajo): se llenan con cada volcado.
- **Log:** mensajes y errores del ensamblador o del puerto. Sin conexión, los botones
  de envío avisan en el log en vez de romper.

---

## El ensamblador (`assembler.py`)

```bash
uv run assembler.py entrada.s             # imprime el hex por stdout
uv run assembler.py entrada.s -o salida.hex
```

Como librería:

```python
import assembler
words = assembler.assemble("addi x1, x0, 5\nhalt")   # -> [0x00500093, 0x0000000b]
```

### Sintaxis soportada

- **Una instrucción por línea.** Comentarios con `#` o `//` (hasta fin de línea).
- **Registros:** `x0`–`x31` o sus alias ABI (`zero ra sp gp tp t0–t6 s0–s11 a0–a7`, `fp`).
- **Inmediatos:** decimal, hex (`0x…`), binario (`0b…`), con signo.
- **Labels:** `nombre:` (sola o antes de una instrucción). Los branches y `jal`
  aceptan una label **o** un offset numérico en bytes; el ensamblador calcula el
  offset relativo (PC byte-direccionado, +4 por instrucción).

### Instrucciones (subset RV32I que decodifica el HW)

| Tipo | Instrucciones | Forma |
|------|---------------|-------|
| R | `add sub sll slt sltu xor srl sra or and` | `add rd, rs1, rs2` |
| I-arit | `addi slti sltiu xori ori andi` | `addi rd, rs1, imm` |
| I-shift | `slli srli srai` | `slli rd, rs1, shamt` |
| Load | `lb lh lw lbu lhu lwu` | `lw rd, off(rs1)` |
| Store | `sb sh sw` | `sw rs2, off(rs1)` |
| Branch | `beq bne blt bge bltu bgeu` | `beq rs1, rs2, label` |
| Jump | `jal` / `jalr` | `jal rd, label` / `jalr rd, off(rs1)` |
| U | `lui` | `lui rd, imm20` |
| Parada | `halt` | `halt` |

**Pseudo-instrucciones:** `nop`, `j label`, `mv rd, rs`, `li rd, imm` (12 bits),
`beqz/bnez rs, label`, `ret`.

> **Sin** `auipc` ni `nor` (no los implementa el hardware).
> **Memoria de datos direccionada por palabra:** el offset de un load/store es el
> índice de word (`sw x1, 1(x0)` → `mem[1]`), no un offset en bytes.

---

## La CLI (`riscv_debug.py`)

```
uv run riscv_debug.py --port <PUERTO> [--baud N] <subcomando> [archivo]
```

| Subcomando | Argumento | Qué hace |
|------------|-----------|----------|
| `load` | `<archivo>` | Carga el programa y deja el core en `READY`. |
| `run` | — | Ejecución continua hasta `HALT`, luego vuelca el estado. |
| `loadrun` | `<archivo>` | `load` + `run` en una invocación. |
| `step` | — | Entra en paso a paso, avanza un ciclo y vuelca. |
| `info` | — | Vuelca el estado actual sin ejecutar. |

El `<archivo>` puede ser **`.s`/`.asm`** (se ensambla al vuelo) o **`.hex`** (código
máquina, formato `$readmemh`). Ejemplos:

```bash
uv run riscv_debug.py --port /dev/ttyUSB1 loadrun programs/04_loop_jal.s   # asm
uv run riscv_debug.py --port /dev/ttyUSB1 loadrun programs/demo_add.hex     # hex
```

Cada invocación abre y cierra el puerto, pero el **estado vive en la FPGA**: el
programa cargado persiste entre llamadas hasta recargar o reiniciar la placa.

---

## Ejemplos (`programs/`)

Cada `.s` arranca con una cabecera comentada que explica **qué demuestra** y el
resultado esperado. Todos terminan en `halt`.

| Archivo | Demuestra |
|---------|-----------|
| `01_branches.s` | `beq` no tomado + `bne` tomado: hazard de control y flush del pipeline. |
| `02_load_use.s` | `sw`→`lw`→uso inmediato: dependencia RAW (forwarding + stall load-use). |
| `03_memoria.s` | Stores/loads de byte/half/word: extensión con signo (`lb/lh`) vs sin signo (`lbu/lhu`); usa `lui`. |
| `04_loop_jal.s` | Bucle con branch hacia atrás + subrutina con `jal`/`ret` (`jalr`). |
| `demo_add.hex` | Suma mínima ya en código máquina (`x1=5`, `x2=3`, `x3=8`). |

---

## Formato del programa `.hex`

Un **word hexadecimal de 32 bits por línea** (formato `$readmemh`). El parser ignora
líneas vacías y comentarios (`#`, `//`), y acepta el prefijo opcional `0x`.

Límites (deben coincidir con los parámetros de `RiscvTop` / `DebugUnit`):

- **Máx. 64 instrucciones** (`IM_WORDS`); se rellena con ceros (NOPs) hasta 64.
- El dump devuelve **32 registros** y **64 words** de memoria, cada valor de **64 bits**.

> Si cambiás `IM_WORDS`, `RB_DEPTH` o `DM_DEPTH` en el RTL, actualizá las constantes
> equivalentes en `uart.py` o el dump se desincroniza.

---

## Troubleshooting

| Síntoma | Causa probable / arreglo |
|---------|--------------------------|
| `Permission denied: '/dev/ttyUSB1'` | Falta el grupo `dialout` (ver prerrequisitos) o el puerto está en uso. |
| `No module named '_tkinter'` (al abrir la GUI) | Ese Python no trae el binding de Tk. Usá `uv run gui.py` o `/usr/bin/python3`. |
| `could not open port` / no aparece `/dev/ttyUSB1` | Placa desconectada o sin programar; revisá `ls /dev/ttyUSB*` y `dmesg`. |
| `error de ensamblado: línea N: …` | El mensaje indica línea y motivo (registro/inmediato/label/mnemónico). |
| `timeout leyendo un word del dump` | Baud incorrecto, top equivocado en la FPGA, o la transferencia se desalineó. |
| Valores del dump sin sentido | Mismatch entre los parámetros del RTL y las constantes de `uart.py`. |

> El protocolo **no tiene checksum ni reintentos**: un byte perdido desalinea toda la
> transferencia. Ante dudas, reiniciá la placa y recargá el programa. Ver limitaciones
> en [`docs/DEBUG_UNIT.md` §13](../../docs/DEBUG_UNIT.md#13-limitaciones-conocidas).

---

## Estado

UART + carga de programa + debug continuo y paso a paso están **validados en la
Basys-3 física** (el SoC corre a 50 MHz vía MMCM; ver *Known Issues* en
[`CLAUDE.md`](../../CLAUDE.md)). El ensamblador está verificado contra los encodings
de referencia del hardware.
