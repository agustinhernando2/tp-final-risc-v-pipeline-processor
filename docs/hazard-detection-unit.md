# Unidad de Detección de Riesgos (`HazardDetectionUnit`)

Archivo: [`src/sources_1/Hazard/HazardDetectionUnit.sv`](../src/sources_1/Hazard/HazardDetectionUnit.sv)
Cableado top-level: [`src/sources_1/Top/riscv.sv`](../src/sources_1/Top/riscv.sv) (instancia `HDU`)

> **Validado contra** Patterson & Hennessy, *Computer Organization and Design:
> RISC-V Edition*, §**4.7 "Data Hazards: Forwarding versus Stalling"**,
> subsección **"Data Hazards and Stalls"** (pp. 303–307). Las citas de figura y
> página corresponden al texto incluido en la skill `riscv-expert`
> (`references/patterson_riscv.md`).

## 1. Propósito

El forwarding resuelve la mayoría de los riesgos de datos sin perder ciclos,
**pero hay un caso que no puede resolver: el riesgo *load-use***. Cuando un
`load` produce un dato y la instrucción siguiente lo usa, el dato sale de
memoria al final de MEM, es decir **un ciclo demasiado tarde** para adelantarlo
a la ALU de la instrucción siguiente (libro p. 303, Figura **4.56**).

```asm
ld  x2, 20(x1)   # el dato de x2 sale de memoria al final de MEM (CC4)
and x4, x2, x5   # necesita x2 al inicio de EX (CC4) -> imposible por forwarding
```

La única solución es **detener (*stall*) el pipeline un ciclo** e insertar una
burbuja (nop). Tras ese ciclo el dato ya está en MEM/WB y el forwarding normal
(distancia 2, `ForwardA/B = 01`) lo entrega.

> El libro lo enuncia así (p. 303): *"in addition to a forwarding unit, we need a
> hazard detection unit. It operates during the ID stage so that it can insert
> the stall between the load and the instruction dependent on it."*
>
> Los riesgos de **control** (branches/jumps) son §**4.8 "Control Hazards"**
> (p. 307) y NO los maneja este módulo (ver §6, fuera de alcance — Stage 8).

## 2. Interfaz del módulo

```systemverilog
module HazardDetectionUnit #(parameter NB_REG = 5) (
    input  logic              i_id_ex_MemRead, // ID/EX.MemRead (¿la instr. en EX es load?)
    input  logic [NB_REG-1:0] i_id_ex_rd,      // ID/EX.RegisterRd (destino del load)
    input  logic [NB_REG-1:0] i_if_id_rs1,     // IF/ID.RegisterRs1 (fuente en ID)
    input  logic [NB_REG-1:0] i_if_id_rs2,     // IF/ID.RegisterRs2 (fuente en ID)
    output logic              o_PCWrite,        // 0 = congelar PC
    output logic              o_IF_ID_Write,    // 0 = congelar IF/ID
    output logic              o_ID_EX_flush     // 1 = insertar burbuja en ID/EX
);
```

Es **puramente combinacional** (`always_comb`). Opera en ID, como pide el libro.

## 3. Condición de detección (vs. ecuación de p. 304)

Código (`HazardDetectionUnit.sv`, líneas 22–23):

```
if (ID/EX.MemRead and ID/EX.Rd != 0 and
    (ID/EX.Rd == IF/ID.Rs1 or ID/EX.Rd == IF/ID.Rs2))
        stall
```

Ecuación del libro (p. 304):

```
if (ID/EX.MemRead and
    ((ID/EX.RegisterRd = IF/ID.RegisterRs1) or
     (ID/EX.RegisterRd = IF/ID.RegisterRs2)))
        stall the pipeline
```

✅ Coincide. La primera línea testea que la instrucción en EX sea un load (el
único que lee memoria); las otras dos comparan el destino del load con las
fuentes de la instrucción en ID.

> **Diferencia menor (mejora):** el código añade `ID/EX.Rd != 0`, que el libro
> **no** incluye en la detección load-use (sí lo incluye, en cambio, en el
> forwarding, p. 297). Es un guard inofensivo y beneficioso: un `ld x0, ...`
> nunca crea dependencia real, así que evita un stall innecesario. No introduce
> errores.

## 4. Efecto del stall sobre el pipeline (pp. 304–306)

El libro (p. 304–305) indica: si la instrucción en ID se detiene, también hay que
detener la de IF, **impidiendo que cambien el PC y el registro IF/ID**; y se
inserta una burbuja **poniendo a 0 los campos de control EX/MEM/WB del registro
ID/EX** (p. 305–306). Las tres salidas implementan esto:

| Salida           | Valor en stall | Destino en `riscv.sv`                              | Efecto |
|------------------|:--------------:|---------------------------------------------------|--------|
| `o_PCWrite`      | `0`            | `w_if_pc_enable = i_if_enable & w_PCWrite` → IF    | El PC no avanza: se re-busca la misma instrucción |
| `o_IF_ID_Write`  | `0`            | `w_if_id_enable = i_if_enable & w_IF_ID_Write` → IF/ID | IF/ID congelado: ID re-decodifica lo mismo |
| `o_ID_EX_flush`  | `1`            | `w_ID_EX_flush` → `ID_EX.i_flush`                  | ID/EX se pone a 0: avanza un nop (burbuja) a EX |

