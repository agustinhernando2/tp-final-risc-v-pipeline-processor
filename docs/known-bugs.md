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
