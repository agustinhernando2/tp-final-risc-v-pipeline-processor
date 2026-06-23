# Unidad de Forwarding (`ForwardingUnit`)

Archivo: [`src/sources_1/Hazard/ForwardingUnit.sv`](../src/sources_1/Hazard/ForwardingUnit.sv)
Integración EX: [`src/sources_1/EX/ExecuteStage.sv`](../src/sources_1/EX/ExecuteStage.sv)
Cableado top-level: [`src/sources_1/Top/riscv.sv`](../src/sources_1/Top/riscv.sv) (instancia `FWD`)

> **Validado contra** Patterson & Hennessy, *Computer Organization and Design:
> RISC-V Edition*, §**4.7 "Data Hazards: Forwarding versus Stalling"** (pp.
> 294–307). Las citas de figura y página corresponden al texto incluido en la
> skill `riscv-expert` (`references/patterson_riscv.md`, offset 6835).

## 1. Propósito

La unidad de forwarding (*bypassing*) resuelve los **riesgos de datos** que
aparecen cuando una instrucción necesita el resultado de otra que todavía no
llegó a WB. En vez de detener el pipeline, adelanta el dato desde un registro de
pipeline posterior directamente a las entradas de la ALU en EX.

Ejemplo del libro (p. 295), dependencias sobre `x2`:

```asm
sub  x2, x1, x3   # produce x2 (resultado disponible al final de EX)
and  x12, x2, x5  # necesita x2 en EX  -> hazard tipo 1a (EX/MEM)
or   x13, x6, x2  # necesita x2 en EX  -> hazard tipo 2b (MEM/WB)
add  x14, x2, x2  # ya lo lee del register file (sin hazard)
```

Sin forwarding, `and`/`or` leerían el `x2` viejo. La unidad detecta que `x2` ya
fue calculado y lo inyecta en la entrada correspondiente de la ALU.