Las señales `PCWrite` e `IF/IDWrite` son exactamente las que aparecen en la
Figura **4.58** del libro (overview de control con la hazard detection unit).

El buffer [`ID_EX_Buffer`](../src/sources_1/Buffers/ID_EX_Buffer.sv) implementa
la burbuja en su `always_ff`: `if (i_reset || i_flush)` pone todas las salidas a
`'0` (líneas 51–69), desactivando RegWrite/MemWrite/etc.

> Nota del libro (Elaboration, p. 307): en rigor solo hace falta poner a 0
> `RegWrite` y `MemWrite`; el resto pueden quedar *don't care*. Acá se ponen a 0
> **todas** las señales del ID/EX, lo cual es correcto (más conservador).
>
> `ID_EX.i_enable` queda en `1'b1` (no se congela). Es lo correcto: la burbuja
> **debe** avanzar hacia EX; el congelamiento ocurre solo en PC e IF/ID.

## 5. Diagramas

### Conexiones (equivale a la Figura 4.58)

```
   IF/ID.Rs1 ─────────────┐   (= instruction[19:15])
   IF/ID.Rs2 ───────────┐ │   (= instruction[24:20])
   ID/EX.Rd ──────────┐ │ │
   ID/EX.MemRead ───┐ │ │ │
                    ▼ ▼ ▼ ▼
               ┌────────────────────┐
               │ HazardDetectionUnit│  (combinacional, opera en ID)
               └──┬──────┬──────┬───┘
       o_PCWrite  │      │      │  o_ID_EX_flush
                  │      │ o_IF_ID_Write
         (& i_if_enable) │      │
                  ▼      ▼      ▼
            ┌────────┐ ┌────────┐ ┌─────────────┐
            │ PC reg │ │IF/ID buf│ │ ID/EX buffer│
            │ en=¬st │ │ en=¬st  │ │ flush=stall │
            └────────┘ └─────────┘ └─────────────┘
            (no avanza) (no avanza) (inserta nop)
            st = condición de stall
```

### Línea de tiempo (load-use) — equivale a la Figura 4.57

```
ciclo:        1    2    3    4    5    6    7
ld  x2      IF   ID   EX   MEM  WB
and x2..         IF   ID   ID*  EX   MEM  WB      <- ID se repite (stall)
(burbuja)             ··   nop  MEM  WB           <- burbuja inyectada en ID/EX
or  ..                IF   IF*  ID   EX   ...     <- IF congelado un ciclo
                           ▲
                      ID* / IF* = ciclo de stall
```

Tras el stall, `and` lee `x2` ya disponible en MEM/WB → la `ForwardingUnit`
(camino MEM/WB → EX, `ForwardA/B = 01`) lo entrega. Ver
[`forwarding-unit.md`](forwarding-unit.md).

## 6. Validación de la implementación

| Aspecto                                                  | Estado | Referencia |
|---------------------------------------------------------|:------:|-----------|
| Detección load-use (MemRead + match rs1/rs2)            |  ✅   | p. 304; código líneas 22–23 |
| Guard extra `Rd != 0`                                   |  ✅+  | Mejora sobre el libro (inofensiva) |
| Congelado de PC (`o_PCWrite`)                           |  ✅   | p. 304–305; `riscv.sv` 30, 209 |
| Congelado de IF/ID (`o_IF_ID_Write`)                    |  ✅   | p. 304–305; `riscv.sv` 31, 210 |
| Inserción de burbuja (`o_ID_EX_flush` → `i_flush`)      |  ✅   | p. 305–306; `riscv.sv` 162, 211; buffer 51–69 |
| Instanciación en `riscv.sv`                             |  ✅   | Figura 4.58; instancia `HDU` 202–212 |
| Testbench dedicado                                      |  ✅   | `src/sim_1/Hazard/tb_Forwarding.sv` (Test B: load-use) |
| Riesgos de control (branch/jump)                        |  ❌   | §4.8 (p. 307); pendiente Stage 8 |

### Conclusión

La unidad de detección de riesgos está **implementada en su totalidad y
correctamente integrada** para el riesgo **load-use**: la condición coincide con
la de p. 304, las tres salidas de control están cableadas (PC, IF/ID y burbuja en
ID/EX, igual que la Figura 4.58) y existe testbench (`tb_Forwarding.sv`, Test B).
El único agregado (`Rd != 0`) es una mejora respecto del texto base.

**Lo que NO cubre** (por diseño, corresponde a otra etapa): los **riesgos de
control** de branches y saltos (§4.8, p. 307). En `riscv.sv` el
`InstructionFetch` está instanciado con `i_PCSrc(1'b0)` fijo y sin redirección de
PC, y las señales `Branch`/`Jump` viajan por los buffers pero todavía no generan
flush. Esto es el **Stage 8** pendiente según `plans/plan.md`.

Ver la unidad complementaria en
[`forwarding-unit.md`](forwarding-unit.md).
