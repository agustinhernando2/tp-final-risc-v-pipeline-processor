# Guía de instrucciones RISC-V (con ejemplos)

Esta guía explica **las instrucciones que soporta este procesador** de forma
sencilla y con ejemplos paso a paso. Empieza por lo básico (un repaso rápido) y
después se mete en las que más cuestan: **branches (`beq`/`bne`), `jal`, `jalr`
y `lui`**.

> El procesador implementa este conjunto (ver
> [`ControlUnit.sv`](../src/sources_1/ID/ControlUnit.sv)):
> R-type · I-type ALU · `lw` · `sw` · `beq` · `bne` · `jal` · `jalr` · `lui`.

## Cómo leer una instrucción

Casi todas las instrucciones tienen esta forma:

```
operacion  destino, fuente1, fuente2/inmediato
```

- **`x0`** siempre vale `0` (está cableado a cero). Escribir en `x0` no hace nada
  — es un truco muy usado para "tirar" un resultado.
- **inmediato**: un número constante que viene metido *dentro* de la instrucción
  (no en un registro).
- En este diseño el **PC cuenta bytes** (igual que el RISC-V real y el libro de
  Patterson & Hennessy): incrementa de a 4 y los saltos se miden en bytes
  (`+4 bytes` = una instrucción más adelante). La memoria de instrucciones se
  indexa con `PC >> 2`. Ver [`docs/CONSIDERACIONES.md`](CONSIDERACIONES.md).

---

## 1. Las básicas (repaso rápido)

### Aritmética/lógica con registros (R-type)

```asm
add  x5, x6, x7   # x5 = x6 + x7
sub  x5, x6, x7   # x5 = x6 - x7
and  x5, x6, x7   # x5 = x6 AND x7 (bit a bit)
or   x5, x6, x7   # x5 = x6 OR  x7
```

Lee dos registros, opera, guarda en el destino.

### Aritmética con inmediato (I-type)

```asm
addi x5, x6, 10   # x5 = x6 + 10
ori  x5, x6, 0xF  # x5 = x6 OR 0xF
```

Igual que las anteriores, pero el segundo operando es una **constante**.
`addi x5, x0, 10` es la forma típica de "cargar el número 10 en x5"
(porque `x0 = 0`, entonces `x5 = 0 + 10`).

### Memoria: `lw` (load) y `sw` (store)

```asm
lw  x5, 8(x6)     # x5 = Memoria[ x6 + 8 ]   (leer de memoria a registro)
sw  x5, 8(x6)     # Memoria[ x6 + 8 ] = x5   (guardar registro en memoria)
```

Se lee como: *"el inmediato (8) es un desplazamiento que se suma a la dirección
base que está en x6"*. `8(x6)` = dirección `x6 + 8`.

---

## 2. Branches: `beq` y `bne` (saltos condicionales)

Un **branch** decide *si saltar o no* según una comparación. Si la condición se
cumple, el PC salta a un destino relativo; si no, sigue con la instrucción de
abajo como siempre.

```asm
beq  x5, x6, ETIQUETA   # Branch if EQual:     salta si x5 == x6
bne  x5, x6, ETIQUETA   # Branch if Not Equal: salta si x5 != x6
```

El tercer operando es el **desplazamiento en bytes** (relativo a la posición del
propio branch). Como el PC cuenta bytes, `+8` significa "saltá 8 bytes
= 2 instrucciones más adelante".

### Ejemplo: contar de 0 a 3 con un loop

```asm
        addi x5, x0, 0    # x5 = 0   (contador)
        addi x6, x0, 3    # x6 = 3   (tope)
LOOP:   addi x5, x5, 1    # x5 = x5 + 1
        bne  x5, x6, -1   # si x5 != 3, volver 1 instrucción atrás (a LOOP)
        # ...cuando x5 == 3, no salta y sigue acá
```

- Mientras `x5 != x6`, el `bne` salta hacia atrás y repite el `addi`.
- Cuando `x5` llega a 3, la condición `x5 != x6` es falsa → **no salta** → sigue
  de largo. Salimos del loop.

---

## 3. `jal` — Jump And Link (llamar a una subrutina)

`jal` hace **dos cosas a la vez**:

1. **Salta** incondicionalmente a un destino (siempre salta, no compara nada).
2. **Guarda la dirección de retorno** (la instrucción *siguiente* al `jal`) en el
   registro destino. A eso se le llama el *"link"*.

```asm
jal  rd, offset
#    │   └── a cuántas instrucciones saltar (relativo al jal)
#    └────── dónde guardar la dirección de retorno (PC del jal + 1)
```

