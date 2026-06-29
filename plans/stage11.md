# Stage 11 — Timing & Synthesis

**Status:** DONE (validado en placa @60 MHz)

> Objetivo: cerrar timing del top de síntesis `RiscvTop` en la Basys-3 (Artix-7
> `xc7a35tcpg236-1`). El análisis del problema a 100 MHz está en
> [`docs/report-20260628.md`](../docs/report-20260628.md); este documento registra el
> **fix aplicado** (bajar la frecuencia con un MMCM) y agrega dos secciones didácticas
> (qué es el Clock Wizard y cómo correr el análisis de timing a mano en la UI de Vivado).
>
> **Frecuencia final: 60 MHz** — el máximo confiable según el barrido de frecuencias
> ([`docs/report-fmax-sweep-20260628.md`](../docs/report-fmax-sweep-20260628.md)): el
> timing aguanta hasta ~75 MHz pero el device queda al ~99% y el placement se vuelve
> irreproducible por encima de 60 MHz.

---

## Files created / modified

| File | Action |
|------|--------|
| `src/sources_1/Top/RiscvTop.sv` | Updated — MMCM `MMCME2_BASE` 100→60 MHz (M=12/O=20) + reset-bridge; `i_clk`/`i_reset` → `w_clk`/`w_rst` en uart/debug/core; `CLK` default = `60_000_000` |
| `src/constrs_1/new/basys3_riscv.xdc` | Sin cambios — `create_clock` sigue solo en `i_clk` (W5, 100 MHz); el reloj de 60 MHz es *generated clock* derivado por el MMCM |
| `docs/report-fmax-sweep-20260628.md` | Created — barrido de frecuencias 50–80 MHz, análisis de Fmax y validación en placa |
| `plans/plan.md`, `plans/stage9b.md`, `CLAUDE.md` | Updated — Stages 9b/10 validados en placa; Stage 11 cerrado @60 MHz |

---

## 1. El problema (resumen)

A 100 MHz el diseño **no cerraba timing**: WNS = **−1.341 ns**, 521/31983 endpoints
fallaban setup. El camino crítico **no es la ALU**, sino la **lectura del dump
core→DebugUnit**:

```
Source:      u_core/ID/RF/r_RF_reg[24][5]/C   (FF flanco de SUBIDA)
Destination: u_debug/r_tx_data_reg[5]/D        (FF flanco de BAJADA)
Requirement: 5.000 ns   ← medio período, no 10 ns
Data Path Delay: 6.394 ns
```

**Causa raíz:** el core corre en `posedge i_clk` y la DebugUnit en `negedge i_clk`
(intencional, para que `pipeline_enable`/`imem_wr` queden estables medio ciclo antes
del `posedge` que los muestrea — ver [`docs/DEBUG_UNIT.md §9`](../docs/DEBUG_UNIT.md)).
Un camino `rise@0 → fall@5ns` tiene solo **5 ns de presupuesto**. La cadena de dump
(mux 32:1 del register file + selector de byte) tarda 6.394 ns → viola por 1.341 ns.

## 2. El fix: MMCM 100 MHz → 60 MHz

Bajar **todo el SoC a 60 MHz**. A 60 MHz (período 16.67 ns) el medio período pasa a
**8.33 ns**, así que el camino de dump de ~6.4 ns cierra con margen (WNS +0.704 ns en el
build final) sin tocar la lógica ni la estructura `posedge/negedge`. Se eligió 60 MHz
como **máximo confiable**; a 50 MHz el margen es aún mayor (+2.012 ns). Ver el barrido
completo y por qué no se sube más en [`docs/report-fmax-sweep-20260628.md`](../docs/report-fmax-sweep-20260628.md).

### 2.1 MMCM en `RiscvTop.sv`

Se instancia el primitivo `MMCME2_BASE` directamente (no el IP Clock Wizard) para que
el flujo batch sin proyecto siga autocontenido:

```
CLKIN1_PERIOD    = 10.000   // 100 MHz de entrada (W5)
DIVCLK_DIVIDE    = 1
CLKFBOUT_MULT_F  = 12.000   // VCO = 100 * 12 / 1 = 1200 MHz  (rango -1: 600–1200 MHz)
CLKOUT0_DIVIDE_F = 20.000   // 60 MHz = 1200 / 20
```

`CLKFBOUT → BUFG → CLKFBIN` (realimentación) y `CLKOUT0 → BUFG → w_clk`. Los tres
submódulos (`Uart`, `DebugUnit`, `RISCV`) pasan a usar `w_clk`.

### 2.2 Reset-bridge

