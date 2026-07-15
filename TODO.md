# ToDo

## Pendientes

- [x] Actualizar el [drawio](https://app.diagrams.net/#G1rPXbd46hBu4peEcoeF44U_wG0EooTBuv#%7B%22pageId%22%3A%22rqNhQ4T9WLc7g1J5UKfi%22%7D): terminar los stages y conexiones sin complejidades
- [x] Entender cada test hecho
- [x] Entender test de integracion
- [x] Actualizar diagrama con Branch y Jump signals
- [x] Leer unidad de forwarding
- [x] Leer hazard detection
- [x] Actualizar diagramas Forwardin y Hazard detection
- [x] Ver si se necesita la instruccion Jump y donde la trata el libro
- [x] Correr y entender el test de integración
- [x] Corregir instruccion LUI
- [x] Revisar JAL y Branch instructions si estan funcionando bien
IA: 'Un detalle aparte mientras mirás esto: ese sumador calcula siempre PC + imm. Para JALR el target correcto es rs1 + imm, no PC + imm' REV: el sumador solamente es para JAL, BEQ y BENQ
- [x] Validar que esten todas las instrucciones implementadas y que no hallan de mas
- [x] Estudiar la unidad de detección de riesgos y forwarding
- [x] Agregarle y probar UART
- [x] Entender codigo y diagramar UART
- [x] Agregar Debug unit y probarla
- [x] Entender codigo y diagramar DebugUnit
- [x] Entender como funciona el HALT
- [x] Correr pruebas a mano
- [x] Revisar todo el repo y documentar
- [x] Entender scripts de python
- [x] Armar informe PDF 

## Preguntas para responder

- ¿Por qué están los NOP y cómo funcionan?
- En esta instancia, ¿por qué hacen falta el módulo de detección de riesgos y el de forwarding?
- ¿Qué instrucciones quedan pendientes?
- Notas sobre jump

```md
El libro (sección 4.8) **no cubre JAL/JALR explícitamente** — solo habla de branches condicionales (`beq`/`bne`). El manejo de `i_Jump` en el buffer ID/EX es una extensión que implementaron ustedes para soportar saltos incondicionales, y la justificación viene de razonar sobre el ISA de RISC-V:

- **JAL**: escribe `PC+4` en `rd` → EX necesita saber que es un jump para generar ese valor en lugar del resultado ALU normal.
- **JALR**: igual que JAL pero el target es `rs1 + imm` → también necesita distinción en EX.

El libro menciona el concepto de **link register** brevemente en la sección 4.3/4.4 al describir el formato J-type, pero el manejo pipeline de JAL/JALR queda como ejercicio. La señal `i_Jump` en el buffer es una decisión de diseño propia, no algo que P&H detalle paso a paso.

```
- Notas sobre MEM
```md
El libro simplifica: solo cubre `ld`/`sd` (doubleword, 64 bits) y omite `lb`, `lh`, `lw`, `lbu`, `lhu`, etc.

La tabla `000=byte, 001=halfword, 010=word, 100=byte unsigned...` viene directamente del **RISC-V ISA Specification** (Volume I, User-Level ISA), en la sección de instrucciones de load:

| funct3 | Instrucción | Significado             |
| ------ | ----------- | ----------------------- |
| `000`  | LB          | byte, sign-extended     |
| `001`  | LH          | halfword, sign-extended |
| `010`  | LW          | word, sign-extended     |
| `100`  | LBU         | byte, zero-extended     |
| `101`  | LHU         | halfword, zero-extended |
| `110`  | LWU         | word, zero-extended     |

Para stores (`funct3` `000`=SB, `001`=SH, `010`=SW), el bit de signo no aplica porque solo se escribe, no se extiende.
```

## Notas sobre los controles temporales en el testbench

- `@(posedge i_clk)` / `@(negedge i_clk)` = *event control*: bloquea la task hasta ese flanco. No consume tiempo por sí mismo, solo espera el evento.
- `#1` = *delay control*: avanza 1 unidad de tiempo (1 ns con `timescale 1ns/1ps`). Se usa después del flanco para muestrear/cambiar señales ya asentadas y evitar condiciones de carrera con los flip-flops del DUT.
- `task tick;`: `@(posedge)` + `#1` → "avanzá hasta justo después del próximo flanco de subida"; cada llamada hace avanzar la sim un ciclo.
- `task load_instr(...)`: secuencia temporal:
  1. `@(negedge i_clk)` → se preparan `i_mem_wr=1`, `addr`, `data` en el flanco de **bajada** (lejos del flanco de captura → da margen de setup durante el semiciclo en bajo).
  2. `@(posedge i_clk)` → la memoria síncrona **captura** el dato en el flanco de **subida**.
  3. `#1` y luego `i_mem_wr=0` → baja el enable 1 ns después del posedge para no reescribir.

```
          negedge              posedge        +1ns
            │                     │             │
            ▼                     ▼             ▼
────────────┐                     ┌───────────────────
            └─────────────────────┘  (i_clk)
            │                     │
            │ wr=1, addr, data    │ memoria captura     wr=0
            │ (preparados)        │ el dato aquí
            └──── setup margin ───┘
```