¿Por qué guardar el retorno? Para que la subrutina sepa **a dónde volver** cuando
termine. Por convención se usa `x1` (llamado `ra`, *return address*) para eso.

> Si no te interesa volver (un salto "de una sola dirección"), usás `jal x0, ...`:
> como `x0` no se puede escribir, simplemente descartás la dirección de retorno.

### Ejemplo: llamar a una subrutina y volver (tu programa de prueba)

```asm
        jal  x1, +3       # (0) saltar a SUBR; x1 = retorno = PC+1 = 1
        addi x5, x0, 3    # (1) se reanuda ACÁ al volver; x5 = 3
        # ... fin del programa principal      (2)
SUBR:   addi x5, x0, 2    # (3) cuerpo de la subrutina; x5 = 2
        jalr x0, x1, 0    # (4) volver usando x1 (a la dirección 1)
```

Paso a paso, suponiendo que el `jal` está en la dirección (palabra) **0**:

| PC | Instrucción         | Qué pasa                                                        |
|----|---------------------|----------------------------------------------------------------|
| 0  | `jal x1, +3`        | Guarda `x1 = 0 + 1 = 1` (retorno). Salta a `0 + 3 = 3`.        |
| 3  | `addi x5, x0, 2`    | `x5 = 2`. Sigue normal a la 4.                                  |
| 4  | `jalr x0, x1, 0`    | Vuelve: salta a `x1 + 0 = 1`.                                   |
| 1  | `addi x5, x0, 3`    | Se reanuda el programa principal; `x5 = 3`.                     |
| 2  | *(fin)*             | Termina.                                                        |

Acá está la clave: **`x1` guarda `1`** (la instrucción *siguiente* al `jal`, que es
la continuación del programa principal). Por eso la subrutina tiene que vivir
**fuera** del flujo lineal (al final, alcanzable solo por el salto): si la metés
justo en medio, el retorno te haría re-ejecutar código y entrarías en un loop.

> 💡 Resultado final: **`x5 = 3`** y **`x1` = dirección de retorno** (la instrucción
> inmediatamente posterior al `jal`). El "link" es literalmente "PC del jal + 1".

La idea importante a quedarse: **`jal` = saltar + dejar una miga de pan (`x1`)
para poder volver.**

---

## 4. `jalr` — Jump And Link Register (volver, o salto indirecto)

`jalr` es el compañero de `jal`. La diferencia: el destino del salto **no es un
offset fijo en la instrucción, sino el contenido de un registro** (más un
inmediato).

```asm
jalr rd, rs1, offset
#    │    │     └── inmediato que se suma a rs1
#    │    └──────── registro base: acá está la dirección a la que saltar
#    └───────────── dónde guardar el retorno (igual que jal: PC+1)
```

Destino del salto = **`rs1 + offset`**.

### Uso típico 1: volver de una subrutina (`return`)

```asm
jalr x0, x1, 0    # PC = x1 + 0  →  vuelve a la dirección que dejó el jal
```

- `rs1 = x1` (la dirección de retorno que guardó el `jal`).
- `offset = 0` → saltamos exactamente ahí.
- `rd = x0` → no necesitamos guardar un nuevo retorno, lo tiramos.

Esto es el clásico `ret` de una función.

### Uso típico 2: salto indirecto / a direcciones lejanas

Como el destino sale de un registro, `jalr` puede saltar a **cualquier** lugar
(no estás limitado al rango del inmediato del `jal`). Sirve para:

- tablas de saltos (`switch`),
- llamar a funciones cuya dirección se calculó en tiempo de ejecución.

### `jal` vs `jalr` de un vistazo

| | `jal` | `jalr` |
|---|-------|--------|
| ¿Cuándo salta? | Siempre | Siempre |
| Destino | PC + offset (fijo en la instrucción) | **registro** `rs1` + offset |
| ¿Guarda retorno en `rd`? | Sí (PC+1) | Sí (PC+1) |
| Uso típico | Llamar a subrutina | **Volver** de subrutina / salto indirecto |

---

## 5. `lui` — Load Upper Immediate (armar constantes grandes)

**Problema:** los inmediatos de `addi` son chicos (12 bits → rango ±2048 aprox).
¿Cómo metés una constante grande, como `0x12345000`, en un registro?

**Solución:** `lui` carga un inmediato en la **parte ALTA** del registro (los bits
de más peso) y deja los de abajo en cero.

```asm
lui x5, 0x12345    # x5 = 0x12345 << 12 = 0x12345000
```