Los submódulos usan **reset síncrono**. Si el reset cayera apenas el MMCM engancha, el
primer flanco estable vería `reset=0` y los registros nunca se inicializarían. Por eso
se usa un *reset-bridge* (assert asíncrono mientras `~w_locked | i_reset`, deassert
síncrono 2 ciclos después del lock):

```systemverilog
assign w_async_rst = i_reset | ~w_locked;
always_ff @(posedge w_clk or posedge w_async_rst)
    if (w_async_rst) r_rst_sync <= 2'b11;
    else             r_rst_sync <= {r_rst_sync[0], 1'b0};
assign w_rst = r_rst_sync[1];
```

### 2.3 Baud rate de la UART

La UART deriva su divisor de la frecuencia de reloj
(`N_CONT = CLK/(BAUDRATE*OVERSAMPLE)`). Como el reloj real ahora es 60 MHz, el
parámetro `CLK` de `RiscvTop` pasa a **60_000_000**; si quedara en 100e6 el baud rate
se rompería. Verificación: `60e6/(19200*16) ≈ 195` → baud real ≈ 19231 (error ~0.16 %,
dentro de la tolerancia 8N1).

### 2.4 Constraints

`basys3_riscv.xdc` **no cambia**: `create_clock -period 10.00 [get_ports i_clk]` sigue
describiendo la entrada de 100 MHz en W5. Vivado deriva automáticamente el reloj
generado de 60 MHz a la salida del MMCM (no hay que agregar un `create_clock` manual).

---

## 3. Resultados de timing

Build batch (flujo `program-board`, sin `.xpr`):

```bash
TOP=RiscvTop \
SRC_GLOBS="src/sources_1/**/*.sv" \
XDC=src/constrs_1/new/basys3_riscv.xdc \
bash .claude/skills/program-board/scripts/build.sh
# -> build_out/RiscvTop/timing_summary.rpt
```

| Métrica | Antes (@100 MHz) | Final (@60 MHz) | Ref. (@50 MHz) |
|---------|------------------|-----------------|----------------|
| WNS (setup) | −1.341 ns ❌ | **+0.704 ns** ✅ | +2.012 ns ✅ |
| TNS | −65.490 ns | **0.000 ns** ✅ | 0.000 ns |
| Failing endpoints (setup) | 521 / 31983 | **0 / 47211** ✅ | 0 / 47203 |
| WHS (hold) | +0.034 ns | +0.022 ns ✅ | +0.029 ns |
| Medio período (captura del dump) | 5 ns | 8.33 ns | 10 ns |

> `build_out/RiscvTop/timing_summary.rpt`: *"All user specified timing constraints are
> met."* El *Clock Summary* lista `sys_clk_pin` (100 MHz de entrada) y el reloj generado
> `w_clk_unbuf` a **60.000 MHz** (período 16.667 ns). El MMCM se sintetiza como
> `MMCME2_ADV`. Bitstream: `build_out/RiscvTop/RiscvTop.bit` (0 errores, 0 critical warnings).
> El barrido completo de frecuencias está en
> [`docs/report-fmax-sweep-20260628.md`](../docs/report-fmax-sweep-20260628.md).

---

## 4. Extra A — ¿Qué es el Clock Wizard?

El **Clocking Wizard** (`clk_wiz`) es un **IP de Xilinx** que, mediante una GUI,
configura y genera un wrapper de RTL alrededor de los bloques de gestión de reloj del
FPGA — el **MMCM** (Mixed-Mode Clock Manager) o el **PLL** del Artix-7. Sirve para:

- **Sintetizar/multiplicar/dividir** relojes (de 100 MHz sacar 50, 200, 25 MHz, etc.).
- **Limpiar el jitter** y **alinear fases** (de-skew) de relojes derivados.
- Exponer una señal `locked` que indica cuándo el reloj de salida ya es estable.

**Relación con lo que hicimos:** instanciar `MMCME2_BASE` "a mano" produce
*exactamente el mismo hardware* que genera el Clock Wizard — de hecho, en el log de
síntesis Vivado transforma `MMCME2_BASE => MMCME2_ADV`, que es el mismo primitivo que
usa el IP. El wizard sólo agrega la capa GUI: calcula automáticamente
`CLKFBOUT_MULT_F` / `CLKOUT_DIVIDE` para la frecuencia pedida y valida que el **VCO**
quede en rango (600–1200 MHz en el speed grade -1).

**Cómo se usaría por GUI** (alternativa al primitivo, requiere proyecto/IP):

