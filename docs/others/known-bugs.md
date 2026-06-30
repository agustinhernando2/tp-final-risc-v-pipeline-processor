# Bugs conocidos

## BUG-001 — LUI produce resultado incorrecto cuando `imm[14:12] != 000`

**Estado:** ✅ resuelto  
**Etapa afectada:** EX (`ALUControl` + `ALU`)  
**Archivos involucrados:**
- [`src/sources_1/ID/ControlUnit.sv`](../src/sources_1/ID/ControlUnit.sv) — origen del problema
- [`src/sources_1/EX/ALUControl.sv`](../src/sources_1/EX/ALUControl.sv) — donde se manifestaba
- [`src/sources_1/EX/ALU.sv`](../src/sources_1/EX/ALU.sv) — ejecutaba la operación incorrecta

> **Resumen de la corrección:** `ControlUnit` asigna a LUI `ALUOp=00` (ADD
> forzado) y emite una señal `LUI=1` que se propaga por `ID_EX_Buffer` hasta
> `ExecuteStage`, donde un mux fuerza el operando A a `0`. La ALU calcula
> `0 + imm = imm` para cualquier inmediato. Detalle abajo en "Solución".

---

### Flujo correcto esperado de LUI

```
lui rd, imm
```

| Etapa | Qué debería pasar |
|-------|-------------------|
| IF    | Se trae la instrucción de 32 bits (U-type). |
| ID    | `ImmediateExtend` genera `{inst[31:12], 12'b0}` — el inmediato ya está en posición. La `ControlUnit` activa `RegWrite=1`, `ALUSrc=1`, `MemToReg=0`, `Jump=0`. No hay `rs1`/`rs2` reales: `inst[19:15]` e `inst[24:20]` son partes del inmediato. |
| EX    | La ALU debería hacer `0 + imm = imm` (pasar el inmediato). Con `ALUSrc=1` el operando B es el inmediato correcto. El operando A es irrelevante — debería ser ignorado. |
| MEM   | `MemRead=0`, `MemWrite=0` — no toca memoria. |
| WB    | `MemToReg=0`, `Jump=0` → escribe `alu_result` en `rd`. |

El resultado esperado en `rd` es siempre `{imm[31:12], 12'b0}`.

---

### Encoding U-type y raíz del bug

La instrucción U-type no tiene campo `funct3`. Los bits `[14:12]`, que en otras
instrucciones codifican `funct3`, en U-type son parte del **inmediato** (`imm[14:12]`):

```
inst[31:12]   inst[11:7]   inst[6:0]
 imm[31:12]      rd        0110111
    ↑
inst[14:12] = imm[14:12]  ← lo que InstructionDecode pasa como "funct3"
inst[30]    = imm[30]     ← lo que InstructionDecode pasa como "funct7_5"
```

`ControlUnit` asigna `ALUOp = 2'b11` para LUI, **igual que para instrucciones
I-type aritméticas**. `ALUControl` con `ALUOp=11` decodifica `funct3` para
elegir la operación ALU:

```
6'b11_000_?: ADDI  (ADD)   ← correcto solo si imm[14:12] = 000
6'b11_001_?: SLLI           ← imm[14:12] = 001 → incorrecto
6'b11_101_0: SRLI           ← imm[14:12] = 101 → incorrecto
...
```

### Condición de fallo

LUI falla cuando `imm[14:12] != 3'b000`. Como `imm[14:12]` son los bits 2:0 del
valor de 20 bits que el programador escribe, esto afecta a la gran mayoría de los
inmediatos útiles.

Ejemplo concreto — `lui x5, 0x12345`:

```
imm = 0x12345 → imm[14:12] = 3'b101 (bits 2:0 de 0x12345)
funct7_5 = imm[30] = 0
ALUOp=11, funct3=101, funct7_5=0  →  ALUCtrl = SRLI
ALU hace: operand_a >> operand_b[4:0]
        = rs1_garbage >> 0          (0x12345000[4:0] = 0)
        = rs1_garbage
Resultado: rs1_garbage ≠ 0x12345000  ✗
```

