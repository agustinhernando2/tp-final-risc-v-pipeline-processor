# Consideraciones de diseño

Registro breve de decisiones de arquitectura no obvias.

---

## C-001 — PC byte-addressed (`PC + 4`) en lugar de word-addressed (`PC + 1`)

**Fecha:** 2026-06-13
**Estado:** resuelto / implementado
**Etapas afectadas:** IF (`InstructionFetch`, `InstructionMemory`), EX (`ExecuteStage`)

### Discusión

El diseño original usaba un **PC word-addressed**: incrementaba de a 1, la
`InstructionMemory` indexaba el array de palabras directo con el PC, y el branch
target convertía el offset de bytes a palabras con `>>> 2`:

```systemverilog
// IF: PC + 1
// branch_target = PC + (sign_ext(imm) >>> 2)
```

El libro de referencia (Patterson & Hennessy, *RISC-V edition*, §4.3, Fig. 4.9)
usa un **PC byte-addressed**: el PC cuenta bytes (`PC + 4`) y el branch target se
calcula como `PC + (imm << 1)`. El `<< 1` ("Shift left 1") **no es hardware**: es
puro cableado que apenda un `0` al bit menos significativo del offset, porque el
inmediato B-type guarda solo `imm[12:1]` (offset en half-words).

La pregunta fue: ¿por qué el libro hace `<< 1` y el desarrollo hacía `>>> 2`?

- **`<< 1` (libro):** convierte el inmediato de *half-words → bytes*, porque su PC
  cuenta bytes.
- **`>>> 2` (diseño original):** convertía el byte offset (que `ImmediateExtend`
  ya produce, gracias al `1'b0` que apenda en el LSB del B/J-type) de
  *bytes → palabras*, porque el PC contaba palabras.

Es decir, el `ImmediateExtend` ya hacía el `<< 1` del libro internamente, y luego
el `>>> 2` lo dividía de nuevo: una doble conversión redundante, y una convención
distinta a la del libro.

### Decisión

Alinear con el libro: **PC byte-addressed, incremento de a 4**. Cambios:

1. `InstructionFetch.sv` — el sumador del PC suma `4` (antes `1`).
2. `InstructionMemory.sv` — el fetch indexa con `PC >> 2`
   (`i_PC[NB_ADDR+1:2]`); el puerto de carga por debug sigue usando índice de
   palabra.
3. `ExecuteStage.sv` — se **elimina** el `>>> 2`: el inmediato ya es un byte
   offset y el PC está en bytes, así que `branch_target = PC + imm` directo.
   (Reemplazar por `<< 1` habría sido **incorrecto**: duplicaría el offset, porque
   el `ImmediateExtend` ya incluye el `<< 1` del libro.)
4. La señal `pc_plus_1` se renombró a `pc_plus_4` en todo el pipeline (la
   dirección de retorno de JAL/JALR pasa a ser `PC + 4`, generada por el sumador
   de IF; no hace falta un sumador aparte).

### Resultado

- Suite de tests: **117 passed, 10 failed**. Los 10 fallos son el bug conocido
  preexistente [BUG-001 (LUI)](known-bugs.md), no relacionado con este cambio.
- `tb_branch` (BNE loop + JAL): 6/6 ✓ — la dirección de retorno de JAL pasó de
  `x1 == 1` a `x1 == 4`, como corresponde al modelo byte-addressed.
- `tb_IF_to_WB`: 6/6 ✓.
- Beneficio adicional: JALR con offset no nulo ahora funciona (antes era una
  limitación del diseño word-addressed; ver [`plans/stage8.md`](../plans/stage8.md)).

### Fuera de alcance

- **`DataMemory`** (LW/SW/LH/SH) sigue siendo **word-addressed**. Es un eje de
  direccionamiento independiente del PC y no se modificó en este cambio. Queda
  como deuda conocida si se busca consistencia byte-addressed end-to-end.

---

## C-002 — Cómo leer la notación de inmediatos B-type y J-type

**Fecha:** 2026-06-21
**Estado:** nota de referencia
**Etapas afectadas:** ID (`ImmediateExtend`)

### Discusión

La notación `imm[20|10:1|11|19:12]` (J-type) o `imm[12|10:5] ... imm[4:1|11]`
(B-type) **no** lista los bits del inmediato en orden. Describe **en qué orden
físico aparecen los trozos del inmediato dentro de la instrucción**, leyendo de
izquierda (MSB de la instrucción, `inst[31]`) a derecha. Cada número o rango
indica **a qué posición del inmediato** va ese trozo. El hardware lee esos
pedazos y los rearma en su lugar correcto.

