# Reporte — Barrido de frecuencia y Fmax de RiscvTop (Basys-3)

**Fecha:** 2026-06-28
**Top:** `RiscvTop` (`src/sources_1/Top/RiscvTop.sv`)
**Device:** Artix-7 `xc7a35tcpg236-1` (Basys-3), speed grade **-1**
**Constraint:** `src/constrs_1/new/basys3_riscv.xdc` — entrada de 100 MHz en W5; reloj
del SoC generado por el MMCM (`MMCME2_BASE`).
**Método:** barrido cambiando el divisor del MMCM (`CLKFBOUT_MULT_F`/`CLKOUT0_DIVIDE_F`)
con `DIVCLK_DIVIDE=1`, manteniendo el VCO en rango (600–1200 MHz). Cada punto corre
`synth_design → opt → place → route → report_timing_summary` (flujo batch, sin `.xpr`).

> **Resumen ejecutivo:** el timing del diseño **cierra hasta ~75 MHz**, pero el FPGA
> queda al **~99 % de capacidad** (8048 slices disponibles de 8150), así que cerca del
> techo el **placement es no-determinista**: 65/70/80 MHz no llegaron a rutear y 75 MHz
> sí. El **Fmax confiable es 60 MHz** (WNS +0.804 ns y placement consistente). 50 MHz
> queda como punto conservador (WNS +2.012 ns). Validado funcionalmente en placa a
> **60 MHz** (ver §4).

---

## 1. Resultados del barrido

| Frecuencia | MMCM (M / O) | VCO | WNS (setup) | TNS | Endpoints fallando | Resultado |
|-----------:|:------------:|:---:|:-----------:|:---:|:------------------:|:----------|
| 50 MHz | 10.0 / 20.0 | 1000 MHz | **+2.012 ns** | 0 | 0 / 47203 | ✅ cierra holgado |
| 55 MHz | 11.0 / 20.0 | 1100 MHz | **+0.916 ns** | 0 | 0 | ✅ cierra |
| 60 MHz | 12.0 / 20.0 | 1200 MHz | **+0.804 ns** | 0 | 0 | ✅ cierra |
| 65 MHz | 6.5 / 10.0 | 650 MHz | — | — | — | ❌ no rutea (placement) |
| 70 MHz | 7.0 / 10.0 | 700 MHz | — | — | — | ❌ no rutea (placement) |
| 75 MHz | 7.5 / 10.0 | 750 MHz | **+0.122 ns** | 0 | 0 | ⚠️ cierra al límite |
| 80 MHz | 8.0 / 10.0 | 800 MHz | — | — | — | ❌ no rutea (placement) |

> El punto de 50 MHz proviene del build completo previo (`build_out/RiscvTop/`); el resto
> del barrido `build_out/sweep/<f>MHz/timing_summary.rpt`.

### Curva WNS vs frecuencia (puntos que rutean)

```
WNS (ns)
 +2.0 |  *  (50)
 +1.5 |
 +1.0 |        *  (55)
      |           *  (60)
 +0.5 |
      |                          *  (75)
  0.0 +----+----+----+----+----+----+---- f (MHz)
      50   55   60   65   70   75   80
              [65,70,80: no rutean por area]
```

El slack **no cae linealmente** con la frecuencia: el peor camino dominante cambia entre
puntos y el ruteo varía con cada implementación, por eso 75 MHz cierra con +0.122 ns
mientras 65/70 ni siquiera encajan.

---

## 2. El verdadero cuello: utilización del device, no el WNS

Las corridas de 65, 70 y 80 MHz **no fallaron por timing** sino por **placement**:

```
ERROR: [Place 30-487] The packing of instances into the device could not be obeyed.
There are a total of 8150 slices in the device, of which 8048 slices are available,
however, the unplaced instances require 8409 slices (65 MHz) / 8130 (70) / 8086 (80).
```

El diseño ya ocupa casi todo el `xc7a35t`. Para cumplir un timing más exigente, el
optimizador físico **replica registros/lógica** (retiming, *Break lutnm for timing*),
lo que **infla la cantidad de slices** y, con el device tan lleno, **desborda la
capacidad**. Que 75 MHz haya entrado y 65/70 no es producto de la **no-determinación del
placer** cerca del 100 % de ocupación — no es reproducible.