Incluso en el caso "afortunado" donde `imm[14:12]=000` (→ ADD), el operando A es
`RegisterFile[inst[19:15]]` = `RegisterFile[imm[19:15]]` — un registro indexado
por bits del inmediato, no necesariamente cero. El resultado sería correcto solo
si ese registro vale `0`.

| imm[14:12] | Operación real de la ALU | Correcto para LUI |
|------------|--------------------------|:-----------------:|
| 000 | ADD (`rs1_garbage + imm`) | solo si `rs1_garbage = 0` |
| 001 | SLLI | no |
| 010 | SLTI | no |
| 011 | SLTIU | no |
| 100 | XORI | no |
| 101 | SRLI/SRAI | no |
| 110 | ORI | no |
| 111 | ANDI | no |

### Solución (aplicada)

Se implementó la opción 1: señal de control dedicada `LUI`.

1. `ControlUnit` (`src/sources_1/ID/ControlUnit.sv`): LUI usa `ALUOp = 2'b00`
   (ADD forzado, igual que `lw`/`sw`) y activa la nueva salida `o_LUI = 1'b1`.
   Con `ALUOp=00` el `ALUControl` selecciona ADD sin mirar `funct3`, eliminando
   la dependencia de `imm[14:12]`.
2. La señal `LUI` se propaga `InstructionDecode → ID_EX_Buffer → ExecuteStage`.
3. `ExecuteStage` (`src/sources_1/EX/ExecuteStage.sv`): un `mux1_2` (`u_mux_alu_a`)
   fuerza el operando A de la ALU a `0` cuando `i_LUI=1`. Así
   `result = 0 + imm = imm` para cualquier inmediato.

Resultado: `rd = {imm[31:12], 12'b0}` siempre, sin importar `imm[14:12]` ni el
contenido del register file.

**Testbench (regresión):** [`src/sim_1/EX/tb_lui_bug.sv`](../src/sim_1/EX/tb_lui_bug.sv)
ejercita `ExecuteStage` con `i_LUI=1` para los 8 valores de `imm[14:12]` y un
operando A basura; verifica `alu_result == imm` en todos los casos.

---

### Cómo ejecutar el testbench

Desde la raíz del repositorio:

```bash
mkdir -p sim_out
cd sim_out
xvlog --sv $(find ../src/sources_1 -name '*.sv' | grep -v Top) ../src/sim_1/EX/tb_lui_bug.sv
xelab -debug typical tb_lui_bug -s sim_lui_bug
xsim sim_lui_bug --runall
```

O con el script del proyecto (si ya existe `sim_out/`):

```bash
bash .claude/skills/run-tests/scripts/run_one.sh tb_lui_bug
```

### Salida esperada (tras la corrección)

```
--- BUG-001 regresion: LUI produce {imm[31:12], 12'b0} para cualquier imm ---
  PASS  lui x5,0x12345: 0x12345000
  PASS  lui x1,0x00001: 0x00001000
  PASS  lui x5,0x00100: 0x00100000
  PASS  lui imm[14:12]=010: 0xabcd2000
  PASS  lui imm[14:12]=011: 0x55553000
  PASS  lui imm[14:12]=100: 0x0f0f4000
  PASS  lui imm[14:12]=110: 0x80006000
  PASS  lui imm[14:12]=111: 0xfffff000

--- Results: 8 passed, 0 failed ---
ALL TESTS PASSED
```

Cada caso ejecuta `ExecuteStage` con `i_LUI=1`, un operando A basura (para
confirmar que se ignora) y el inmediato U-type ya formado (`{imm[31:12], 12'b0}`).
Se verifica que `alu_result == inmediato` en los 8 valores posibles de
`imm[14:12]`, incluyendo los 7 que antes seleccionaban una operación ALU
incorrecta (SLLI, SLTI, …) y el caso `000` donde el operando A no nulo antes
contaminaba la suma.