Este "desorden" es deliberado: el bit de signo es siempre `inst[31]` en todos los
formatos (arranca el sign-extend sin esperar el opcode), y los bits comunes entre
formatos parecidos (S↔B, U↔J) se mantienen en la misma posición física para
reutilizar cableado y reducir muxes.

El formato es así por **hardware más barato**: el ISA acepta complicar al
ensamblador/decoder (que rebaraja bits una sola vez en software) a cambio de
simplificar el ruteo de inmediatos, que está en el camino crítico de cada
instrucción y se paga en silicio en cada chip.

El `imm[0]` implícito siempre es `0` (saltos alineados a 2 bytes): es el `1'b0`
que `ImmediateExtend` apenda en el LSB, y que cumple el rol del `<< 1` del libro
(ver [C-001](#c-001--pc-byte-addressed-pc--4-en-lugar-de-word-addressed-pc--1)).

### Formato UJ / J-type — `imm[20|10:1|11|19:12]`

![Formato UJ / J-type](../img/formato-uj-jtype.png)

| bits de la instrucción | bit del inmediato |
|---|---|
| `inst[31]`    | `imm[20]`    |
| `inst[30:21]` | `imm[10:1]`  |
| `inst[20]`    | `imm[11]`    |
| `inst[19:12]` | `imm[19:12]` |

```systemverilog
wire [20:0] imm_j = { inst[31], inst[19:12], inst[20], inst[30:21], 1'b0 };
// luego sign-extend con inst[31]
```

### Formato SB / B-type — `imm[12|10:5] ... imm[4:1|11]`

![Formato SB / B-type](../img/formato-sb-btype.png)

| bits de la instrucción | bit del inmediato |
|---|---|
| `inst[31]`    | `imm[12]`   |
| `inst[30:25]` | `imm[10:5]` |
| `inst[11:8]`  | `imm[4:1]`  |
| `inst[7]`     | `imm[11]`   |

```systemverilog
wire [12:0] imm_b = { inst[31], inst[7], inst[30:25], inst[11:8], 1'b0 };
// luego sign-extend con inst[31]
```

### Nota de nomenclatura

"SB-type" y "UJ-type" son los nombres antiguos (spec ≤ 2.0). En el manual actual
de RISC-V y en Patterson & Hennessy se llaman **B-type** y **J-type**
respectivamente. Son el mismo formato; solo cambió la denominación.

---

## C-003 — La lista de instrucciones del TP está en mnemónicos MIPS

**Fecha:** 2026-06-22
**Estado:** nota de referencia
**Etapas afectadas:** ID (`ControlUnit`, `ALUControl`), MEM (`DataMemory`)

### Discusión

La lista de instrucciones del enunciado (`plans/TRABAJO_FINAL_2025.md`) usa
mnemónicos de **MIPS**, no de RISC-V (el template fue adaptado de un curso de
MIPS). El set RISC-V implementado cubre todos sus equivalentes:

| TP (MIPS) | RISC-V implementado |
|---|---|
| SLLV, SRLV, SRAV (shift por registro) | SLL, SRL, SRA |
| SLL, SRL, SRA (shift por inmediato)   | SLLI, SRLI, SRAI |
| ADDU, SUBU | ADD, SUB |
| ADDIU | ADDI |
| J  | `JAL x0` (pseudo) |
| JR | `JALR x0` (pseudo) |

`J` y `JR` no necesitan hardware propio: el ensamblador los emite como `JAL`/`JALR`
con `rd = x0`, ya soportados.

### Decisión sobre `NOR`

`NOR` figura en la lista del TP pero **no existe en RISC-V** (no tiene opcode/funct
asignado). Se considera **no aplicable** y no se implementa; sería una extensión
custom fuera del ISA. Todo el resto de la lista está implementado, sin
instrucciones de más (AUIPC se removió por no estar pedida).

---

## C-004 — Instrucción HALT: opcode dedicado vs. self-loop

**Fecha:** 2026-06-22 (resuelto 2026-06-23, Stage 9b)
**Estado:** resuelto / implementado
**Etapas afectadas:** ID (`ControlUnit`), Buffers, Debug Unit

### Discusión

El TP exige *"una instrucción HALT o instrucción de stop"*
(`docs/TRABAJO_FINAL_2025.md:141`) y que **el pipeline quede vacío al terminar la
ejecución** (`:171`). El libro de Patterson & Hennessy **no define HALT**: el
subset RISC-V del cap. 4 asume ejecución continua y lo más cercano es el manejo de
excepciones (§4.9). En el RISC-V real tampoco hay HALT en RV32I (lo análogo sería
`EBREAK`/`ECALL`, o `WFI` en la spec privilegiada). Es decir: HALT es **custom**,
lo definimos nosotros.

Hay dos enfoques sobre la mesa:

1. **Self-loop `jal x0, 0`** (lo que hoy propone `plans/plan.md:228`): no es una
   instrucción nueva, se reutiliza JAL. La Debug Unit detecta el self-loop por
   fuera y dispara el dump. Simple, pero **no detiene el procesador ni vacía el
   pipeline**: el PC sigue refetcheando la misma instrucción para siempre. No
   cumple bien el requisito `:171`.

2. **Opcode HALT dedicado** (MIPS de referencia): es una instrucción real con opcode propio
   (allí `HALT_OPCODE = 6'h3f`). La `ControlUnit` la decodifica y levanta una
   señal `halt` que **viaja por los buffers de pipeline** como un bit de control
   más. Cuando llega a MEM/WB, la unidad de hazard/stall hace **flush de IF, ID y
   EX** (drena las instrucciones posteriores para que no escriban en memoria ni en
   registros) y se expone un `o_halt` al top/Debug Unit para señalar fin de
   programa. Este enfoque **sí vacía el pipeline** y es más fiel al enunciado.

### Decisión (implementada en Stage 9b)

Se adoptó el **opcode HALT dedicado** (enfoque 2): cumple el requisito de pipeline
vacío y responde la pregunta del TP *"¿qué pasa si en memoria no hay una instrucción
de parada?"* (`:174`) — sin HALT, el procesador sigue ejecutando lo que haya después.

Detalles concretos del encoding y la implementación:

- **Encoding:** opcode **custom-0 de RISC-V = `7'b0001011`**, instrucción
  `0x0000000B` (resto del encoding en cero). Es espacio reservado por el ISA para
  extensiones, así que no colisiona con ninguna instrucción base.
- La `ControlUnit` lo decodifica a `o_Halt` con **todas las demás señales en 0** (no
  escribe registros ni memoria). El bit `Halt` viaja por los buffers ID/EX → EX/MEM →
  MEM/WB como un control más.
- **`o_halt` se asierta cuando HALT llega a WB** (no a MEM): así la última instrucción
  real anterior a HALT completa su write-back antes de que la `DebugUnit` congele el
  pipeline (bajando el enable global `i_if_enable`). Las instrucciones posteriores a
  HALT son NOPs (la GUI rellena el programa con `0x00000000` y la IM arranca en cero),
  por lo que el pipeline queda efectivamente vacío al detenerse.
- No se usó una unidad de flush dedicada para el HALT: alcanza con el padding de NOPs
  y el corte del enable global. Ver `plans/stage9b.md`.

---

## C-005 — Asignación bloqueante (`=`) vs. no bloqueante (`<=`): cuándo usar cada una

**Fecha:** 2026-06-23
**Estado:** nota de referencia
**Etapas afectadas:** todas las que usan FSMs de dos bloques (UART, DebugUnit, buffers, etc.)

### Regla de oro

| Bloque | Asignación | Modela |
|--------|-----------|--------|
| `always_ff` (secuencial, `@(posedge i_clk)`) | **no bloqueante `<=`** | flip-flops (memoria de estado) |
| `always_comb` (combinacional) | **bloqueante `=`** | compuertas (cálculo del próximo estado) |

Esto aplica al patrón de **FSM de dos bloques** que usamos en toda la UART y la
DebugUnit: un `always_ff` que **guarda** el estado (`r_*`) y un `always_comb` que
**calcula** el próximo estado (`w_next_*`) a partir del estado actual y las entradas.

### Por qué

Son **dos garantías independientes** que trabajan juntas:

1. **No bloqueante en el `always_ff`** → todos los lados derechos se evalúan con los
   valores *viejos* y todos los registros se actualizan **a la vez** en el flanco.
   Así el `always_comb` siempre lee una **foto coherente** del estado: ningún
   registro ve el valor "ya nuevo" de otro a mitad de flanco.

2. **Bloqueante en el `always_comb`** → las asignaciones se ejecutan **en orden, de
   arriba hacia abajo, y toman efecto al instante** (como software). Eso es lo que
   hace funcionar el patrón *default y después sobrescribo*:

   ```systemverilog
   w_next_state = r_state;   // 1) default: quedarse igual
   ...
   w_next_state = START;     // 2) lo piso si corresponde (dentro del case)
   ```

   y modela cómo una red de compuertas se asienta en su valor final en un solo paso.

### Qué pasa si se invierten

- **`always_ff` con bloqueante:** los registros se actualizan **en orden** y uno puede
  usar el valor *ya nuevo* de otro en el mismo flanco → carrera, comportamiento
  dependiente del orden de las líneas. Ejemplo de shift register: `b<=a; c<=b;`
  desplaza bien; `b=a; c=b;` colapsa (`c` toma el `a` nuevo, se "come" una etapa).

- **`always_comb` con no bloqueante:** los updates se difieren al final del paso de
  tiempo (región NBA). Una línea que lea una señal asignada más arriba en el mismo
  bloque leería el valor **viejo** → dataflow roto y, sobre todo, **mismatch entre
  simulación y síntesis** (el sintetizador infiere las mismas compuertas, pero la
  simulación RTL se comporta distinto). Bug carísimo de encontrar.

### El "baile" de un ciclo (modelo mental)

1. **Flanco de subida:** el `always_ff` latchea `w_next_* → r_*` (todos a la vez).
2. Cambian los `r_*` → el `always_comb` se dispara y recalcula `w_next_*`
   (bloqueante) a partir de los `r_*` nuevos + las entradas actuales.
3. Entre flancos, si cambia una entrada, el `always_comb` recalcula de nuevo.
4. Próximo flanco: el `always_ff` vuelve a latchear. Y se repite.

El `always_ff` es la **memoria** (avanza una "generación" por flanco); el
`always_comb` es el **cálculo** (puede recalcular muchas veces entre flancos, pero
recién se consolida en estado en el próximo flanco).

> Convención estándar (regla de Cummings, *"Nonblocking Assignments in Verilog
> Synthesis"*): secuencial → `<=`, combinacional → `=`. Mezclarlas es una *red flag*
> en cualquier review y la causa más común de mismatch simulación–síntesis.

---

## C-006 — Volcado de los *latches intermedios* por UART

**Fecha:** 2026-06-29
**Estado:** resuelto / implementado
**Etapas afectadas:** Debug (`DebugUnit`), Top (`riscv.sv`, `RiscvTop`), GUI

### Discusión

El TP exige que la Debug Unit envíe por UART, además de los 32 registros y la memoria
de datos, **el contenido de los latches intermedios** (`docs/TRABAJO_FINAL_2025.md:132`).
La implementación inicial (Stage 9b) sólo volcaba **PC + registros + memoria** — la
misma sección que el MIPS de base —, dejando ese requisito sin cubrir.

Los "latches intermedios" son los cuatro **buffers de pipeline** (`IF/ID`, `ID/EX`,
`EX/MEM`, `MEM/WB`). Había que decidir **cómo** exponerlos y serializarlos.

### Decisión

Reutilizar el patrón ya existente de `SEND_REG` / `SEND_MEM` (índice + `msb_byte` +
handshake `i_tx_done`) en vez de inventar un protocolo nuevo:

1. **Enumeración plana indexada.** Cada campo de cada buffer es un índice (0..24,
   `LATCH_COUNT = 25`). El core (`riscv.sv`) mapea el índice a la salida del buffer
   correspondiente con un `always_comb` + `case`, zero-extendiendo a `DATA_WIDTH`.
   **No se tocan los módulos de buffer** — sus salidas ya son wires en `riscv.sv`.
2. **Control empaquetado.** Los bits de control de cada buffer se agrupan en un único
   word `ctrl` por buffer (layout documentado en [`DEBUG_UNIT.md`](DEBUG_UNIT.md) §2),
   en vez de un valor por bit. Mantiene el conteo y el tiempo de transferencia chicos
   (25 × 4 = 100 bytes extra).
3. **Cuarta sección del dump.** Se agrega el estado `SEND_LATCH` *después* de
   `SEND_MEM` (`…→SEND_MEM→SEND_LATCH→r_prev`), para no alterar el prefijo
   PC/registros/memoria que ya parseaban las herramientas. La GUI (`uart.py`,
   `riscv_debug.py`, `gui.py`) se actualizó en lockstep (`LATCH_FIELDS`, `N_LATCH=25`).

### Resultado

- Suite completa: **132 passed, 0 failed**. `tb_DebugUnit` verifica byte a byte la
  sección de latches con stubs; `tb_RiscvDebug` reconstruye latches reales tras HALT
  (el buffer `MEM/WB` retiene `Halt=1`, las etapas previas quedan en NOP/0).
- El one-hot de estados pasó de 8 a **9 bits**; como `o_state` son 8 LEDs,
  `SEND_LATCH` comparte indicador con `SEND_MEM` (cosmético).

### Nota de temporización

El mux de latches es **otro camino de dump core→DebugUnit que cruza posedge→negedge**
(como registros/memoria, ver [`reports/report-20260628.md`](../reports/report-20260628.md)).
A 65 MHz hay margen y los buffers ya son salidas registradas, así que se espera que
cierre. Si regresara el timing, registrar `i_latch_data` (Opción A del reporte: 1
ciclo extra, irrelevante en un dump serie a 19200 baud).