Es decir, `lui` toma el inmediato y lo "corre" hacia los bits altos. Los 12 bits
de abajo quedan en `0`.

### Patrón clásico: `lui` + `addi` para una constante de 32 bits

Para armar `0x12345678` completo:

```asm
lui  x5, 0x12345     # x5 = 0x12345000   (parte alta)
addi x5, x5, 0x678   # x5 = 0x12345678   (le sumás la parte baja)
```

Primero la mitad de arriba con `lui`, después la de abajo con `addi`. Entre las
dos cubrís los 32 bits.

> ⚠️ Detalle real de RISC-V: como el inmediato de `addi` está con signo, a veces
> hay que ajustar la parte alta en 1. Para entenderlo de entrada, quedate con la
> idea principal: **`lui` pone los bits de arriba, `addi` completa los de abajo.**

---

## Resumen en una tabla

| Instrucción | Tipo | Qué hace (en una línea) |
|-------------|------|--------------------------|
| `add/sub/and/or` | R | Operan dos registros → destino |
| `addi/ori`       | I | Operan registro + constante → destino |
| `lw`             | I | Lee de memoria a un registro |
| `sw`             | S | Guarda un registro en memoria |
| `beq`            | B | Salta **si** los dos registros son **iguales** |
| `bne`            | B | Salta **si** son **distintos** |
| `jal`            | J | Salta siempre y guarda el retorno (llamar subrutina) |
| `jalr`           | I | Salta a `rs1+offset` (volver / salto indirecto) |
| `lui`            | U | Carga un inmediato en la parte alta del registro |

## Para seguir

- Riesgos de datos y cómo se resuelven: [`forwarding-unit.md`](forwarding-unit.md)
  y [`hazard-detection-unit.md`](hazard-detection-unit.md).
- Estructura general del procesador: [`structure.md`](structure.md).

---

## Tabla completa de instrucciones soportadas

Fuente de verdad: [`ControlUnit.sv`](../../src/sources_1/ID/ControlUnit.sv), [`ALUControl.sv`](../../src/sources_1/EX/ALUControl.sv), [`DataMemory.sv`](../../src/sources_1/MEM/DataMemory.sv).

La columna **Datapath (EX / MEM)** muestra los componentes activos en cada etapa, separados por ` / `. `·` encadena componentes dentro de la misma etapa. `ImmExt` = immediate extender + ALUSrc mux; `BrAdder` = sumador PC+imm de EX; `DM` = data memory; `PCSrc` = lógica de redirección del PC en MEM.

### R-type — `opcode = 0110011` (`0x33`)

| Instrucción | funct3 | funct7[5] | Descripción | Datapath (EX / MEM) |
|-------------|--------|-----------|-------------|---------------------|
| `add`       | `000`  | `0`       | Suma dos registros | `ALU` |
| `sub`       | `000`  | `1`       | Resta dos registros | `ALU` |
| `sll`       | `001`  | —         | Desplazamiento lógico a la izquierda | `ALU` |
| `slt`       | `010`  | —         | 1 si rs1 < rs2 (con signo) | `ALU` |
| `sltu`      | `011`  | —         | 1 si rs1 < rs2 (sin signo) | `ALU` |
| `xor`       | `100`  | —         | XOR bit a bit | `ALU` |
| `srl`       | `101`  | `0`       | Desplazamiento lógico a la derecha | `ALU` |
| `sra`       | `101`  | `1`       | Desplazamiento aritmético a la derecha | `ALU` |
| `or`        | `110`  | —         | OR bit a bit | `ALU` |
| `and`       | `111`  | —         | AND bit a bit | `ALU` |

### I-type aritmético — `opcode = 0010011` (`0x13`)

El inmediato **no va directo al RF** — entra al ALU por el ALUSrc mux (operand B). La ALU siempre opera.

| Instrucción | funct3 | funct7[5] | Descripción | Datapath (EX / MEM) |
|-------------|--------|-----------|-------------|---------------------|
| `addi`      | `000`  | —         | Suma registro + inmediato | `ImmExt · ALU` |
| `slli`      | `001`  | —         | Desplazamiento lógico izq. con inmediato | `ImmExt · ALU` |
| `slti`      | `010`  | —         | 1 si rs1 < imm (con signo) | `ImmExt · ALU` |
| `sltiu`     | `011`  | —         | 1 si rs1 < imm (sin signo) | `ImmExt · ALU` |
| `xori`      | `100`  | —         | XOR con inmediato | `ImmExt · ALU` |
| `srli`      | `101`  | `0`       | Desplazamiento lógico der. con inmediato | `ImmExt · ALU` |
| `srai`      | `101`  | `1`       | Desplazamiento aritmético der. con inmediato | `ImmExt · ALU` |
| `ori`       | `110`  | —         | OR con inmediato | `ImmExt · ALU` |
| `andi`      | `111`  | —         | AND con inmediato | `ImmExt · ALU` |