1. `Flow Navigator → IP Catalog → buscar "Clocking Wizard" → doble clic`.
2. Pestaña *Clocking Options*: *Primitive = MMCM*, *Input Clock = 100.000 MHz*.
3. Pestaña *Output Clocks*: habilitar `clk_out1 = 60.000 MHz`; dejar `locked` activo.
4. *Generate* → Vivado crea `clk_wiz_0` (`.xci`) con sus archivos.
5. Instanciar `clk_wiz_0` en `RiscvTop` (`.clk_in1(i_clk)`, `.clk_out1(w_clk)`,
   `.locked(w_locked)`, `.reset(i_reset)`).

**Por qué el camino batch usa el primitivo y no el IP:** el flujo de este repo es
*non-project* (no hay `.xpr` commiteado; `read_verilog` + `synth_design`). El IP del
Clock Wizard genera un `.xci` que requiere el catálogo de IP y un `synth_ip` previo;
instanciar `MMCME2_BASE` evita esa dependencia y mantiene el build reproducible con un
solo comando.

---

## 5. Extra B — Análisis de timing a mano en la UI de Vivado

Si querés inspeccionar el timing interactivamente (en vez de leer el `.rpt` del batch):

1. **Crear el proyecto:** Vivado → *Create Project* → RTL Project →
   *Add Sources* = `src/sources_1/**` (incluye `Top/`, `Debug/`, `UART/`) →
   *Add Constraints* = `src/constrs_1/new/basys3_riscv.xdc` →
   *Part* = `xc7a35tcpg236-1`. Fijar **top = `RiscvTop`**.
2. **Correr el flujo:** `Run Synthesis`, y al terminar `Run Implementation`.
3. **Abrir el diseño implementado:** `Open Implemented Design` (el timing post-rutado
   es el que vale).
4. **Reporte de timing:** menú `Reports → Timing → Report Timing Summary`
   (o en la consola Tcl: `report_timing_summary`).
5. **Leer el resumen** (panel *Timing*):
   - **Design Timing Summary:** mirar **WNS** (≥ 0 = cierra setup), **TNS**,
     **WHS** (≥ 0 = hold OK) y *Total Failing Endpoints*.
   - **Intra-Clock Paths:** slack por dominio de reloj.
   - Doble clic en un endpoint que falla, o `Report Timing`, para ver el peor camino:
     *Source / Destination*, *Requirement*, *Data Path Delay* (lógica vs ruteo),
     *Logic Levels*. Así se ve, p. ej., el cruce `posedge→negedge` con `Requirement
     = 5.000 ns`.
6. **Ver los relojes:** `Window → Clock Networks` o `report_clocks` — debería aparecer
   el reloj de **100 MHz** de entrada y el **60 MHz** *generated* del MMCM.
7. **Si WNS < 0:** identificar si es Setup (lógica lenta) o Hold; los caminos peores
   indican dónde registrar o qué bajar de frecuencia.

> Tip: el flujo batch ya escribe `build_out/RiscvTop/timing_summary.rpt` con el mismo
> contenido del *Report Timing Summary*; la UI sólo agrega navegación interactiva y el
> esquemático del camino crítico.

---

## 6. Alternativas no tomadas (por si se quiere recuperar 100 MHz)

Del análisis en `docs/report-20260628.md`, ordenadas por riesgo:

- **Opción A — registrar la lectura del dump:** insertar un FF entre la lectura del
  core y el `msb_byte` de la DebugUnit, partiendo la cadena `posedge→negedge`. Cierra a
  100 MHz; la latencia extra (1–2 ciclos) es imperceptible en un dump serie a 19200 baud.
- **Opción C — re-clockear la DebugUnit en `posedge`:** elimina el medio período pero
  obliga a rediseñar el gating del pipeline (`i_if_enable`/`o_imem_wr`) y re-verificar
  carga y paso a paso. Es el fix "de manual" pero el más riesgoso.

La Opción B (bajar la frecuencia vía MMCM, la elegida — 60 MHz) es la de menor riesgo: no
toca RTL funcional ni la relación de flancos, sólo el dominio de reloj. Para subir el Fmax
de verdad habría que **bajar la utilización** del device (mover la mem de datos a BRAM,
registrar/serializar los muxes de dump, o reducir `DATA_WIDTH`) — ver
[`docs/report-fmax-sweep-20260628.md §5`](../docs/report-fmax-sweep-20260628.md).

---

## Next: fin del plan

Stage 11 es el último stage del plan. Con timing cerrado y validado en placa a 60 MHz,
el procesador RISC-V de 5 etapas queda completo: pipeline + hazards/forwarding +
branch/jump + UART + DebugUnit (continuo y paso a paso) + cierre de timing.
