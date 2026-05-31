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
- Importante en este diseño: el **PC cuenta palabras, no bytes**. Por eso los
  saltos se miden en "+1 instrucción", no en "+4 bytes" como en el RISC-V real.
  Esto está documentado en [`CLAUDE.md`](../CLAUDE.md) ("PC increment unit: Adds
  1, not 4").

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

El tercer operando es **a cuántas instrucciones saltar** (relativo a la posición
del propio branch). En este diseño, como el PC cuenta palabras, `+2` significa
"saltá 2 instrucciones más adelante".

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
        jal  x1, +2       # (1) saltar +2 instrucciones; x1 = retorno = PC+1
        addi x5, x0, 1    # (2) SE SALTEA (nunca se ejecuta)
SUBR:   addi x5, x0, 2    # (3) destino del salto; x5 = 2
        jalr x0, x1, 0    # (4) volver usando x1
        addi x5, x0, 3    # (5) se reanuda acá; x5 = 3
```

Paso a paso, suponiendo que el `jal` está en la dirección (palabra) **0**:

| PC | Instrucción         | Qué pasa                                                        |
|----|---------------------|----------------------------------------------------------------|
| 0  | `jal x1, +2`        | Guarda `x1 = 0 + 1 = 1` (retorno). Salta a `0 + 2 = 2`.        |
| 1  | `addi x5, x0, 1`    | **Salteada** (el PC pasó de 0 a 2, nunca pisó la 1).           |
| 2  | `addi x5, x0, 2`    | `x5 = 2`. Sigue normal a la 3.                                  |
| 3  | `jalr x0, x1, 0`    | Vuelve: salta a `x1 + 0 = 1`... ¡pero ojo! → ver abajo.        |

Acá está la clave del ejemplo: **`x1` guarda `1`** (la instrucción *siguiente* al
`jal`, que era el `addi x5,x0,1` salteado). El `jalr` salta a la dirección `1`,
con lo cual ahora **sí** se ejecuta esa instrucción y *después* la 2 otra vez,
hasta caer en la 4 (`addi x5,x0,3`).

> 💡 Por eso el resultado final del enunciado es **`x5 = 3`** y **`x1` = dirección
> de retorno** (la instrucción inmediatamente posterior al `jal`). El "link" es
> literalmente "PC del jal + 1".

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
