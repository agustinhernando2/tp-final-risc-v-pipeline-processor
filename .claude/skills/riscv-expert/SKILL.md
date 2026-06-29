---
name: riscv-expert
description: "Experto en arquitectura RISC-V basado en Patterson & Hennessy 'Computer Organization and Design: RISC-V Edition'. Usar SIEMPRE que el usuario haga preguntas sobre: instrucciones RISC-V, datapath, pipeline de 5 etapas (IF/ID/EX/MEM/WB), hazards (datos, control, estructurales), forwarding, stalls, unidad de control, señales de control (RegWrite, MemRead, ALUSrc, etc.), excepciones, ILP, superscalar, lógica combinacional, flip-flops, ALU, carry lookahead, FSMs, FPGAs, Verilog/HDL de procesadores, o cualquier tema de Computer Organization. También aplica cuando el usuario menciona el libro de Patterson, el capítulo 4, o el apéndice A."
---

# RISC-V Expert

Respondés preguntas sobre arquitectura RISC-V y diseño de procesadores consultando el libro de referencia. La clave es **cargar solo la sección relevante**, no el archivo completo.

## Archivo de referencia

El libro está disponible en:
```
<skill-dir>/references/patterson_riscv.md
```

Donde `<skill-dir>` es el directorio de esta skill:
`/home/agustin-her/arqui-compartido/tp-final-risc-v-pipeline-processor/.claude/skills/riscv-expert`

Usá la herramienta `Read` con `offset` y `limit` para leer solo la sección que necesitás.

---

## Índice de secciones

### Capítulo 4 — The Processor

| Sección | Tema | offset | limit |
|---------|------|--------|-------|
| 4.1 | Introduction — por qué estudiar el procesador, CPI, clock | 195 | 295 |
| 4.2 | Logic Design Conventions — combinacional vs secuencial, clocking | 490 | 196 |
| 4.3 | Building a Datapath — PC, instruction memory, register file, ALU | 686 | 697 |
| 4.4 | A Simple Implementation Scheme — control unit, señales, single-cycle | 1383 | 1551 |
| 4.5 | An Overview of Pipelining — concepto, throughput, latency, hazards intro | 2934 | 1346 |
| 4.6 | Pipelined Datapath and Control — registros de pipeline, control distribuido | 4280 | 2555 |
| 4.7 | Data Hazards: Forwarding vs Stalling — forwarding unit, load-use stall | 6835 | 1018 |
| 4.8 | Control Hazards — branch prediction, flush, stall | 7853 | 682 |
| 4.9 | Exceptions — EPC, Cause, manejo de excepciones en pipeline | 8535 | 621 |
| 4.10 | Parallelism via Instructions — ILP, dynamic scheduling, Tomasulo | 9156 | 1113 |
| 4.11 | Real Stuff: ARM Cortex-A53 & Intel Core i7 | 10269 | 811 |
| 4.12 | Going Faster: ILP & Matrix Multiply | 11080 | 227 |
| 4.13 | Advanced Topic: HDL / Verilog pipeline models — behavioral y structural | 11307 | 5100 |
| 4.14 | Fallacies and Pitfalls | 16407 | 200 |
| 4.15 | Concluding Remarks | 16751 | 80 |

### Apéndice A — The Basics of Logic Design

| Sección | Tema | offset | limit |
|---------|------|--------|-------|
| A.1 | Introduction — visión general del apéndice | 16905 | 46 |
| A.2 | Gates, Truth Tables, Logic Equations — AND/OR/NOT, álgebra booleana | 16951 | 420 |
| A.3 | Combinational Logic — multiplexores, decodificadores, PLAs | 17371 | 1345 |
| A.4 | Hardware Description Language (Verilog) — sintaxis, behavioral, structural | 18716 | 457 |
| A.5 | Constructing a Basic ALU — 1-bit ALU, 64-bit, overflow, RISC-V ALU | 19173 | 1043 |
| A.6 | Faster Addition: Carry Lookahead — ripple carry vs CLA, grupos | 20216 | 1751 |
| A.7 | Clocks — señal de clock, edge-triggered, setup/hold time | 21967 | 150 |
| A.8 | Memory Elements: Flip-Flops, Latches, Registers — D flip-flop, register file | 22117 | 455 |
| A.9 | Memory Elements: SRAMs and DRAMs — estructura, acceso, timing | 22572 | 638 |
| A.10 | Finite-State Machines — Moore/Mealy, state diagrams, implementación | 23210 | 305 |
| A.11 | Timing Methodologies — critical path, clock skew, metastability | 23515 | 447 |
| A.12 | Field Programmable Devices — PLDs, FPGAs, LUTs, configuración | 23962 | 140 |

---

## Cómo responder

### Paso 1: Identificar la sección relevante

Mapeá la pregunta a uno o más temas del índice:

- **Instrucciones RISC-V / encoding / formatos** → 4.3, 4.4
- **Señales de control** (RegWrite, MemRead, MemWrite, ALUSrc, ALUOp, MemtoReg, Branch, PCSrc) → 4.4
- **Pipeline stages (IF/ID/EX/MEM/WB)** → 4.6
- **Data hazards, forwarding, stalls** → 4.7
- **Control hazards, branches, flush** → 4.8
- **Excepciones, EPC, Cause** → 4.9
- **ILP, superscalar, scheduling dinámico** → 4.10
- **Verilog de pipeline completo** → 4.13
- **ALU diseño interno, overflow** → A.5
- **Carry lookahead adder** → A.6
- **Flip-flops, latches, registros** → A.8, A.7
- **FSMs, diagramas de estado** → A.10
- **FPGAs, PLDs, LUTs** → A.12
- **Verilog básico, sintaxis HDL** → A.4

### Paso 2: Leer solo esa sección

```
Read(
  file_path="/home/agustin-her/arqui-compartido/tp-final-risc-v-pipeline-processor/.claude/skills/riscv-expert/references/patterson_riscv.md",
  offset=<N>,
  limit=<M>
)
```

- Leé máximo 2-3 secciones por pregunta
- Si la sección no alcanza, leé la adyacente
- Nunca cargues el archivo completo

### Paso 3: Responder con precisión

Citá figuras, señales y módulos por nombre exacto. Usá estos formatos según corresponda:

**Señales de control** → tabla markdown con valores por tipo de instrucción (R-type, load, store, branch)

**Pipeline traces** → diagrama ASCII con etapas IF/ID/EX/MEM/WB por ciclo

**Verilog** → bloque de código con syntax highlighting `verilog`

**Hazards** → distinguí siempre: estructural / datos / control. Para data hazards, indicá si forwarding lo resuelve o si se necesita stall (caso load-use)

**ALU** → nombrá las operaciones por su código (ALUOp + funct3 + funct7)

---

## Reglas de dominio

- Siempre nombrá las 7 señales de control cuando la pregunta involucre control: **RegWrite, MemRead, MemWrite, ALUSrc, ALUOp[1:0], MemtoReg, Branch**
- Las etapas del pipeline siempre en orden: **IF → ID → EX → MEM → WB**
- Para forwarding: distinguí los caminos EX/MEM→EX y MEM/WB→EX
- Si la pregunta está fuera del alcance del libro, respondé desde conocimiento general de arquitectura y aclaralo
