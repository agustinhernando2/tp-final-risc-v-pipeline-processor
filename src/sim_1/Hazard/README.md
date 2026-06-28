# Testbench `tb_Forwarding`

Archivo: [`tb_Forwarding.sv`](tb_Forwarding.sv)

Test de integración del **sistema completo** (`RISCV`, pipeline IF→ID→EX→MEM→WB)
que valida las dos unidades de riesgos de datos:
[`ForwardingUnit`](../../../docs/forwarding-unit.md) y
[`HazardDetectionUnit`](../../../docs/hazard-detection-unit.md).

**Flujo:** reset → carga el programa por la interfaz de debug
(`i_imem_wr`/`i_imem_addr`/`i_imem_data`, con `i_if_enable=0`) → ejecuta
(`i_if_enable=1`, ~30 ciclos) → verifica el banco de registros (`DUT.ID.RF.r_RF`).

## Por qué estas instrucciones

Cada instrucción depende de las anteriores **a una distancia controlada** para
disparar un camino concreto de forwarding/stall y no otro.

### Test A — RAW back-to-back (solo forwarding, sin stalls)

| # | Instrucción       | Res | Qué prueba |
|---|-------------------|-----|-----------|
| I0 | `addi x1, x0, 10` | 10 | semilla |
| I1 | `addi x2, x1, 3`  | 13 | x1 de la instr. anterior → forward **EX/MEM** (dist 1) |
| I2 | `add x3, x1, x2`  | 23 | x2 (dist 1, EX/MEM) **y** x1 (dist 2, MEM/WB) a la vez → ambos caminos en operandos distintos |
| I3 | `sub x4, x3, x1`  | 13 | x3 (dist 1, EX/MEM) + x1 ya en register file (sin forward) → que no adelante de más |

Sin NOPs entre medio: el punto es demostrar **throughput pleno** con dependencias
consecutivas.

### Test B — load-use (1 stall + forward posterior)

| # | Instrucción       | Res | Qué prueba |
|---|-------------------|-----|-----------|
| I4 | `sw x1, 0(x0)`    | MEM[0]=10 | deja un dato en memoria para el load |
| I5 | `lw x5, 0(x0)`    | 10 | carga |
| I6 | `add x6, x5, x2`  | 23 | x5 del load anterior → **load-use**: forwarding no alcanza, la `HazardDetectionUnit` mete **1 burbuja**; luego x5 llega por MEM/WB |
| I7 | `sub x7, x3, x2`  | 10 | registros viejos, **sin** dependencia → control negativo: confirma que el pipeline reanuda y no frena a instrucciones independientes |

## Correr

```bash
bash .claude/skills/run-tests/scripts/run_one.sh tb_Forwarding
```

Esperado: **7 passed, 0 failed** (4 de Test A + 3 de Test B).
