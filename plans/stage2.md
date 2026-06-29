# Stage 2 — Control Unit

**Status: DONE**

---

## Files created / modified

| File | Action |
|------|--------|
| `src/sources_1/ID/ControlUnit.sv` | Created |
| `src/sources_1/ID/InstructionDecode.sv` | Updated — instantiates ControlUnit, removes `i_ImmSrc` input, adds control signal outputs |
| `src/sim_1/ID/tb_ControlUnit.sv` | Created |

---

## Design notes

### ControlUnit.sv

Pure combinational (`always_comb`, `unique case`). Takes only `opcode[6:0]` — funct3/funct7 are not needed here; the ALUDecoder (Stage 3) handles them.

```
module ControlUnit #(
    parameter OPCODE_WIDTH = 7
)(
    input  logic [OPCODE_WIDTH-1:0] i_opcode,
    output logic                    o_RegWrite,
    output logic                    o_ALUSrc,
    output logic [1:0]              o_ALUOp,
    output logic                    o_MemRead,
    output logic                    o_MemWrite,
    output logic                    o_MemToReg,
    output logic                    o_Branch,
    output logic                    o_Jump,
    output logic [2:0]              o_ImmSrc
);
```

ALUOp encoding (P&H convention):

| ALUOp | Meaning |
|-------|---------|
| `2'b00` | Forced ADD (loads/stores) |
| `2'b01` | Forced SUB (branches) |
| `2'b10` | R-type — decode via funct3/funct7 in ALUDecoder |
| `2'b11` | I-type ALU — decode via funct3 only in ALUDecoder |

Truth table:

| Instruction | opcode | RegWrite | ALUSrc | ALUOp | MemRead | MemWrite | MemToReg | Branch | Jump | ImmSrc |
|-------------|--------|----------|--------|-------|---------|----------|----------|--------|------|--------|
| R-type      | 7'b0110011 | 1 | 0 | 10 | 0 | 0 | 0 | 0 | 0 | 000 |
| I-arith     | 7'b0010011 | 1 | 1 | 11 | 0 | 0 | 0 | 0 | 0 | 000 |
| Load        | 7'b0000011 | 1 | 1 | 00 | 1 | 0 | 1 | 0 | 0 | 000 |
| Store       | 7'b0100011 | 0 | 1 | 00 | 0 | 1 | 0 | 0 | 0 | 001 |
| Branch      | 7'b1100011 | 0 | 0 | 01 | 0 | 0 | 0 | 1 | 0 | 010 |
| LUI         | 7'b0110111 | 1 | 1 | 00 | 0 | 0 | 0 | 0 | 0 | 011 |
| JAL         | 7'b1101111 | 1 | 1 | 00 | 0 | 0 | 0 | 0 | 1 | 100 |
| JALR        | 7'b1100111 | 1 | 1 | 00 | 0 | 0 | 0 | 0 | 1 | 000 |
| default     | —      | 0 | 0 | 00 | 0 | 0 | 0 | 0 | 0 | 000 |

### InstructionDecode.sv changes

1. Remove `i_ImmSrc` from port list.
2. Instantiate `ControlUnit` driven by `i_instruction[6:0]`.
3. Feed ControlUnit's `o_ImmSrc` wire to `ImmediateExtend`'s `i_ImmSrc`.
4. Add outputs for all control signals + `o_funct3[2:0]` + `o_funct7_5` (bit 30):

```
output logic [2:0]  o_funct3
output logic        o_funct7_5
output logic        o_RegWrite
output logic        o_ALUSrc
output logic [1:0]  o_ALUOp
output logic        o_MemRead
output logic        o_MemWrite
output logic        o_MemToReg
output logic        o_Branch
output logic        o_Jump
```

Assignments: `o_funct3 = i_instruction[14:12]`, `o_funct7_5 = i_instruction[30]`.

---

## Running the tests

```bash
mkdir -p sim_out && cd sim_out

# 1. Compile
xvlog --sv \
  ../src/sources_1/ID/ControlUnit.sv \
  ../src/sim_1/ID/tb_ControlUnit.sv

# 2. Elaborate
xelab -debug typical tb_ControlUnit -s sim_cu

# 3. Simulate
xsim sim_cu --runall
```

Expected output ends with `ALL TESTS PASSED`.

---

## Test results

9/9 passed — all opcodes (R-type, I-arith, Load, Store, Branch, LUI, JAL, JALR, default) verified.

---

## Notas — comparación con Patterson & Hennessy (Fig. 4.18, pág. 258)

El libro define la Main Control Unit en la sección 4.4 cubriendo solo 4 opcodes: R-format, ld, sd, beq. Las señales que define son: `RegWrite`, `ALUSrc`, `ALUOp[1:0]`, `MemRead`, `MemWrite`, `MemtoReg`, `Branch`. No incluye `ImmSrc` ni `Jump`.

La implementación de Stage 2 es un **superset correcto** de lo que define el libro:

- Los valores de las 7 señales del libro para R-type, load, store y branch **coinciden exactamente** con Figure 4.18.
- El encoding de `ALUOp` sigue la convención del libro: `00`=ADD, `01`=SUB, `10`=R-type. Se agrega `11`=I-arith como extensión necesaria para separar ADDI/ANDI/ORI de los loads.
- `ImmSrc[2:0]` no existe en el libro (el ImmGen del libro es combinacional sobre la instrucción completa), pero se agrega aquí para manejar los cinco formatos de inmediato (I, S, B, U, J).
- `Jump` no existe en el libro (que no cubre JAL/JALR en 4.4), se agrega para las instrucciones de salto incondicional.
- LUI, JAL, JALR, I-arith no están en la tabla del libro; se agregan para cubrir el ISA del TP.

**LUI (resolución de BUG-001):** LUI no opera sobre registros fuente — debe
propagar el inmediato U-type (`rd = {imm[31:12], 12'b0}`). En U-type los bits
`inst[14:12]`/`inst[30]` son parte del inmediato, **no** un `funct3`/`funct7`
real, así que no se puede usar `ALUOp=11` (que decodifica esos bits). Solución
adoptada: LUI usa `ALUOp=00` (ADD forzado, el ALUDecoder ignora `funct3`) y la
`ControlUnit` emite además una señal `LUI=1` que se propaga por el `ID_EX_Buffer`
hasta `ExecuteStage`, donde un mux fuerza el operando A a `0`. Así la ALU calcula
`0 + imm = imm` para cualquier inmediato. Ver [`docs/known-bugs.md`](../docs/known-bugs.md) (BUG-001, resuelto).

---

## Next: Stage 3 — EX / ALU

`InstructionDecode` now outputs `o_ALUOp`, `o_funct3`, `o_funct7_5` which feed into `ID_EX_Buffer` (Stage 4) and then into `ALUDecoder` inside `ExecuteStage`.