**Por qué el diseño es tan grande:** `DATA_WIDTH = 64` en todo el datapath, más los muxes
de dump (`32:1` de 64 bits para registros, `64:1` de 64 bits para memoria de datos) y la
memoria de datos de 64×64 bits implementada en lógica (no en BRAM). Todo eso consume LUTs
a lo ancho.

---

## 3. Interpretación: ¿cuál es "el máximo"?

Hay que separar dos métricas:

| Métrica | Valor | Qué significa |
|---------|-------|---------------|
| **Fmax por timing (STA)** | ~**75 MHz** | La frecuencia más alta a la que el STA dio WNS ≥ 0 en este barrido. Pero con +0.122 ns es **marginal** y, sobre todo, **el placement a esa altura no es confiable** (65/70/80 no entraron). |
| **Fmax confiable** | **60 MHz** | Cierra con margen sano (+0.804 ns) **y** rutea de forma consistente. Es el máximo recomendable para operar. |
| **Punto conservador** | **50 MHz** | +2.012 ns de margen; el más robusto frente a variación de proceso/temperatura y a la no-determinación del placer. |

**Nota sobre "lo que aguanta la placa físicamente":** la placa podría incluso funcionar
por encima del Fmax de STA (el análisis es pesimista), pero **pasar un test funcional no
garantiza fiabilidad** — un diseño con WNS < 0 o al borde puede fallar con otra
temperatura, otro chip o tras un re-ruteo. Por eso el número que se reporta como Fmax es
el de **cierre de timing**, no el "hasta dónde anduvo".

---

## 4. Validación funcional en placa

Build completo a 60 MHz (`build_out/RiscvTop_60MHz/`): **WNS = +0.704 ns**, 0 endpoints
fallando, *"All user specified timing constraints are met"*; el *Clock Summary* muestra
`w_clk_unbuf` a **60.000 MHz** (período 16.667 ns). Bitstream generado sin errores.

Programado en la Basys-3 (`CLK = 60_000_000` → la UART sigue a 19200 baud):

- **Modo continuo:** `loadrun demo_add.hex` → **x1=5, x2=3, x3=8** ✅
- **Paso a paso** (tras reconfigurar para estado fresco): el PC avanza un word por step
  y el write-back llega con la latencia del pipeline ✅

  | step | PC | x3 |
  |-----:|----|----|
  | 1 | 0x04 | 0 |
  | 2 | 0x08 | 0 |
  | … | … | 0 |
  | 6 | 0x18 | 0 |
  | 7 | 0x1c | **8** (WB del `add`) |

> Confirma que el **máximo confiable (60 MHz) funciona en hardware real**, tanto en
> ejecución continua como en depuración paso a paso.

---

## 5. Recomendación

1. **Operar a 60 MHz** si se quiere el máximo confiable: cierra timing con margen y rutea
   consistentemente. Requiere `CLK = 60_000_000` en `RiscvTop` (para que la UART siga a
   19200) y MMCM `M=12 / O=20`.
2. **Mantener 50 MHz** si se prioriza robustez/repetibilidad (margen 2 ns, ya validado).
3. **No usar 75 MHz** en serio: aunque el STA cierra, el placement es irreproducible al
   ~99 % de ocupación; un rebuild puede no rutear.
4. **Para subir el Fmax de verdad** habría que **bajar la utilización**: mover la memoria
   de datos a BRAM, registrar/serializar los muxes de dump (Opción A del
   [`report-20260628.md`](report-20260628.md)) o reducir `DATA_WIDTH`. Eso liberaría
   slices y le daría aire al placer para frecuencias más altas.

---

## 6. Cómo reproducir

```bash
# Barrido (timing-only, sin bitstream) — script en scratchpad de la sesión:
#   parchea el MMCM por frecuencia, corre vivado y junta WNS en sweep_results.csv
python3 sweep.py     # frecuencias: 55,60,65,70,75,80

# Build completo de un punto (ej. 60 MHz): editar RiscvTop.sv (M=12,O=20,CLK=60e6) y
TOP=RiscvTop SRC_GLOBS="src/sources_1/**/*.sv" XDC=src/constrs_1/new/basys3_riscv.xdc \
  OUTDIR=build_out/RiscvTop_60MHz bash .claude/skills/program-board/scripts/build.sh
```

### Referencias
- Análisis del camino crítico (posedge→negedge del dump): [`report-20260628.md`](report-20260628.md)
- Cierre de timing y MMCM: [`../plans/stage11.md`](../plans/stage11.md)
- Reportes del barrido: `build_out/sweep/<f>MHz/timing_summary.rpt`