---

## BUG-002 — Branch tomado no flushea la instrucción inmediatamente posterior (B+4)

**Estado:** ✅ resuelto  
**Etapa afectada:** MEM (resolución del branch) + buffer EX/MEM  
**Archivos involucrados:**
- [`src/sources_1/Top/riscv.sv`](../../src/sources_1/Top/riscv.sv) — origen: `EX_MEM_Buffer.i_flush` estaba cableado a `1'b0`
- [`src/sources_1/MEM/MemoryAccessStage.sv`](../../src/sources_1/MEM/MemoryAccessStage.sv) — genera `o_PCSrc` en la etapa MEM
- [`src/sim_1/Integrador/tb_branch.sv`](../../src/sim_1/Integrador/tb_branch.sv) — testbench de regresión

> **Resumen de la corrección:** el branch se resuelve en **MEM** (`o_PCSrc`), así
> que cuando se toma hay **tres** instrucciones jóvenes en vuelo (etapas IF, ID y
> EX). El RTL flusheaba solo IF/ID e ID/EX y dejaba viva la de EX (B+4), que pasaba
> a MEM/WB y commiteaba su write-back. La corrección cablea `EX_MEM_Buffer.i_flush
> = w_PCSrc`, flusheando las tres (penalidad de 3 ciclos). Detalle abajo en "Solución".

---

### Flujo correcto esperado de un branch tomado

Con `assume-not-taken`, el IF sigue trayendo instrucciones secuenciales mientras el
branch baja por el pipeline. La decisión no ocurre hasta **MEM**, así que cuando el
branch llega a MEM ya entraron por detrás tres instrucciones:

| Etapa en el ciclo en que el branch está en MEM | Instrucción | Acción correcta si el branch se toma |
|---|---|---|
| EX | B+4 | **flush** (la salta el branch) |
| ID | B+8 | flush |
| IF | B+12 | flush + redirigir PC al target |

Esto coincide con Patterson & Hennessy, cap. 4.8, Fig. 4.59:

> "Since the branch instruction decides whether to branch in the MEM stage […] the
> three sequential instructions that follow the branch will be fetched and begin
> execution. […] we must be able to **flush instructions in the IF, ID, and EX
> stages** of the pipeline."

### Raíz del bug y condición de fallo

`riscv.sv` flusheaba solo dos de los tres buffers en un salto tomado:

```
IF_ID_Buffer.i_flush  = w_PCSrc                 // mata B+12 (IF)   ✓
ID_EX_Buffer.i_flush  = w_ID_EX_flush | w_PCSrc // mata B+8  (ID)   ✓
EX_MEM_Buffer.i_flush = 1'b0                     // B+4 (EX) NO se mata ✗
```

La instrucción en EX (B+4) se latcheaba normalmente en EX/MEM, llegaba a MEM y WB, y
escribía su resultado en el register file aunque el salto la hubiera salteado.

**Condición de fallo:** cualquier `beq`/`bne`/`jal`/`jalr` **tomado** cuya instrucción
inmediatamente posterior tenga un efecto observable que el destino no sobrescriba.

Ejemplo concreto — `tools/gui/programs/01_branches.s`:

```asm
        bne  x1, x3, fin   # 7 != 9 -> TOMADO, salta a 'fin'
        addi x6, x6, 222   # B+4: la cabecera dice "x6 = 0 (se saltea / flush)"
fin:    halt
```

- **Antes del fix:** `x6 = 222` (B+4 se filtró y ejecutó).
- **Después del fix:** `x6 = 0` (B+4 flusheada), como documenta la cabecera del programa.

Los 129 tests previos no lo detectaban porque en `tb_branch.sv` el efecto de la
instrucción filtrada quedaba sobrescrito (JAL: `x5` se pisa a 2) o era inocuo
(BNE loop: `x3=99` igual quedaba 99).

### Solución (aplicada)

