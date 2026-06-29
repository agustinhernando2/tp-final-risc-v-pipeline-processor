# Trabajo Final — Procesador RISC-V Segmentado (Pipeline de 5 etapas)

**Arquitectura de Computadoras**
**Implementación sobre FPGA Basys-3 (Artix-7 `xc7a35tcpg236-1`)**

| | |
|---|---|
| **Tema** | Diseño de un pipeline RISC-V (RV32I, subconjunto) en SystemVerilog |
| **Placa** | Digilent Basys-3 (Artix-7, speed grade −1) |
| **Toolchain** | Xilinx Vivado (síntesis, implementación, simulación) |
| **Interfaz** | UART 8N1 19200 baud + GUI/CLI en Python |

> _Espacio para integrantes / fecha / cátedra._

---

## Índice

1. [Introducción](#1-introducción)
2. [Objetivo](#2-objetivo)
3. [Etapas del Pipeline](#3-etapas-del-pipeline)
4. [Detección de riesgos — Unidad de Stall](#4-detección-de-riesgos--unidad-de-stall)
5. [Redirección de datos — Forwarding Unit](#5-redirección-de-datos--forwarding-unit)
6. [Riesgos de control — Branch y Jump](#6-riesgos-de-control--branch-y-jump)
7. [Debug Unit](#7-debug-unit)
8. [UART, ensamblador y GUI](#8-uart-ensamblador-y-gui)
9. [Modos de operación y HALT](#9-modos-de-operación-y-halt)
10. [Demo — Análisis del pipeline](#10-demo--análisis-del-pipeline)
11. [Análisis de tiempos](#11-análisis-de-tiempos)
12. [Cumplimiento de la consigna](#12-cumplimiento-de-la-consigna)
13. [Conclusión](#13-conclusión)
14. [Bibliografía](#14-bibliografía)

---

## 1. Introducción

**RISC-V** es una arquitectura de conjunto de instrucciones (ISA) abierta y modular,
de tipo **RISC** (conjunto reducido y regular de instrucciones). Este trabajo
implementa el subconjunto entero de 32 bits (**RV32I**) sobre un **procesador
segmentado de cinco etapas**, siguiendo el modelo clásico de Patterson & Hennessy
(*Computer Organization and Design: RISC-V Edition*, cap. 4).

Características principales del diseño:

- **Segmentación (pipelining):** la ejecución se divide en cinco etapas que operan en
  paralelo sobre instrucciones distintas:
  - **IF** — *Instruction Fetch*: búsqueda de la instrucción en la memoria de programa.
  - **ID** — *Instruction Decode*: decodificación y lectura del banco de registros.
  - **EX** — *Execute*: operación aritmético-lógica y cálculo de destinos de salto.
  - **MEM** — *Memory Access*: lectura/escritura de la memoria de datos.
  - **WB** — *Write Back*: escritura del resultado en el banco de registros.
- **Banco de registros fijo:** 32 registros de propósito general (`x0`–`x31`), con `x0`
  cableado a cero. El ancho del datapath es **32 bits** (`DATA_WIDTH = 32`, RV32); el
  PC se mantiene de 64 bits (`NB_PC = 64`).
- **Modelo *load/store*:** las operaciones aritmético-lógicas se hacen entre registros;
  la transferencia con memoria es exclusiva de `lw`/`sw` (y sus variantes de byte/half).
- **Tres formatos base de instrucción** (más U/B/J para inmediatos):
  - **Tipo R** — operaciones registro-registro.
  - **Tipo I** — inmediatos, loads y `jalr`.
  - **Tipo S/B** — stores y branches.
  - **Tipo U/J** — `lui` y `jal`.

El procesador se controla desde una PC mediante **UART**: se carga el programa, se
ejecuta (en modo continuo o paso a paso) y se vuelca el estado completo del procesador
de vuelta a la PC.

> **Figura 1.** Diagrama general del sistema: **PC → UART → Debug Unit → Pipeline**.
>
> ![Diagrama completo del sistema](../img/PLACEHOLDER-diagrama-completo.png)
>
> _(Reemplazar por el diagrama provisto: el host envía comandos/programa por la línea
> serie a la UART; la UART entrega bytes a la Debug Unit; la Debug Unit carga la
> memoria de instrucciones, controla el `enable` del pipeline y lee el estado del core
> para volcarlo.)_

---

## 2. Objetivo

Implementar un procesador RISC-V segmentado en las etapas IF, ID, EX, MEM y WB, capaz
de ejecutar el siguiente subconjunto de instrucciones (la consigna las lista en
mnemónicos **MIPS**; aquí se mapean a sus equivalentes **RISC-V**):

| Grupo | Instrucciones RISC-V implementadas | Opcode |
|-------|------------------------------------|--------|
| **R-type** | `ADD`, `SUB`, `AND`, `OR`, `XOR`, `SLL`, `SRL`, `SRA`, `SLT`, `SLTU` | `0110011` |
| **I-aritm.** | `ADDI`, `ANDI`, `ORI`, `XORI`, `SLTI`, `SLTIU`, `SLLI`, `SRLI`, `SRAI` | `0010011` |
| **Load** | `LB`, `LBU`, `LH`, `LHU`, `LW`, `LWU` | `0000011` |
| **Store** | `SB`, `SH`, `SW` | `0100011` |
| **Branch** | `BEQ`, `BNE` | `1100011` |
| **U-type** | `LUI` | `0110111` |
| **Jump** | `JAL` | `1101111` |
| **Jump-reg** | `JALR` | `1100111` |
| **HALT** | opcode custom-0 (`0x0000000B`) | `0001011` |

> **Mapeo MIPS → RISC-V** (ver [`CONSIDERACIONES.md`](utils/CONSIDERACIONES.md) C-003):
> `SLLV/SRLV/SRAV`→`SLL/SRL/SRA`; `ADDU/SUBU`→`ADD/SUB`; `ADDIU`→`ADDI`;
> `J`→`JAL x0` y `JR`→`JALR x0` (pseudoinstrucciones, sin hardware propio).
> **`NOR` no existe en RISC-V** (no tiene opcode asignado) → se considera *no
> aplicable*. `AUIPC` se removió por no estar pedida.

Requisitos funcionales adicionales (consigna):

- El procesador debe **programarse y reprogramarse por UART**.
- El **clock no debe intervenirse** en ninguna parte de la lógica funcional (se congela
  el procesador con un `enable`, **nunca** gateando el reloj).
- Una **Debug Unit** debe enviar a la PC: el PC, los 32 registros, **el contenido de
  los latches intermedios** y la memoria de datos.
- Dos **modos de operación**: continuo y paso a paso, con el **pipeline vacío** al
  terminar.
- Un **ensamblador** (Assembly → código máquina) y validación **en placa real**.
- Análisis de **timing** y elección de la **frecuencia de funcionamiento**.

---

## 3. Etapas del Pipeline

El núcleo del procesador es el módulo `RISCV` (`src/sources_1/Top/riscv.sv`), que
instancia las cinco etapas y los cuatro buffers de pipeline. Convenciones de diseño:
SystemVerilog (`logic`, `always_ff`, `always_comb`), prefijos `i_`/`o_`/`w_`/`r_`,
**todos los anchos parametrizados**, reset síncrono activo-alto.

> **Figura 2.** Datapath completo del pipeline de 5 etapas con forwarding y hazard
> detection.
>
> ![Datapath del pipeline](../img/PLACEHOLDER-datapath.png)

### 3.1 IF — Instruction Fetch

Módulo `InstructionFetch` (`src/sources_1/IF/InstructionFetch.sv`). Busca la próxima
instrucción y calcula la dirección siguiente.

- **PC byte-addressed:** el PC cuenta **bytes** e incrementa de a **4** (alineado con
  Patterson & Hennessy). La memoria de instrucciones se indexa con `PC >> 2`. Esta
  decisión se documenta en [`CONSIDERACIONES.md`](utils/CONSIDERACIONES.md) C-001.
- **Memoria de instrucciones** (`InstructionMemory`): arreglo de `2^NB_ADDR` words de
  32 bits, con un puerto de escritura para la carga por la Debug Unit.
- **Selección de PC:** un mux elige entre `PC+4` y el destino de salto (`PCBranch`),
  según `PCSrc` (resuelto en MEM).

| Señal | Dir | Significado |
|-------|-----|-------------|
| `i_enable` | in | habilita el PC (congelable por stall / Debug Unit) |
| `i_PCSrc` / `i_PCBranch` | in | redirección de PC (branch/jump tomado) |
| `i_imem_wr/addr/data` | in | escritura de la IM (carga del programa) |
| `o_PC`, `o_PC_increment` | out | PC actual y `PC+4` |
| `o_instruction` | out | instrucción buscada |

### 3.2 ID — Instruction Decode

Módulo `instructionDecode` (`src/sources_1/ID/InstructionDecode.sv`). Decodifica la
instrucción, lee el banco de registros y genera las señales de control. Submódulos:

- **`RegisterFile`** — 32 registros; `x0` cableado a 0; **write-through** combinacional
  (escribe en la 1.ª mitad del ciclo, lee en la 2.ª) que resuelve el hazard de
  distancia 3 (WB→ID en el mismo ciclo). Expone un puerto de lectura de debug.
- **`ControlUnit`** — decodifica el opcode y emite las señales de control
  (`RegWrite`, `ALUSrc`, `ALUOp`, `MemRead`, `MemWrite`, `MemToReg`, `Branch`, `Jump`,
  `JumpReg`, `LUI`, `Halt`).
- **`ImmediateExtend`** — arma y extiende en signo los inmediatos I/S/B/U/J. La
  notación "desordenada" de los inmediatos B/J y el `<<1` implícito se explican en
  [`CONSIDERACIONES.md`](utils/CONSIDERACIONES.md) C-002.

### 3.3 EX — Execute

Módulo `ExecuteStage` (`src/sources_1/EX/ExecuteStage.sv`). Ejecuta la operación
aritmético-lógica y calcula el destino de los saltos.

- **`ALU`** — operaciones `ADD/SUB/AND/OR/XOR/SLL/SRL/SRA/SLT/SLTU` (selección por
  `ALUControl` a partir de `ALUOp` + `funct3` + `funct7[5]`).
- **Muxes de forwarding** (`mux2_4`) en ambos operandos: eligen entre el dato del banco,
  el resultado de EX/MEM o el dato de MEM/WB (ver §5).
- **Mux `ALUSrc`** (`mux1_2`): elige entre el segundo registro y el inmediato.
- **`branch_target = PC + immediate`** (directo, sin shift: el inmediato ya es byte
  offset; ver C-001).

| Entradas clave | Salidas clave |
|----------------|----------------|
| `read_data_1/2`, `immediate`, `pc`, `pc_plus_4`, `funct3`, `funct7_5`, `ALUSrc`, `ALUOp`, `LUI`, `ForwardA/B`, `ex_mem_alu_result`, `wb_write_data` | `alu_result`, `zero`, `read_data_2` (para store, forwardeado), `rd`, `branch_target`, `pc_plus_4` |

### 3.4 MEM — Memory Access

Módulo `MemoryAccessStage` (`src/sources_1/MEM/MemoryAccessStage.sv`). Acceso a la
memoria de datos y **resolución de saltos**.

- **`DataMemory`** — soporta accesos de **byte / halfword / word**, con carga **con
  signo** (`lb`/`lh`) y **sin signo** (`lbu`/`lhu`), según `funct3`. Es **word-addressed**
  (eje de direccionamiento independiente del PC; deuda conocida, C-001). Expone un puerto
  de lectura de debug.
- **Branch/Jump:** evalúa la condición (`zero`/`funct3[0]` para `beq`/`bne`) y genera
  `PCSrc` y `PCBranch`. La resolución ocurre en el **límite EX/MEM** (penalidad de 2
  ciclos por flush).

### 3.5 WB — Write Back

Módulo `WriteBackStage` (`src/sources_1/WB/WriteBackStage.sv`). Selecciona el dato a
escribir en el banco de registros mediante muxes explícitos (`mux1_2`):

- `MemToReg` elige entre el **resultado de la ALU** y el **dato leído de memoria**.
- `Jump` selecciona `PC+4` como dato a escribir (link de `jal`/`jalr`).
- Emite `write_data`, `write_reg` y `RegWrite` de vuelta a la etapa ID.

### 3.6 Buffers de pipeline (latches intermedios)

Entre cada par de etapas hay un **buffer registrado** que propaga datos y control:

| Buffer | Contenido (resumen) |
|--------|----------------------|
| `IF_ID_Buffer` | `PC`, `PC+4`, `instruction` |
| `ID_EX_Buffer` | `PC`, `PC+4`, `read_data_1/2`, `immediate`, `rs1`, `rs2`, `rd`, `funct3`, `funct7_5`, + 11 señales de control |
| `EX_MEM_Buffer` | `alu_result`, `zero`, `read_data_2`, `rd`, `funct3`, `branch_target`, `PC+4`, + control |
| `MEM_WB_Buffer` | `alu_result`, `mem_read_data`, `rd`, `PC+4`, + control |

Estos son precisamente los **latches intermedios** que la Debug Unit vuelca por UART
(ver §7.4). Todos comparten el primitivo `PosEdgeRegister` (flip-flop parametrizado con
reset y enable síncronos), y soportan `flush` (para insertar burbujas / limpiar tras un
salto tomado).

---

## 4. Detección de riesgos — Unidad de Stall

Un **riesgo de datos** ocurre cuando una instrucción necesita un resultado que todavía
no se calculó/escribió. La mayoría se resuelven por *forwarding* (§5), **pero el caso
*load-use* no**: un `lw` produce el dato al final de MEM, demasiado tarde para
adelantarlo a la ALU de la instrucción siguiente.

Módulo `HazardDetectionUnit` (`src/sources_1/Hazard/HazardDetectionUnit.sv`), validado
contra Patterson & Hennessy §4.7 (pp. 303–307). Opera en **ID** y detecta:

```
if (ID/EX.MemRead and ID/EX.Rd != 0 and
    (ID/EX.Rd == IF/ID.Rs1 or ID/EX.Rd == IF/ID.Rs2))
        → STALL
```

El stall **congela PC e IF/ID** (`o_PCWrite=0`, `o_IF_ID_Write=0`) e **inserta una
burbuja** poniendo a 0 el control de ID/EX (`o_ID_EX_flush=1`). Tras un ciclo, el dato
ya está en MEM/WB y el forwarding normal (distancia 2) lo entrega.

> **Línea de tiempo del load-use** (equivale a la Figura 4.57 del libro):
>
> ```
> ciclo:        1    2    3    4    5    6    7
> ld  x2      IF   ID   EX   MEM  WB
> and x2..         IF   ID   ID*  EX   MEM  WB      ← ID se repite (stall)
> (burbuja)             ··   nop  MEM  WB           ← burbuja en ID/EX
> or  ..                IF   IF*  ID   EX   ...     ← IF congelado un ciclo
> ```

> **Mejora sobre el libro:** se añade el guard `ID/EX.Rd != 0`, que evita un stall
> innecesario cuando el load escribe en `x0`. Detalle completo en
> [`hazard-detection-unit.md`](utils/hazard-detection-unit.md).

---

## 5. Redirección de datos — Forwarding Unit

Módulo `ForwardingUnit` (`src/sources_1/Hazard/ForwardingUnit.sv`), validado contra
Patterson & Hennessy §4.7 (Figuras 4.52–4.55). Es **puramente combinacional** y resuelve
los riesgos de datos sin perder ciclos, adelantando el resultado desde un buffer
posterior directamente a la ALU.

Codificación de los selectores (Figura 4.53):

| Valor | Fuente seleccionada |
|-------|----------------------|
| `2'b00` | Banco de registros (ID/EX.read_data) |
| `2'b10` | **EX/MEM** (resultado de ALU, distancia 1) |
| `2'b01` | **MEM/WB** (dato de WB: ALU o memoria, distancia 2) |

Lógica (con prioridad EX/MEM > MEM/WB para el *double hazard*):

```
if (EX/MEM.RegWrite and EX/MEM.Rd != 0 and EX/MEM.Rd == ID/EX.RsN)   ForwardN = 10
else if (MEM/WB.RegWrite and MEM/WB.Rd != 0 and MEM/WB.Rd == ID/EX.RsN) ForwardN = 01
else                                                                  ForwardN = 00
```

Se excluye `x0` (`Rd != 0`) y el dato forwardeado del operando B también alimenta los
**stores** (forwarding a memoria, *Elaboration* p. 302). Detalle completo en
[`forwarding-unit.md`](utils/forwarding-unit.md).

---

## 6. Riesgos de control — Branch y Jump

Los **riesgos de control** aparecen con branches y saltos: cuando se toma uno, las
instrucciones que ya entraron al pipeline detrás de él son incorrectas.

Estrategia: **assume-not-taken + flush**. Los saltos se resuelven en el límite EX/MEM
(inicio de MEM). Cuando `PCSrc=1` (salto tomado), se hace **flush de `IF/ID` y `ID/EX`**
(2 ciclos de penalidad) y el PC se redirige a `PCBranch`.

- `beq`/`bne` comparan vía `zero` y `funct3[0]`.
- `jal` salta a `PC+immediate` y guarda `PC+4` (link) en `rd`.
- `jalr` salta a `rs1+immediate` (salto indirecto / retorno de subrutina).

> **Figura 3.** Formatos de inmediato B-type y J-type (rearmado de bits).
>
> ![Formato B-type](../img/formato-sb-btype.png)
> ![Formato J-type](../img/formato-uj-jtype.png)

Guía de uso de cada instrucción con ejemplos paso a paso en
[`instrucciones.md`](utils/instrucciones.md).

---

## 7. Debug Unit

La **Debug Unit** (`src/sources_1/Debug/DebugUnit.sv`) es una **máquina de estados**
que actúa como **único puente** entre la UART y el pipeline. La UART sólo mueve bytes
sueltos; la Debug Unit los interpreta: carga el programa, arranca/frena el core y
reporta su estado. Es la portación a SystemVerilog (datapath de 32 bits) del
`debug_unit.v` del proyecto MIPS de base.

> **Figura 4.** Integración host ↔ UART ↔ Debug Unit ↔ core.
>
> ![Integración Debug Unit](../img/PLACEHOLDER-debug-integracion.png)
> _(Fuente editable: [`diagrams/host_uart_debug_pipeline.drawio`](diagrams/host_uart_debug_pipeline.drawio).)_

### 7.1 Protocolo de comandos (UART 8N1, MSB-first)

| Byte | Comando | Efecto |
|------|---------|--------|
| `0x01` | `CMD_WRITE_IM` | Iniciar carga del programa |
| `0x02` | `CMD_CONTINUE` | Ejecución continua hasta `HALT` |
| `0x03` | `CMD_STEP_BY_STEP` | Entrar en modo paso a paso |
| `0x04` | `CMD_SEND_INFO` | Volcar el estado sin ejecutar |
| `0x05` | `CMD_STEP` | Avanzar un ciclo |

### 7.2 Máquina de estados

Estados **one-hot** (9 estados; cada uno enciende un LED para depuración visual):

| Estado | Descripción |
|--------|-------------|
| `INITIAL` | Reposo: espera `WRITE_IM` o `SEND_INFO`. |
| `WRITE_IM` | Recibe el programa byte a byte y lo escribe en la IM. |
| `READY` | Programa cargado: espera `CONTINUE` / `STEP_BY_STEP`. |
| `RUN` | Ejecución continua hasta `HALT`. |
| `STEP_MODE` | Paso a paso: avanza un ciclo por comando. |
| `SEND_PC` | Transmite el PC. |
| `SEND_REG` | Transmite los 32 registros. |
| `SEND_MEM` | Transmite la memoria de datos. |
| `SEND_LATCH` | **Transmite los latches intermedios** (buffers de pipeline). |

> **Figura 5.** Diagrama de estados de la Debug Unit.
>
> ![FSM de la Debug Unit](../img/PLACEHOLDER-fsm-debugunit.png)
> _(Fuente editable: [`diagrams/debug_unit_fsm.drawio`](diagrams/debug_unit_fsm.drawio).)_

**Ejecución "Step by Step":** `INITIAL → WRITE_IM → READY → STEP_MODE`. Cada `CMD_STEP`
pone `enable=1` un solo ciclo y vuelca el estado; repite hasta `HALT`.

**Ejecución Continua:** `INITIAL → WRITE_IM → READY → RUN`. El core corre hasta que
`HALT` llega al final del pipeline (`i_halt=1`); ahí la FSM congela el core y arranca el
dump automáticamente.

> **Nota de temporización:** la FSM corre en **flanco descendente** (`negedge`); el
> pipeline en flanco de subida. Así `pipeline_enable`/`imem_wr` quedan estables medio
> ciclo antes del `posedge` que los muestrea (evita carreras). Ver
> [`DEBUG_UNIT.md`](utils/DEBUG_UNIT.md) §9.

### 7.3 El gating del pipeline (clock no intervenido)

La señal `o_pipeline_enable` entra al core como `i_if_enable` y **gatea todo el estado
secuencial** (PC, los cuatro buffers, escritura al banco y a la memoria de datos).
Cuando vale 0, **nada avanza** — pero el **reloj nunca se toca**, cumpliendo el
requisito de la consigna. Esto garantiza que durante la carga y entre pasos el
procesador esté quieto y que un pipeline congelado nunca escriba registros ni memoria.

### 7.4 El dump: PC + registros + memoria + **latches intermedios**

El volcado se transmite siempre en este orden, cada valor de `NB_BYTES = DATA_WIDTH/8`
bytes (= 4) MSB-first:

```
PC  →  reg[0..31]  →  mem[0..DM_DEPTH-1]  →  latch[0..LATCH_COUNT-1]
```

La **cuarta sección** cubre el requisito de la consigna *"el contenido de los latches
intermedios"*. Cada índice es un campo almacenado en uno de los cuatro buffers,
zero-extendido al ancho del dump. El core mapea índice → campo con un mux combinacional
en `riscv.sv`; la Debug Unit lo serializa con el mismo patrón que registros y memoria
(estado `SEND_LATCH`). El mapa de los **25 campos** (`LATCH_COUNT = 25`):

| Idx | Campo | Idx | Campo |
|----:|-------|----:|-------|
| 0 | `IF/ID.PC` | 13 | `EX/MEM.alu_result` |
| 1 | `IF/ID.PC+4` | 14 | `EX/MEM.read_data_2` |
| 2 | `IF/ID.instruction` | 15 | `EX/MEM.branch_target` |
| 3 | `ID/EX.PC` | 16 | `EX/MEM.PC+4` |
| 4 | `ID/EX.PC+4` | 17 | `EX/MEM.rd` |
| 5 | `ID/EX.read_data_1` | 18 | `EX/MEM.funct3` |
| 6 | `ID/EX.read_data_2` | 19 | `EX/MEM.ctrl` |
| 7 | `ID/EX.immediate` | 20 | `MEM/WB.alu_result` |
| 8 | `ID/EX.rs1` | 21 | `MEM/WB.mem_read_data` |
| 9 | `ID/EX.rs2` | 22 | `MEM/WB.PC+4` |
| 10 | `ID/EX.rd` | 23 | `MEM/WB.rd` |
| 11 | `ID/EX.funct` | 24 | `MEM/WB.ctrl` |
| 12 | `ID/EX.ctrl` | | |

Los bits de control de cada buffer se empaquetan en un único word `ctrl` (layout bit a
bit en [`DEBUG_UNIT.md`](utils/DEBUG_UNIT.md) §2). Total del dump:
`(1 + 32 + 64 + 25) × 4 = 488 bytes`.

> **Figura 6.** Vista del dump en la GUI: registros, memoria y **latches intermedios**.
>
> ![Dump en la GUI](../img/PLACEHOLDER-gui-dump.png)

---

## 8. UART, ensamblador y GUI

### 8.1 UART

Implementación propia en SystemVerilog (`src/sources_1/UART/`): `BaudRateGenerator`
(divisor con sobre-muestreo 16×), `UartRx`, `UartTx` y el wrapper full-duplex `Uart`.
Configuración **8N1, 19200 baud**. El error de baud real es **+0,16 %** (muy por debajo
del ±3 % que tolera la UART). Validada por **eco loopback** en placa (256/256 bytes
correctos). Detalle en [`UART.md`](utils/UART.md).

### 8.2 Ensamblador y GUI (lado PC)

En `tools/gui/` (Python):

- **`assembler.py`** — ensambla Assembly RISC-V (`.s`/`.asm`) a código máquina.
- **`uart.py`** — capa de protocolo: arma el binario con zero-padding a `IM_WORDS`,
  envía comandos y reconstruye el dump (PC + registros + memoria + **latches**).
- **`riscv_debug.py`** — CLI (`load`, `run`, `step`, `info`, `loadrun`).
- **`gui.py`** — GUI con editor, vista de código máquina y tablas de registros, memoria
  y **latches intermedios**.

```bash
cd tools/gui && uv sync
uv run riscv_debug.py --port /dev/ttyUSB1 loadrun programs/04_loop_jal.s
```

---

## 9. Modos de operación y HALT

### 9.1 HALT

El TP exige una instrucción de parada y que **el pipeline quede vacío al terminar**. Se
adoptó un **opcode HALT dedicado** (custom-0 de RISC-V = `0x0000000B`), decisión
documentada en [`CONSIDERACIONES.md`](utils/CONSIDERACIONES.md) C-004. La `ControlUnit`
lo decodifica con todas las demás señales en 0; el bit `Halt` viaja por los buffers y se
señaliza `o_halt` **al llegar a WB** (no a MEM), para que la última instrucción real
complete su write-back antes de congelar el pipeline. Las instrucciones posteriores a
HALT son NOPs (la GUI rellena con ceros, que decodifican como no-op), por lo que el
**pipeline queda efectivamente drenado**.

### 9.2 Respuestas a las preguntas de la consigna

> **¿Qué pasa si en memoria no hay una instrucción de parada?**
> El procesador sigue ejecutando indefinidamente lo que haya después del programa
> (NOPs, por el zero-padding); nunca dispara el dump automático. Por eso HALT es
> obligatorio al final del programa.

> **¿Es necesario vaciar la memoria / los registros / el pipeline / la memoria de
> programa al reprogramar?**
> - **Memoria de datos y registros:** no es estrictamente necesario vaciarlos, pero al
>   resetear el core (`i_reset`) se inicializan en 0; conviene para resultados
>   reproducibles.
> - **Pipeline:** sí debe quedar vacío — se garantiza con el padding de NOPs + HALT y el
>   corte del `enable` global.
> - **Memoria de programa:** se reescribe completa en cada carga (`WRITE_IM` escribe los
>   `IM_WORDS`), así que no requiere un borrado aparte.

### 9.3 Modos

- **Continuo:** un comando (`0x02`) y el core corre hasta HALT; ahí se vuelca todo el
  estado.
- **Paso a paso:** cada comando (`0x05`) ejecuta **un ciclo** de reloj y vuelca el
  estado, permitiendo inspeccionar el avance instrucción a instrucción (incluidos los
  latches intermedios).

En ambos casos el pipeline queda vacío al terminar.

---

## 10. Demo — Análisis del pipeline

Se incluyen programas de ejemplo en `tools/gui/programs/`, cada uno pensado para
ejercitar un mecanismo distinto:

| Programa | Qué demuestra | Resultado esperado |
|----------|----------------|--------------------|
| `01_branches.s` | Riesgo de control (flush en branch tomado) | `x5=111`, `x6=0` |
| `02_load_use.s` | Stall load-use + forwarding | `x1=10`, `mem[0]=10`, `x4=15` |
| `03_memoria.s` | Accesos byte/half/word, con/sin signo | `x10=-1`, `x11=255`, … |
| `04_loop_jal.s` | Loop con branch hacia atrás + subrutina `jal`/`jalr` | `x5=15`, `x10=30` |
| `demo_add.hex` | Suma simple con forwarding + HALT | `x3=8` |

> **Figura 7.** Avance de las instrucciones de un programa por las 5 etapas (tabla de
> ejecución ciclo a ciclo).
>
> ![Tabla de ejecución del pipeline](../img/PLACEHOLDER-tabla-pipeline.png)

**Ejemplo — `demo_add.hex`** (`addi x1,x0,5`; `addi x2,x0,3`; `add x3,x1,x2`; `halt`):

```
ciclo:        1    2    3    4    5    6    7
addi x1       IF   ID   EX   MEM  WB
addi x2            IF   ID   EX   MEM  WB
add  x3                 IF   ID   EX   MEM  WB     ← x1,x2 por forwarding (EX/MEM, MEM/WB)
halt                         IF   ID   EX   MEM  WB ← o_halt en WB → dump
```

El `add x3,x1,x2` necesita `x1` y `x2` antes de que se escriban en el banco: la
**Forwarding Unit** los adelanta (de EX/MEM y MEM/WB) sin stalls. Al llegar HALT a WB,
la Debug Unit congela el core y vuelca PC + registros + memoria + latches.

---

## 11. Análisis de tiempos

### 11.1 Conceptos

- **WNS (Worst Negative Slack):** slack del peor camino. **WNS ≥ 0 ⇒ cierra timing.**
  Negativo ⇒ el reloj es demasiado rápido para ese camino.
- **Setup / Hold:** el dato debe llegar suficientemente temprano antes del flanco
  (setup) y mantenerse estable después (hold).

### 11.2 Metodología

Flujo batch de Vivado (`synth → opt → place → route → report_timing_summary +
report_utilization`), barriendo la frecuencia del reloj generado por el MMCM y midiendo
el WNS en cada punto. Identificación del **camino crítico** y de los cuellos de
utilización.

### 11.3 El camino crítico

El peor camino **no es la ALU**, sino la **lectura del dump core → Debug Unit**:

```
RegisterFile/DataMemory  →  mux de lectura  →  msb_byte  →  r_tx_data
(posedge, flanco de subida)                                  (negedge, flanco de bajada)
```

Como el core corre en `posedge` y la Debug Unit en `negedge`, este camino tiene **sólo
medio período de presupuesto** (5 ns @ 100 MHz). A 100 MHz **no cierra** (WNS = −1.341 ns,
521/31983 endpoints fallan; ver [`report-20260628.md`](reports/report-20260628.md)). El
72 % del retardo es **ruteo**.

> El `negedge` es **intencional** (evita la carrera de `pipeline_enable`/`imem_wr`), no
> un bug. El efecto colateral es que todos los caminos de lectura del dump pagan medio
> período.

### 11.4 Resultados del barrido y decisión

Se redujo el datapath a **32 bits** (`DATA_WIDTH=32`, correcto para RV32): −32 % de LUTs
y un bug de ancho de JALR corregido. El barrido
([`report-fmax-sweep-dw32-20260629.md`](reports/report-fmax-sweep-dw32-20260629.md)):

| Frecuencia | WNS (setup) | Estado |
|-----------:|:-----------:|:-------|
| 60 MHz | +0.380 ns | ✅ holgado |
| **65 MHz** | **+0.206 ns** (build final: **+0.319 ns**) | ✅ **elegida** |
| 70 MHz | — | ❌ no coloca (cliff de *control sets*) |
| 75 MHz | +0.038 ns | ⚠️ al límite (99.5 % de slices) |
| 78 MHz | −0.211 ns | ❌ no cierra |
| 100 MHz | −1.245 ns | ❌ no cierra |

El **techo de timing real es ~75 MHz** (lo fija el camino de dump posedge→negedge,
dominado por ruteo, independiente del ancho de datos). Por encima de ~70 MHz, la
optimización por timing **replica registros**, explota los **control sets** (~8000) y
satura el device (~99 % de slices), volviendo el placement irreproducible.

**Decisión:** se aplica un **MMCM** en `RiscvTop` que divide los 100 MHz de entrada a
**65 MHz** (`M=6.5 / O=10`), el **máximo confiable**: cierra con WNS **+0.319 ns**, usa
~61 % de slices y 6 % de control sets. El reloj **no se gatea** en ningún punto (la
frecuencia se fija con el MMCM y el procesador se congela con `enable`). Para llegar a
100 MHz haría falta **registrar/re-clockear el camino de dump** o mover la memoria de
datos a BRAM — no angostar el datapath.

> **Figura 8.** Reporte de timing de Vivado (resumen WNS/TNS @ 65 MHz).
>
> ![Reporte de timing](../img/PLACEHOLDER-timing-report.png)

> **Figura 9.** Utilización del device (slices, LUTs, FFs, control sets) @ 65 MHz.
>
> ![Reporte de utilización](../img/PLACEHOLDER-utilization-report.png)

---

## 12. Cumplimiento de la consigna

| Requisito (consigna) | Estado | Dónde |
|----------------------|:------:|-------|
| Pipeline de 5 etapas (IF/ID/EX/MEM/WB) | ✅ | `src/sources_1/`, §3 |
| Subconjunto de instrucciones (R/I/S/B/U/J) | ✅ | §2, `ControlUnit`/`ALU` |
| Mapeo MIPS→RISC-V; `NOR` no aplicable | ✅ | C-003 |
| Detección y manejo de riesgos de datos (forwarding + stall) | ✅ | §4, §5 |
| Riesgos de control (branch/jump, flush) | ✅ | §6 |
| Programar/reprogramar por UART | ✅ | §7, §8 |
| Clock no intervenido (gating por `enable`, no por reloj) | ✅ | §7.3, §11.4 |
| Debug Unit envía **PC** | ✅ | §7.4 (`SEND_PC`) |
| Debug Unit envía **32 registros** | ✅ | §7.4 (`SEND_REG`) |
| Debug Unit envía **latches intermedios** | ✅ | §7.4 (`SEND_LATCH`) |
| Debug Unit envía **memoria de datos** | ✅ | §7.4 (`SEND_MEM`) |
| Instrucción **HALT** / stop | ✅ | §9.1, C-004 |
| Pipeline vacío al terminar | ✅ | §9.1 |
| Modos **continuo** y **paso a paso** | ✅ | §7.2, §9.3 |
| Ensamblador (Assembly → máquina) | ✅ | §8.2 (`assembler.py`) |
| GUI/CLI para interactuar | ✅ | §8.2 |
| Reporte de timing + frecuencia máxima | ✅ | §11 |
| Reloj con IP-core / MMCM | ✅ | §11.4 (MMCM 65 MHz) |
| Validación en placa real | ✅¹ | Basys-3 |

¹ El sistema (UART, carga, ejecución continua + paso a paso, timing) está validado en la
Basys-3 física. **El volcado de latches está verificado en simulación** (132 tests, 0
fallos); su validación end-to-end en placa es el paso de bring-up inmediato siguiente
(regenerar bitstream + correr `riscv_debug.py loadrun`).

> **Nota sobre el formato de carga:** la consigna menciona el formato `.coe`. Aquí el
> programa se carga desde `.s`/`.asm` (ensamblado por `assembler.py`) o `.hex`
> (`$readmemh`); el protocolo de carga por UART envía los words de 32 bits MSB-first.
> Es funcionalmente equivalente (convierte Assembly → máquina y lo transmite por UART).

### Verificación automática

Suite de testbenches (Vivado `xvlog`/`xelab`/`xsim`), corrible con la skill `run-tests`:

```
RESULTS: 132 passed, 0 failed — ALL TESTS PASSED
```

Cubre: `RegisterFile`, `ImmediateExtend`, `ControlUnit`, `ALU`, `ExecuteStage`,
`DataMemory`, buffers, forwarding + load-use, integración IF→WB, branches/jumps, el bug
de `LUI`, la FSM de la `DebugUnit` y la integración `DebugUnit + core` (carga → run →
HALT → dump, **incluyendo la sección de latches intermedios**).

---

## 13. Conclusión

Se implementó un procesador **RISC-V segmentado de cinco etapas** en SystemVerilog,
funcional sobre la **Basys-3**. El pipeline ejecuta el subconjunto RV32I pedido y maneja
correctamente los tres tipos de riesgos: **datos** (forwarding + stall load-use),
**control** (flush en branch/jump) y la coherencia lectura/escritura del banco
(write-through). La interfaz por **UART + Debug Unit** permite cargar y reprogramar el
procesador, ejecutarlo en modo **continuo** o **paso a paso**, y volcar el estado
completo —**PC, los 32 registros, la memoria de datos y los latches intermedios**— a una
**GUI/CLI** en Python, cumpliendo la totalidad de la consigna.

El análisis de tiempos reveló que el camino crítico **no es el datapath** sino la lectura
del dump que cruza `posedge→negedge`: con sólo medio período de presupuesto, fija el
techo en ~75 MHz. Reducir el datapath a 32 bits descongestionó el device y permitió
subir el operativo confiable a **65 MHz** (WNS +0.319 ns), aplicado con un **MMCM** sin
gatear el reloj funcional. Para superar ese techo habría que registrar el camino de dump
o llevar la memoria de datos a BRAM, no angostar más los datos.

El diseño completó las once etapas planificadas (correcciones → control → EX/ALU →
buffers → MEM → WB → forwarding/stall → branch/jump → UART/Debug → modos de operación →
timing), con verificación por **132 testbenches** y documentación de las decisiones de
diseño no obvias.

---

## 14. Bibliografía

- D. Patterson, J. Hennessy. *Computer Organization and Design: The Hardware/Software
  Interface — RISC-V Edition*. Cap. 4 (pipeline, §4.5–4.8) y Apéndice A.
- *The RISC-V Instruction Set Manual, Volume I: Unprivileged ISA*.
- Digilent. *Basys-3 Reference Manual* y *Basys-3 Master XDC*.
- Xilinx/AMD. *Vivado Design Suite — 7 Series MMCM/PLL (UG472, UG949 Timing Closure)*.

### Documentación interna del proyecto

- Decisiones de diseño: [`CONSIDERACIONES.md`](utils/CONSIDERACIONES.md) (C-001…C-006).
- Debug Unit: [`DEBUG_UNIT.md`](utils/DEBUG_UNIT.md) · UART: [`UART.md`](utils/UART.md).
- Riesgos: [`forwarding-unit.md`](utils/forwarding-unit.md) ·
  [`hazard-detection-unit.md`](utils/hazard-detection-unit.md).
- Instrucciones: [`instrucciones.md`](utils/instrucciones.md).
- Timing: [`report-20260628.md`](reports/report-20260628.md) ·
  [`report-fmax-sweep-dw32-20260629.md`](reports/report-fmax-sweep-dw32-20260629.md).
