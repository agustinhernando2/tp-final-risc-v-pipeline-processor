# Consideraciones de diseño

Registro breve de decisiones de arquitectura no obvias.

---

## C-001 — PC byte-addressed (`PC + 4`) en lugar de word-addressed (`PC + 1`)

**Fecha:** 2026-06-13
**Estado:** resuelto / implementado
**Etapas afectadas:** IF (`InstructionFetch`, `InstructionMemory`), EX (`ExecuteStage`)

### Discusión

El diseño original usaba un **PC word-addressed**: incrementaba de a 1, la
`InstructionMemory` indexaba el array de palabras directo con el PC, y el branch
target convertía el offset de bytes a palabras con `>>> 2`:

```systemverilog
// IF: PC + 1
// branch_target = PC + (sign_ext(imm) >>> 2)
```

El libro de referencia (Patterson & Hennessy, *RISC-V edition*, §4.3, Fig. 4.9)
usa un **PC byte-addressed**: el PC cuenta bytes (`PC + 4`) y el branch target se
calcula como `PC + (imm << 1)`. El `<< 1` ("Shift left 1") **no es hardware**: es
puro cableado que apenda un `0` al bit menos significativo del offset, porque el
inmediato B-type guarda solo `imm[12:1]` (offset en half-words).

La pregunta fue: ¿por qué el libro hace `<< 1` y el desarrollo hacía `>>> 2`?

- **`<< 1` (libro):** convierte el inmediato de *half-words → bytes*, porque su PC
  cuenta bytes.
- **`>>> 2` (diseño original):** convertía el byte offset (que `ImmediateExtend`
  ya produce, gracias al `1'b0` que apenda en el LSB del B/J-type) de
  *bytes → palabras*, porque el PC contaba palabras.

Es decir, el `ImmediateExtend` ya hacía el `<< 1` del libro internamente, y luego
el `>>> 2` lo dividía de nuevo: una doble conversión redundante, y una convención
distinta a la del libro.

### Decisión

Alinear con el libro: **PC byte-addressed, incremento de a 4**. Cambios:

1. `InstructionFetch.sv` — el sumador del PC suma `4` (antes `1`).
2. `InstructionMemory.sv` — el fetch indexa con `PC >> 2`
   (`i_PC[NB_ADDR+1:2]`); el puerto de carga por debug sigue usando índice de
   palabra.
3. `ExecuteStage.sv` — se **elimina** el `>>> 2`: el inmediato ya es un byte
   offset y el PC está en bytes, así que `branch_target = PC + imm` directo.
   (Reemplazar por `<< 1` habría sido **incorrecto**: duplicaría el offset, porque
   el `ImmediateExtend` ya incluye el `<< 1` del libro.)
4. La señal `pc_plus_1` se renombró a `pc_plus_4` en todo el pipeline (la
   dirección de retorno de JAL/JALR pasa a ser `PC + 4`, generada por el sumador
   de IF; no hace falta un sumador aparte).

### Resultado

- Suite de tests: **117 passed, 10 failed**. Los 10 fallos son el bug conocido
  preexistente [BUG-001 (LUI)](known-bugs.md), no relacionado con este cambio.
- `tb_branch` (BNE loop + JAL): 6/6 ✓ — la dirección de retorno de JAL pasó de
  `x1 == 1` a `x1 == 4`, como corresponde al modelo byte-addressed.
- `tb_IF_to_WB`: 6/6 ✓.
- Beneficio adicional: JALR con offset no nulo ahora funciona (antes era una
  limitación del diseño word-addressed; ver [`plans/stage8.md`](../plans/stage8.md)).

### Fuera de alcance

- **`DataMemory`** (LW/SW/LH/SH) sigue siendo **word-addressed**. Es un eje de
  direccionamiento independiente del PC y no se modificó en este cambio. Queda
  como deuda conocida si se busca consistencia byte-addressed end-to-end.
