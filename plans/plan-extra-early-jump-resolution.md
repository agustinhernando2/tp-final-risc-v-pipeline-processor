# Plan Extra — Early Jump Resolution (resolver JAL/branch en ID)

**Status:** FUERA DE SCOPE (mejora opcional, no requerida por el TP)

> Esta optimización **no es parte del trabajo práctico**. El TP queda
> completo con el esquema de Stage 8 (assume-not-taken + flush, resolución
> en EX/MEM, penalidad de 2 burbujas). Este documento queda como referencia
> de cómo se podría mejorar el rendimiento de los saltos si se quisiera ir
> más allá del alcance pedido.

---

## Motivación

Hoy (Stage 8) los saltos se resuelven con los valores del **EX/MEM buffer**
(arranque de la etapa MEM). Eso paga **2 burbujas en cada salto tomado**,
incluido **todo JAL/JALR** (que son incondicionales y siempre se toman).

El libro de Patterson & Hennessy llama a esto el esquema **no optimizado**
(Figure 4.59) y describe explícitamente cómo mejorarlo.

### Referencia en el libro

**§4.8 "Control Hazards" — sub-apartado "Reducing the Delay of Branches"
(pp. 309-310):**

> *"if we move the conditional branch execution earlier in the pipeline,
> then fewer instructions need be flushed. Moving the branch decision up
> requires two actions to occur earlier: computing the branch target address
> and evaluating the branch decision. The easy part of this change is to move
> up the branch address calculation. We already have the PC value and the
> immediate field in the IF/ID pipeline register, so we just move the branch
> adder from the EX stage to the ID stage."*

Resultado (Figure 4.60):

> *"moving the conditional branch execution to the ID stage … reduces the
> penalty of a branch to only one instruction if the branch is taken, namely,
> the one currently being fetched."*

Mecanismo de descarte (p. 310):

> *"we add a control line, called **IF.Flush**, that zeros the instruction
> field of the IF/ID pipeline register. Clearing the register transforms the
> fetched instruction into a nop."*

---

## Por qué JAL es el caso más barato

El libro distingue dos partes al mover la resolución a ID:

1. **"The easy part"** — calcular el target (`PC + imm`). Ambos operandos ya
   están en el IF/ID buffer, así que es solo mover el sumador de EX a ID.
2. **"The harder part"** — evaluar la *decisión* del branch (comparador en ID
   para BEQ/BNE) + el forwarding/stall asociado (los "complicating factors"
   #1 y #2 de la p. 309).

**JAL es incondicional**: no hay decisión que evaluar ni operandos que
comparar. Solo queda "the easy part". Por eso, de las tres variantes, JAL es
la que se implementa con menos riesgo y mayor relación beneficio/esfuerzo:

| Instrucción | Resolver en ID requiere | Penalidad actual → optimizada |
|-------------|-------------------------|-------------------------------|
| **JAL**  | Solo adder `PC + imm` en ID. Sin dependencias. | 2 → **1** |
| **JALR** | Adder `rs1 + imm`; **necesita rs1** → forwarding hacia ID o stall (complicating factor #2). | 2 → 1 (con HW extra) |
| **BEQ/BNE** | Comparador (`=`) en ID + forwarding/stall de operandos (the "harder part"). | 2 → 1 (con HW extra) |

> Nota: no se puede llegar a **0** burbujas en este pipeline de 5 etapas sin
> predicción/predecode en IF — siempre hay al menos 1 instrucción ya buscada
> en IF antes de saber que la instrucción era un salto. El mínimo realista es
> 1 burbuja (la del libro, Figure 4.60).

---

## Alcance propuesto (si se hiciera)

Recomendación: implementar **solo JAL** (el caso limpio). BEQ/BNE/JALR quedan
como extensión posterior porque arrastran comparador + forwarding/stall hacia
ID.

### Cambios de hardware

| Archivo | Cambio |
|---------|--------|
| `src/sources_1/Top/riscv.sv` | Adder `PC + imm` en ID usando `w_if_id_pc` + `w_id_immediate`; nuevo `w_PCSrc_id` levantado cuando `w_id_Jump & ~w_id_JumpReg`; redirige PC y activa `IF.Flush` de **solo el IF/ID buffer** (1 burbuja). |
| `src/sources_1/IF/InstructionFetch.sv` | Aceptar el redirect temprano de PC (mux de origen de PC ya existe vía `i_PCSrc`/`i_PCBranch`; sumar el origen "ID"). |
| `src/sources_1/Buffers/IF_ID_Buffer.sv` | Ya tiene `i_flush`; reutilizarlo para el `IF.Flush` del JAL temprano. |
| `MemoryAccessStage` / EX/MEM path | JAL deja de generar `PCSrc` desde MEM (se saca del camino tardío); MEM sigue resolviendo BEQ/BNE/JALR mientras no se opticen. |

### Esquema de tiempos objetivo

```
       c1    c2                       c3
JAL    IF    ID (redirige PC + IF.Flush)
w#1          IF  ← única instrucción flusheada (1 burbuja)
target             IF
```

Versus el actual (Stage 8, resolución en EX/MEM):

```
       c1    c2    c3    c4
JAL    IF    ID    EX    MEM/EX-MEM (resuelve)
w#1          IF    ID    (flush)
w#2                IF    (flush)   ← 2 burbujas
```

### Coexistencia con Stage 8

Mientras BEQ/BNE/JALR sigan resolviéndose tarde, hay **dos fuentes de
redirect de PC**: la temprana (ID, solo JAL) y la tardía (EX/MEM, el resto).
Hay que darle prioridad bien definida al mux de origen del PC y asegurar que
los flush no se pisen. El path tardío de Stage 8 queda intacto para todo lo
que no sea JAL.

---

## Verificación sugerida

- Reusar / extender `src/sim_1/Integrador/tb_branch.sv`.
- Test de JAL contando ciclos: confirmar que entre el JAL y la instrucción
  destino se ejecuta **1 sola** NOP (no 2). Comparar el conteo de ciclos
  contra el baseline de Stage 8.
- Regresión: BEQ/BNE/JALR deben seguir pasando sin cambios (siguen por el
  path tardío).

---

## Conclusión

Implementable y bien fundamentado en §4.8 del libro, pero **excede el alcance
del TP**. Stage 8 ya cumple el requisito funcional (ejecuta todo el control de
flujo RV32I correctamente). Esta optimización es estrictamente de rendimiento
(2 → 1 burbuja por salto) y se deja documentada como mejora futura.
