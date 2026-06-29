# Stage 9b — Debug Unit + integración UART + GUI Python (RISC-V)

**Status:** DONE (HDL + sim + validado en placa)

---

## Files created / modified

| File | Action |
|------|--------|
| `src/sources_1/Debug/DebugUnit.sv` | Created — FSM de control (carga IM, continuo/paso a paso, dump 64-bit) |
| `src/sources_1/Top/RiscvTop.sv` | Created — SoC: Uart + DebugUnit + RISCV core (top de síntesis) |
| `src/constrs_1/new/basys3_riscv.xdc` | Created — pines Basys-3 (W5/B18/A18/U18/LEDs) |
| `src/sim_1/Debug/tb_DebugUnit.sv` | Created — TB de la FSM (carga + dump, sin UART real) |
| `src/sim_1/Debug/tb_RiscvDebug.sv` | Created — TB de integración DebugUnit+core (carga→run→HALT→dump) |
| `tools/gui/uart.py` | Created — capa serie + protocolo (packing programa, parse dump 64-bit) |
| `tools/gui/riscv_debug.py` | Created — CLI: load / run / info / step / loadrun |
| `tools/gui/programs/demo_add.hex` | Created — programa de ejemplo (x3=x1+x2, HALT) |
| `src/sources_1/ID/ControlUnit.sv` | Updated — `o_Halt`; decodifica HALT (opcode `0001011`) |
| `src/sources_1/ID/InstructionDecode.sv` | Updated — expone `o_Halt`; puerto debug del RegisterFile |
| `src/sources_1/ID/RegisterFile.sv` | Updated — 3er puerto de lectura (debug) |
| `src/sources_1/MEM/DataMemory.sv`, `MemoryAccessStage.sv` | Updated — puerto de lectura debug |
| `src/sources_1/Buffers/{ID_EX,EX_MEM,MEM_WB}_Buffer.sv` | Updated — bit `Halt` por el pipeline |
| `src/sources_1/Top/riscv.sv` | Updated — `i_if_enable` como enable global; HALT→`o_halt`; puertos debug `o_PC`/reg/mem |
| `src/sim_1/{Integrador/tb_IF_to_WB,Integrador/tb_branch,Hazard/tb_Forwarding}.sv` | Updated — nuevo port list de `RISCV` |

---

## Design notes

- **HALT:** opcode custom-0 `7'b0001011` (instrucción `0x0000000B`). La `ControlUnit`
  lo decodifica a `o_Halt` (sin escribir nada). El bit viaja por los buffers; `o_halt`
  se asierta cuando HALT llega a **WB** (no a MEM): así la última instrucción real
  antes de HALT completa su write-back antes de que la DebugUnit congele el pipeline.
  Las instrucciones posteriores a HALT son NOPs (la GUI rellena con `0x00000000` y la
  IM arranca en cero), así que el pipeline queda efectivamente vacío.
- **Enable global:** se reutiliza `i_if_enable` del core como habilitación maestra:
  gatea PC, los 4 buffers, la escritura del banco de registros y de la memoria de
  datos. Con `i_if_enable=1` el comportamiento es idéntico al anterior (los tests de
  integración siguen pasando). La DebugUnit lo baja para carga/paso/HALT.
- **Protocolo (MSB-first):** comandos 1..5; carga = 64 instrucciones × 4 bytes; dump =
  PC (8B) → 32 regs × 8B → 64 words de mem × 8B = 776 bytes. Dump de 64 bits (fiel al
  datapath); instrucciones de 32 bits.
- **Temporización:** la FSM corre en flanco descendente (patrón del MIPS de base) para
  que los enables/`o_imem_wr` estén estables en el flanco de subida del pipeline.
- **Carga de IM:** la DebugUnit ensambla 4 bytes MSB-first en un word de 32 bits y lo
  escribe por el puerto `i_imem_wr/addr/data` del core (word-indexed).

---

## Test results (simulación)

Suite completa vía `run-tests`: **129 passed, 0 failed**. Tests relevantes a 9b:

- `tb_DebugUnit` — 49 chequeos: ensamblado de IM (words/direcciones), secuencia de
  bytes del dump (PC/regs/mem MSB-first), disparo del dump por HALT.
- `tb_RiscvDebug` — integración DebugUnit+core sin UART: carga `addi x1,5; addi x2,3;
  add x3,x1,x2; halt`, ejecución continua, y verifica desde el dump x1=5, x2=3, **x3=8**,
  x0=0. Valida el camino completo carga→run→HALT→dump y el timing de freeze.
- Sin regresiones en pipeline (`tb_IF_to_WB`, `tb_branch`, `tb_Forwarding`, etc.).

---

## Running the tests

```bash
bash .claude/skills/run-tests/scripts/run_one.sh tb_DebugUnit
bash .claude/skills/run-tests/scripts/run_one.sh tb_RiscvDebug
bash .claude/skills/run-tests/scripts/run_tests.sh   # suite completa
```

## Validación en placa (OK)

Validado en la Basys-3 (top `RiscvTop`, bitstream del flujo batch `program-board`):

1. `python tools/gui/riscv_debug.py --port /dev/ttyUSBx loadrun tools/gui/programs/demo_add.hex`
   → imprime **x1=5, x2=3, x3=8** (camino completo carga→run→HALT→dump).
2. `... info` / `... step` vuelcan estado y avanzan ciclo a ciclo (modo paso a paso,
   Stage 10). Los LEDs muestran el estado one-hot de la DebugUnit.

> Esto cierra también **Stage 10** (operating modes): el modo continuo y el paso a paso
> funcionan en hardware real.

> **Nota de timing (Stage 11):** la validación inicial se hizo con el bitstream a 100 MHz,
> que **no cierra timing** (ver `docs/report-20260628.md`). El fix definitivo baja el SoC
> a 60 MHz vía MMCM en `RiscvTop.sv`; ver [`plans/stage11.md`](stage11.md).

---

## Next: Stage 11 — Timing & síntesis

Correr síntesis+implementación de `RiscvTop`, revisar el camino crítico (probablemente
ALU/mem→forwarding o el banco de registros), y fijar frecuencia objetivo ~50–100 MHz.
