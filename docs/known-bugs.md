# Bugs conocidos

## BUG-001 — LUI produce resultado incorrecto cuando `imm[14:12] != 000`

**Estado:** abierto  
**Etapa afectada:** EX (`ALUControl` + `ALU`)  
**Archivos involucrados:**
- [`src/sources_1/ID/ControlUnit.sv`](../src/sources_1/ID/ControlUnit.sv) — origen del problema
- [`src/sources_1/EX/ALUControl.sv`](../src/sources_1/EX/ALUControl.sv) — donde se manifiesta
- [`src/sources_1/EX/ALU.sv`](../src/sources_1/EX/ALU.sv) — ejecuta la operación incorrecta

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

### Solución propuesta

Cambiar `ControlUnit` para que LUI use `ALUOp = 2'b00` (ADD forzado, igual que
`lw`/`sw`) y agregar un mux en EX que fuerce el operando A a `0` cuando la
instrucción es LUI, dejando `result = 0 + imm = imm`. Opciones concretas:

1. Señal `i_LUI` nueva en `ExecuteStage` que seleccione `0` como operando A antes
   de la ALU. **Mínimo cambio.**
2. Nuevo valor de `ALUOp` que pase directamente el operando B a la salida, sin
   depender de `funct3`.

**Testbench:** [`src/sim_1/EX/tb_lui_bug.sv`](../src/sim_1/EX/tb_lui_bug.sv)

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

### Salida esperada y cómo interpretarla

```
--- Grupo 1: ALUControl con imm[14:12] como funct3 (ALUOp=11) ---
  PASS  ALUCtrl [imm[14:12]=000] = ADD (0000) -- correcto para LUI
  FAIL  ALUCtrl [imm[14:12]=001]: esperado ADD (0000), obtenido 0010 -- LUI producira resultado incorrecto
  FAIL  ALUCtrl [imm[14:12]=101]: esperado ADD (0000), obtenido 0110 -- LUI producira resultado incorrecto
  ...
--- Grupo 2: resultado de lui x5, 0x12345 (imm[14:12]=101 -> SRLI) ---
  FAIL  lui x5,0x12345: expected 0x12345000, got 0xdeadbeef
--- Grupo 3: resultado de lui x1, 0x00001 (imm[14:12]=001 -> SLLI) ---
  FAIL  lui x1,0x00001: expected 0x00001000, got 0xcafebabe
--- Grupo 4: lui x5, 0x00100 (imm[14:12]=000 -> ADD, pero operand_a != 0) ---
  FAIL  lui x5,0x00100 con rs1_garbage=5: expected 0x00100000, got 0x00100005

--- Results: 1 passed, 10 failed ---
SOME TESTS FAILED
```

**Grupo 1** prueba `ALUControl` directamente: para cada valor posible de
`imm[14:12]` (los 3 bits bajos del inmediato de 20 bits), verifica si la operación
seleccionada es ADD. Solo `000` pasa; los otros 7 valores seleccionan SLLI, SLTI,
SRLI, etc.

El campo `obtenido XXXX` es el código binario de `ALUCtrl`:
`0000`=ADD, `0010`=SLLI, `0011`=SLTI, `0100`=SLTIU, `0101`=XORI,
`0110`=SRLI, `1000`=ORI, `1001`=ANDI.

**Grupos 2 y 3** ejercen la ALU completa con inmediatos reales:
- `got 0xdeadbeef` en el Grupo 2: SRLI desplazó 0 posiciones → devolvió el
  operando A (`0xDEAD_BEEF`) en lugar del inmediato `0x12345000`.
- `got 0xcafebabe` en el Grupo 3: SLLI desplazó 0 posiciones → devolvió el
  operando A (`0xCAFE_BABE`) en lugar de `0x00001000`.

**Grupo 4** muestra que incluso cuando `imm[14:12]=000` (ADD es la operación
correcta), el resultado sigue siendo incorrecto porque el operando A no es cero:
`0x00100000 + 5 = 0x00100005`.