`src/sources_1/Top/riscv.sv`, instancia `EX_MEM`:

```diff
-        .i_flush        (1'b0),
+        .i_flush        (w_PCSrc & i_if_enable),
```

> **Nota:** la primera versión de este fix usó `.i_flush (w_PCSrc)` (sin gatear).
> Eso corrige el leak en ejecución continua pero **rompe el modo paso a paso**
> (ver **BUG-003**): el flush sin gatear expulsa el branch del EX/MEM durante el
> freeze del dump y se pierde la redirección del PC. La forma correcta gatea el
> flush con `i_if_enable`, igual que el update del PC.

`EX_MEM_Buffer.sv` ya daba prioridad a `i_flush` sobre `i_enable`. El propio
branch/JAL no se ve afectado: está en MEM y pasa a MEM/WB (otro buffer, no flusheado),
por lo que JAL conserva su write-back del return address.

Resultado: en un salto tomado se flushean las tres instrucciones jóvenes (IF, ID, EX);
penalidad de **3 ciclos** cuando el branch se toma, 0 cuando no.

**Testbench (regresión):** [`src/sim_1/Integrador/tb_branch.sv`](../../src/sim_1/Integrador/tb_branch.sv),
Test 3 ("Taken-branch flush (B+4)"): un `beq` tomado saltea `addi x10,x0,123`; verifica
`x10 == 0` (B+4 flusheada), `x11 == 0` (B+8) y `x12 == 77` (target ejecutado). Antes del
fix, `x10` daba 123 y el test fallaba.

### Cómo ejecutar el testbench

```bash
bash .claude/skills/run-tests/scripts/run_tests.sh
```

o solo el de branches:

```bash
mkdir -p sim_out && cd sim_out
xvlog --sv $(find ../src/sources_1 -name '*.sv') ../src/sim_1/Integrador/tb_branch.sv
xelab -debug typical tb_branch -s sim_branch
xsim sim_branch --runall
```

### Salida esperada (tras la corrección)

```
--- Taken-branch flush (B+4) Test ---
  PASS  FLUSH: x10 == 0 (B+4 flushed)
  PASS  FLUSH: x11 == 0 (B+8 flushed)
  PASS  FLUSH: x12 == 77 (target ran)
```

### Validación en hardware

El bug también se reproduce y se corrige de punta a punta en la Basys-3 corriendo
`tools/gui/programs/01_branches.s` (assembler → `loadrun` por UART): el dump debe
mostrar `x5 == 111` y `x6 == 0` con el bitstream corregido (pre-fix daba `x6 == 222`).

---

## BUG-003 — Branch tomado pierde la redirección del PC en modo paso a paso

