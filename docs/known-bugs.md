# Bugs conocidos

## BUG-001 — LUI produce resultado incorrecto cuando `rd[2:0] != 000`

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
| ID    | `ImmediateExtend` genera `{inst[31:12], 12'b0}` — el inmediato ya está en posición. La `ControlUnit` activa `RegWrite=1`, `ALUSrc=1`, `MemToReg=0`, `Jump=0`. No hay `rs1`/`rs2` reales: esos bits son partes del inmediato. |
| EX    | La ALU debería hacer `0 + imm = imm` (o simplemente pasar el inmediato). Con `ALUSrc=1`, el operando B es el inmediato correcto. **El operando A es irrelevante**. |
| MEM   | `MemRead=0`, `MemWrite=0` — no toca memoria. |
| WB    | `MemToReg=0`, `Jump=0` → escribe `alu_result` en `rd`. |

El resultado esperado en `rd` es siempre `{imm[31:12], 12'b0}`.

---

### Raíz del bug

La instrucción U-type no tiene campo `funct3`. Los bits `[14:12]`, que en otras instrucciones codifican `funct3`, en U-type son los **3 bits bajos de `rd`**:

```
inst[31:12]   inst[11:7]   inst[6:0]
 imm[31:12]      rd        0110111
    ↑
inst[14:12] = rd[2:0]   ← "funct3" que llega a ALUControl
inst[30]    = imm[30]   ← "funct7_5" que llega a ALUControl
```

`ControlUnit` asigna `ALUOp = 2'b11` para LUI, igual que para instrucciones I-type
aritméticas. `ALUControl` con `ALUOp=11` decodifica `funct3` para elegir la
operación:

```
6'b11_000_?: ADDI  (ADD)   ← funct3=000 → correcto solo si rd[2:0]=000
6'b11_001_?: SLLI           ← funct3=001 → rd=x1,x9,x17,x25...
6'b11_101_0: SRLI           ← funct3=101 → rd=x5,x13,x21...
...
```

### Condición de fallo

LUI falla cuando `rd[2:0] != 3'b000`, es decir para todo registro destino que no
sea `x0`, `x8`, `x16` o `x24`.

| rd | rd[2:0] | Operación real de la ALU | Resultado |
|----|---------|--------------------------|-----------|
| x0, x8, x16, x24 | 000 | ADD | `rs1_garbage + imm` — correcto **solo si** `rs1_garbage = 0` |
| x1, x9, x17, x25 | 001 | SLLI | `rs1_garbage << imm[4:0]` — incorrecto |
| x2, x10, x18, x26 | 010 | SLTI | incorrecto |
| x5, x13, x21, x29 | 101 | SRLI/SRAI | `rs1_garbage >> imm[4:0]` — incorrecto |
| ... | ... | ... | ... |

Incluso en el caso `rd[2:0]=000` (ADD), el operando A es
`RegisterFile[inst[19:15]]` = `RegisterFile[imm[19:15]]` — un registro indexado
por bits del inmediato, no necesariamente cero.

### Solución propuesta

Cambiar `ControlUnit` para que LUI use `ALUOp = 2'b00` (ADD forzado, igual que
`lw`/`sw`) y forzar el operando A a cero. Opciones:

1. Agregar un mux en EX controlado por una señal nueva `LUI` que seleccione `0`
   como operando A, dejando `operand_b = imm` → resultado = `imm`. (**mínimo cambio**)
2. Agregar un `ALUOp = 2'b10x` que directamente pase el operando B, sin depender
   de `funct3`.

**Testbench:** [`src/sim_1/EX/tb_lui_bug.sv`](../src/sim_1/EX/tb_lui_bug.sv)