> El libro lo introduce con las Figuras 4.50–4.51 (las dependencias que "van
> hacia atrás en el tiempo" son los hazards) y lo resuelve con la *forwarding
> unit* de la Figura **4.52** (p. 299–300).

## 2. Interfaz del módulo

```systemverilog
module ForwardingUnit #(parameter NB_REG = 5) (
    input  logic [NB_REG-1:0] i_id_ex_rs1,       // ID/EX.RegisterRs1 (operando A en EX)
    input  logic [NB_REG-1:0] i_id_ex_rs2,       // ID/EX.RegisterRs2 (operando B en EX)
    input  logic [NB_REG-1:0] i_ex_mem_rd,       // EX/MEM.RegisterRd (1 etapa adelante)
    input  logic              i_ex_mem_RegWrite, // EX/MEM.RegWrite
    input  logic [NB_REG-1:0] i_mem_wb_rd,       // MEM/WB.RegisterRd (2 etapas adelante)
    input  logic              i_mem_wb_RegWrite, // MEM/WB.RegWrite
    output logic [1:0]        o_ForwardA,         // selector mux operando A
    output logic [1:0]        o_ForwardB          // selector mux operando B
);
```

Es **puramente combinacional** (`always_comb`). Como dice el libro (p. 301), para
poder comparar los números de registro fuente en EX hubo que **propagar `rs1` y
`rs2` por el buffer ID/EX** — y efectivamente están en
[`ID_EX_Buffer`](../src/sources_1/Buffers/ID_EX_Buffer.sv).

## 3. Codificación de los selectores (Figura 4.53)

Cada salida controla un `mux2_4` que elige el operando real de la ALU. La tabla
de la **Figura 4.53** (p. 300) define exactamente:

| Valor   | Fuente seleccionada                         | Explicación del libro                       |
|---------|---------------------------------------------|---------------------------------------------|
| `2'b00` | Banco de registros (ID/EX.read_data)        | El operando viene del register file         |
| `2'b10` | **EX/MEM** (resultado de ALU)               | "forwarded from the prior ALU result"       |
| `2'b01` | **MEM/WB** (dato de WB: ALU o memoria)      | "forwarded from data memory or an earlier ALU result" |

✅ La codificación del código (`00/10/01`) coincide **exactamente** con la Figura
4.53.

## 4. Lógica de detección (vs. ecuaciones de pp. 300–301)

Código (`ForwardingUnit.sv`, líneas 22–34):

### EX hazard (distancia 1, prioridad ALTA) — p. 300

```
if (EX/MEM.RegWrite and EX/MEM.Rd != 0 and EX/MEM.Rd == ID/EX.RsN)
        ForwardN = 2'b10
```

Ecuación del libro:

```
if (EX/MEM.RegWrite and (EX/MEM.RegisterRd ≠ 0)
    and (EX/MEM.RegisterRd = ID/EX.RegisterRs1)) ForwardA = 10   (idem Rs2 → ForwardB)
```

### MEM hazard (distancia 2, prioridad BAJA) — p. 301

En el código se usa `else if`, que da prioridad automática a EX/MEM:

```
else if (MEM/WB.RegWrite and MEM/WB.Rd != 0 and MEM/WB.Rd == ID/EX.RsN)
        ForwardN = 2'b01
```

El libro escribe la prioridad de forma explícita (p. 301), añadiendo a la
condición MEM:

```
... and not(EX/MEM.RegWrite and (EX/MEM.RegisterRd ≠ 0)
            and (EX/MEM.RegisterRd = ID/EX.RegisterRs1)) ...   ForwardA = 01
```

El `else if` del código cubre exactamente ese `not(EX hazard)`. ✅ Equivalente.

Dos detalles clave, ambos presentes:

1. **Exclusión de `x0`** (`Rd != 0`): el libro lo justifica en p. 297 — escribir
   en `x0` no tiene efecto, así que nunca se debe forwardear su resultado. Es la
   condición `(RegisterRd ≠ 0)`.
2. **Prioridad EX/MEM > MEM/WB**: es el *double data hazard* de p. 301 (ej.
   `add x1,x1,x2; add x1,x1,x3; ...`): si ambas instrucciones previas escriben
   el mismo registro, gana la más reciente (EX/MEM).

## 5. Diagrama de conexiones (datapath EX)

Equivale a la Figura **4.54** (datapath con forwarding) + Figura **4.55** (mux
del inmediato/ALUSrc) del libro:

```
   ID/EX.Rs1 ─────────────────────────────┐
   ID/EX.Rs2 ───────────────────────────┐ │
   EX/MEM.Rd ─────────────────────────┐ │ │
   EX/MEM.RegWrite ─────────────────┐ │ │ │
   MEM/WB.Rd ─────────────────────┐ │ │ │ │
   MEM/WB.RegWrite ─────────────┐ │ │ │ │ │
                                ▼ ▼ ▼ ▼ ▼ ▼
                          ┌───────────────────┐
                          │  ForwardingUnit   │  (combinacional)
                          └───┬───────────┬───┘
                  o_ForwardA  │           │  o_ForwardB
                              ▼           ▼
   ID/EX.read_data_1 ──►┌──────────┐   ┌──────────┐◄── ID/EX.read_data_2
   MEM/WB.wb_data ─────►│ mux2_4   │   │ mux2_4   │◄── MEM/WB.wb_data
   EX/MEM.alu_result ──►│ (fwd_a)  │   │ (fwd_b)  │◄── EX/MEM.alu_result
                        └────┬─────┘   └────┬─────┘
                          w_fwd_a        w_fwd_b
                             │              │
                             │         ┌────▼──────┐  i_ALUSrc   ◄─ Fig. 4.55
                             │         │  mux1_2   │◄── i_immediate
                             │         │ (ALUSrc)  │
                             │         └────┬──────┘
                             │           w_alu_b
                             ▼              ▼
                          ┌───────────────────┐
                          │        ALU        │── o_alu_result ──► EX/MEM
                          └───────────────────┘
                                     w_fwd_b ──► o_read_data_2 ──► EX/MEM
                                     (dato de store, también forwardeado)
```

Cableado real (`ExecuteStage.sv`):

- `u_mux_fwd_a`: `i_a`=`i_read_data_1`, `i_b`=`i_wb_write_data` (MEM/WB),
  `i_c`=`i_ex_mem_alu_result` (EX/MEM), sel=`i_ForwardA`.
- `u_mux_fwd_b`: análogo con `i_read_data_2`, sel=`i_ForwardB`.
- El operando B forwardeado (`w_fwd_b`) pasa luego por el mux `ALUSrc`
  (inmediato vs. registro) y también se exporta como `o_read_data_2`, de modo que
  **los stores escriben el valor forwardeado**. Esto cubre la
  *Elaboration* de la p. 302 sobre forwarding a stores.

Fuentes de los datos (en `riscv.sv`, instancia `EX`):
- `i_ex_mem_alu_result` ← `w_ex_mem_alu_result` (buffer
  [`EX_MEM_Buffer`](../src/sources_1/Buffers/EX_MEM_Buffer.sv)).
- `i_wb_write_data` ← `w_wb_write_data`, salida del mux `MemToReg` de la etapa WB
  → es el valor MEM/WB ya resuelto (ALU **o** dato de memoria), tal como pide la
  Figura 4.53 ("data memory or an earlier ALU result").

## 6. Validación de la implementación

| Aspecto                                                  | Estado | Referencia |
|---------------------------------------------------------|:------:|-----------|
| Forwarding EX/MEM → ALU (dist 1) rs1/rs2                |  ✅   | p. 300; código líneas 24–25, 30–31 |
| Forwarding MEM/WB → ALU (dist 2) rs1/rs2                |  ✅   | p. 301; código líneas 26–27, 32–33 |
| Codificación de mux `00/10/01`                          |  ✅   | Figura 4.53 |
| Exclusión de `x0`                                       |  ✅   | p. 297 |
| Prioridad EX/MEM > MEM/WB (double hazard)               |  ✅   | p. 301; `else if` |
| Muxes `mux2_4` en operandos de la ALU                   |  ✅   | Figura 4.54; `ExecuteStage.sv` 34–55 |
| Mux ALUSrc (inmediato)                                  |  ✅   | Figura 4.55; `ExecuteStage.sv` 57–65 |
| Forwarding del dato de store (rs2)                      |  ✅   | Elaboration p. 302 |
| Instanciación/cableado en `riscv.sv`                    |  ✅   | Figura 4.58; instancia `FWD` líneas 232–243 |
| WB→ID mismo ciclo (dist 3)                              |  ✅*  | p. 297 (ver nota) |
| Testbench dedicado                                      |  ✅   | `src/sim_1/Hazard/tb_Forwarding.sv` (Test A) |

\* El hazard de distancia 3 (WB escribe mientras ID lee el mismo registro) no lo
cubre la `ForwardingUnit`. El libro lo resuelve asumiendo que el register file
**escribe en la 1.ª mitad del ciclo y lee en la 2.ª** (p. 297: *"the write is in
the first half of the clock cycle and the read is in the second half"*). Acá se
resuelve con un *write-through* combinacional en
[`RegisterFile`](../src/sources_1/ID/RegisterFile.sv).

### Conclusión

La unidad de forwarding está **implementada en su totalidad y correctamente
integrada**: la lógica del módulo coincide con §4.7 (codificación de Figura 4.53,
ecuaciones de pp. 300–301, exclusión de x0 de p. 297, prioridad del double
hazard de p. 301), los multiplexores existen en `ExecuteStage` (Figuras 4.54/4.55)
y todo está cableado en el top-level `RISCV` (Figura 4.58). Tiene testbench propio.

Ver la unidad complementaria en
[`hazard-detection-unit.md`](hazard-detection-unit.md).