**Estado:** ✅ resuelto  
**Etapa afectada:** MEM (resolución del branch) + buffer EX/MEM + DebugUnit (step)  
**Relación:** regresión introducida por la **primera** versión del fix de [BUG-002](#bug-002--branch-tomado-no-flushea-la-instrucción-inmediatamente-posterior-b4).  
**Archivos involucrados:**
- [`src/sources_1/Top/riscv.sv`](../../src/sources_1/Top/riscv.sv) — `EX_MEM_Buffer.i_flush`
- [`src/sources_1/Debug/DebugUnit.sv`](../../src/sources_1/Debug/DebugUnit.sv) — congela el pipeline (`o_pipeline_enable=0`) durante el dump
- [`src/sources_1/Buffers/EX_MEM_Buffer.sv`](../../src/sources_1/Buffers/EX_MEM_Buffer.sv) — `i_flush` tiene prioridad sobre `i_enable`
- [`src/sim_1/Integrador/tb_step_branch.sv`](../../src/sim_1/Integrador/tb_step_branch.sv) — testbench de regresión

> **Resumen de la corrección:** el flush de EX/MEM en un branch tomado debe gatearse
> con `i_if_enable` (`w_PCSrc & i_if_enable`), igual que el update del PC. Sin gatear,
> en paso a paso el branch se expulsa del EX/MEM durante el freeze del dump y la
> redirección del PC se pierde, dejando el target flusheado pero nunca re-fetcheado.

### Síntoma

Mismo `01_branches.s` con un cuerpo en el destino del salto, p. ej.:

```asm
        bne  x1, x3, fin   # tomado
        addi x6, x6, 222   # B+4
fin:    addi x8, x0, 3     # destino: debería ejecutarse -> x8 = 3
        halt
```

- **Ejecución continua** (`run`/`loadrun`): `x8 == 3` ✓
- **Paso a paso** (`step`): `x8 == 0` ✗ — el destino se flushea y nunca se re-ejecuta.

Misma arquitectura, resultado distinto según el modo.

### Causa raíz

El branch se resuelve en MEM, así que un branch tomado queda en el buffer EX/MEM
manteniendo `PCSrc=1` hasta que el siguiente ciclo redirige el PC. Dos señales tienen
gating distinto:

| Señal | Gating | Efecto |
|---|---|---|
| Update del PC (`PC ← target`) | `i_if_enable & w_PCWrite` | **gated** por enable |
| Flush de IF/ID, ID/EX, EX/MEM | `w_PCSrc` (sin gatear) | dispara aunque enable=0 |

En **continuo** el ciclo siguiente a la resolución está habilitado: flush y redirect
ocurren en el mismo flanco. En **paso a paso**, la DebugUnit congela el pipeline
(`pipeline_enable=0`) muchos ciclos para hacer el dump. Como el flush de EX/MEM no
estaba gateado (y tiene prioridad sobre `i_enable` en el buffer), **expulsa el branch
del EX/MEM durante el freeze**, bajando `PCSrc` a 0 antes de que el redirect (gated por
enable) pueda ejecutarse. El destino se flushea como instrucción joven pero el PC nunca
salta a él → nunca se re-fetchea.

> Las flushes de IF/ID e ID/EX también son ungated, pero ahí es inocuo: solo contienen
> instrucciones del camino equivocado. El que **debe** sobrevivir al freeze es el branch
> en EX/MEM, porque es el que maneja la redirección.

### Solución (aplicada)

`src/sources_1/Top/riscv.sv`, instancia `EX_MEM`:

```diff
-        .i_flush        (w_PCSrc),
+        .i_flush        (w_PCSrc & i_if_enable),
```

Con el flush gateado, durante el freeze el branch **sobrevive** en EX/MEM (enable=0 →
flush=0 → el buffer retiene) y `PCSrc` se mantiene; en el próximo ciclo habilitado el
flush y el `PC ← target` ocurren juntos, idéntico a continuo. La instrucción B+4 se
sigue flusheando correctamente (en continuo `w_PCSrc & 1 = w_PCSrc`).

### Por qué no lo agarraban los tests

`tb_branch.sv` corre siempre en continuo (`i_if_enable=1` fijo), así que no puede
ejercitar el modo paso a paso. El nuevo `tb_step_branch.sv` **emula** el step (pulsa
`i_if_enable` un ciclo y congela `FREEZE` ciclos) y reproduce el bug de forma
determinística.

### Cómo ejecutar el testbench

```bash
bash .claude/skills/run-tests/scripts/run_tests.sh
```

### Salida esperada (tras la corrección)

```
--- Taken branch in STEP-BY-STEP (freeze=4) ---
  PASS  STEP: x8 == 3 (branch target re-fetched)
  PASS  STEP: x10 == 0 (B+4 flushed)
  PASS  STEP: x11 == 0 (B+8 flushed)
```

### Validación en hardware

Se reproduce y corrige en la Basys-3 cargando el programa de arriba y avanzando con
`riscv_debug.py ... step` (reprogramar la placa antes para garantizar reset, porque la
DebugUnit solo acepta `WRITE_IM` desde el estado `INITIAL`): el dump del último paso
debe mostrar `x8 == 3` con el bitstream corregido (la versión ungated daba `x8 == 0`).