### Load — `opcode = 0000011` (`0x03`)

| Instrucción | funct3 | Descripción | Datapath (EX / MEM) |
|-------------|--------|-------------|---------------------|
| `lb`        | `000`  | Lee 1 byte, extendido con signo | `ImmExt · ALU` / `DM[R]` |
| `lh`        | `001`  | Lee 2 bytes, extendido con signo | `ImmExt · ALU` / `DM[R]` |
| `lw`        | `010`  | Lee 4 bytes (palabra completa) | `ImmExt · ALU` / `DM[R]` |
| `lbu`       | `100`  | Lee 1 byte, extendido con cero | `ImmExt · ALU` / `DM[R]` |
| `lhu`       | `101`  | Lee 2 bytes, extendido con cero | `ImmExt · ALU` / `DM[R]` |
| `lwu`       | `110`  | Lee 4 bytes, extendido con cero (≡ `lw` en 32 bits) | `ImmExt · ALU` / `DM[R]` |

### Store — `opcode = 0100011` (`0x23`)

| Instrucción | funct3 | Descripción | Datapath (EX / MEM) |
|-------------|--------|-------------|---------------------|
| `sb`        | `000`  | Escribe 1 byte en memoria | `ImmExt · ALU` / `DM[W]` |
| `sh`        | `001`  | Escribe 2 bytes en memoria | `ImmExt · ALU` / `DM[W]` |
| `sw`        | `010`  | Escribe 4 bytes en memoria | `ImmExt · ALU` / `DM[W]` |

### Branch — `opcode = 1100011` (`0x63`)

Solo BEQ y BNE están implementadas. La lógica en `MemoryAccessStage` evalúa `zero ^ funct3[0]` (flag de igualdad del ALU); BLT/BGE/BLTU/BGEU no son soportadas.

En EX: la ALU hace SUB (ALUOp=01 forzado) para obtener el flag `zero`, y el `BrAdder` calcula PC+imm en paralelo. En MEM: `PCSrc` decide si redirigir el PC.

| Instrucción | funct3 | Descripción | Datapath (EX / MEM) |
|-------------|--------|-------------|---------------------|
| `beq`       | `000`  | Salta si rs1 == rs2 | `ALU(SUB) · BrAdder` / `PCSrc` |
| `bne`       | `001`  | Salta si rs1 != rs2 | `ALU(SUB) · BrAdder` / `PCSrc` |

### U-type

En EX: el mux `u_mux_alu_a` fuerza el operand A de la ALU a `0`, entonces la ALU computa `0 + imm = imm`. El inmediato **no bypasea la ALU**.

| Instrucción | Opcode             | funct3 | funct7[5] | Descripción | Datapath (EX / MEM) |
|-------------|--------------------|--------|-----------|-------------|---------------------|
| `lui`       | `0110111` (`0x37`) | —      | —         | Carga inmediato en bits [31:12] del registro | `ImmExt · ALU(0+imm)` |

### J-type / saltos

Para `jal`: en EX el `BrAdder` calcula PC+imm (destino); `PC+4` fluye como valor de retorno hacia WB. Para `jalr`: la ALU calcula rs1+imm (destino) y ese resultado se usa como PC en MEM.

| Instrucción | Opcode             | funct3 | funct7[5] | Descripción | Datapath (EX / MEM) |
|-------------|--------------------|--------|-----------|-------------|---------------------|
| `jal`       | `1101111` (`0x6F`) | —      | —         | Salta a PC+offset; guarda retorno en rd | `ImmExt · BrAdder` / `PCSrc · PC+4→rd` |
| `jalr`      | `1100111` (`0x67`) | `000`  | —         | Salta a rs1+offset; guarda retorno en rd | `ImmExt · ALU` / `PCSrc · ALU→PC` |

### Custom

| Instrucción | Opcode             | funct3 | funct7[5] | Descripción | Datapath (EX / MEM) |
|-------------|--------------------|--------|-----------|-------------|---------------------|
| `halt`      | `0001011` (`0x0B`) | —      | —         | Detiene el pipeline (custom-0); los programas deben terminar con esta instrucción | `—` |
