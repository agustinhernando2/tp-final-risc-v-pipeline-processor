# Reporte — Barrido de frecuencia con datapath de 32 bits (DATA_WIDTH=32) — RiscvTop (Basys-3)

**Fecha:** 2026-06-29
**Top:** `RiscvTop` (`src/sources_1/Top/RiscvTop.sv`)
**Device:** Artix-7 `xc7a35tcpg236-1` (Basys-3), speed grade **-1**
**Constraint:** `src/constrs_1/new/basys3_riscv.xdc` — entrada de 100 MHz en W5; reloj
del SoC generado por el MMCM (`MMCME2_BASE`).
**Cambio bajo prueba:** `DATA_WIDTH = 32` (datapath de 32 bits en registros, ALU y
memoria de datos, en vez de 64). `NB_PC` queda en 64 (el PC sigue siendo de 64 bits).
**Método:** mismo flujo batch que [`report-fmax-sweep-20260628.md`](report-fmax-sweep-20260628.md)
(`synth → opt → place → route → report_timing_summary` + `report_utilization`),
parcheando el MMCM por frecuencia.

> **Resumen ejecutivo:** bajar a 32 bits **reduce la lógica** (LUTs 38 %→26 %, FFs
> 15746→12316) y **arregla un bug de ancho** en el camino de JALR, pero **NO alcanza los
> 100 MHz**. El techo de timing sigue en **~75 MHz** (camino de dump posedge→negedge,
> dominado por ruteo, no por el ancho del datapath). Y el cuello de área **no es LUT/FF
> sino control sets**: a ≥70 MHz la optimización por timing replica registros, explota los
> control sets (~8000) y satura el device (~99 % de slices), volviendo el placement
> irreproducible. El **máximo confiable sube de 60 a 65 MHz** (build con la config final
> CLK=65 MHz: WNS +0.319 ns, 61 % de slices, 6 % de control sets), que se deja como nuevo
> default. Para 100 MHz haría falta atacar el camino de dump (registrarlo / re-clockear la
> DebugUnit), no el ancho de datos.

---

## 1. Resultados del barrido (DATA_WIDTH=32)

| Frecuencia | MMCM (M / O) | WNS (setup) | Control Sets | Slices | Placement | Timing |
|-----------:|:------------:|:-----------:|:------------:|:------:|:----------|:------:|
| 60 MHz | 12.0 / 20.0 | **+0.380 ns** | 499 (6 %) | 4852 (59.5 %) | ✅ holgado | ✅ |
| 65 MHz | 6.5 / 10.0 | **+0.206 ns** | 499 (6 %) | 4761 (58.4 %) | ✅ holgado | ✅ |
| 70 MHz | 7.0 / 10.0 | — | 8117 (cliff) | overflow | ❌ no coloca | — |
| 75 MHz | 7.5 / 10.0 | **+0.038 ns** | 7935 (97 %) | 8111 (99.5 %) | ⚠️ al límite (suerte) | ✅ marginal |
| 78 MHz | 7.8 / 10.0 | **−0.211 ns** | — | — | ✅ coloca | ❌ |
| 80 MHz | 8.0 / 10.0 | **−0.483 ns** | — | — | ✅ coloca | ❌ |
| 85 MHz | 8.5 / 10.0 | **−1.159 ns** | — | — | ✅ coloca | ❌ |
| 100 MHz | 10.0 / 10.0 | **−1.245 ns** | — | — | ✅ coloca | ❌ |
| 120 MHz | 12.0 / 10.0 | −2.542 ns | — | — | ✅ coloca | ❌ |
| 150 MHz | 12.0 / 8.0 | −3.703 ns | — | — | ✅ coloca | ❌ |
| 200 MHz | 12.0 / 6.0 | −5.204 ns | — | — | ✅ coloca | ❌ |

> Lectura: el timing cruza a negativo **entre 75 y 78 MHz**. El 70 MHz que no coloca, entre
> un 65 y un 75 que sí, es la **no-determinación del placer** en el borde de los control
> sets (ver §3), no una regresión de timing.
>
> Los puntos de la tabla son del barrido (CLK=60 MHz). El **build con la config final
> commiteada** (CLK=65 MHz, `build_out/RiscvTop_65MHz/`) da **WNS +0.319 ns, 61 % de slices,
> 499 control sets** — confirma que 65 MHz coloca y cierra holgado.

### Curva WNS vs frecuencia

```
WNS (ns)
 +0.4 | * (60)
      |   * (65)
 +0.2 |
      |          * (75)
  0.0 +----+----+--+-+----+----+----+----+----+----+---- f (MHz)
      |          ↑ x(78) * (80)
 -0.2 |          |  cierre de timing ~75-76 MHz
 -0.5 |              * (85)        ...    * (100) ...
      60   65   70  75   80
              [70: no coloca por control sets, no por timing]
```

---

## 2. Lo que sí mejoró: la lógica (LUTs / FFs)

Utilización de síntesis (independiente de la frecuencia):

| Recurso | DATA_WIDTH=64 | DATA_WIDTH=32 | Δ |
|---------|:-------------:|:-------------:|:--|
| Slice LUTs | 7935 (38.2 %) | **5412 (26.0 %)** | −32 % |
| Slice Registers (FF) | 15746 (37.9 %) | **12316 (29.6 %)** | −22 % |
| F7 Muxes | 2917 | 1984 | −32 % |
| F8 Muxes | 1328 | 928 | −30 % |

El datapath de 32 bits ocupa **un tercio menos de LUTs**. Esto es lo que le da aire al
placer para colocar **65 MHz**, frecuencia que con 64 bits **no ruteaba** (en el barrido
original 65 MHz pedía 8409 slices y fallaba).

### Bug de ancho corregido (JALR)

Pasar a 32 bits destapó un error latente en `MemoryAccessStage.sv`: el target de **JALR**
tomaba `i_alu_result[NB_PC-1:0]` (un slice de 64 bits) sobre un resultado de ALU de
`DATA_WIDTH` bits. Con `DATA_WIDTH = NB_PC = 64` quedaba oculto; con 32 bits da
`part-select [63:0] out of range`. Se corrigió con un cast a ancho de PC
(`NB_PC'(i_alu_result)`, zero-extend), que es correcto para ambos anchos.

---

## 3. Lo que NO mejoró: el área real la fijan los *control sets*, no las LUTs

Acá está la sorpresa. Aun con LUTs al 26 %, una corrida que **sí coloca** (75 MHz) reporta:

```
Unique Control Sets : 7935 / 8150  (97.36 %)
Slice               : 8111 / 8150  (99.52 %)   ← ¡device casi lleno!
LUT as Logic        : 5410 / 20800 (26.01 %)
```

El recurso que se agota es el **control set** (combinación única de
{clock, clock-enable, set/reset}). Cada slice aloja **un solo** control set, así que con
~7935 control sets el diseño necesita ~7935 slices **sin importar lo poco que use de LUTs**.
Por eso bajar a 32 bits no descongestionó el device a alta frecuencia.

**Por qué explotan los control sets a ≥70 MHz:** es un efecto **de la optimización por
timing**, no del diseño base. A 60/65 MHz (timing holgado) el placer empaqueta los FFs y
usa **499 control sets / ~58 % de slices**. A ≥70 MHz, para perseguir el camino crítico
(el dump posedge→negedge), `opt/place` **replica y reestructura registros**; cada réplica
con su propio enable fragmenta los control sets, que saltan de **499 a ~8000** y saturan el
device. De ahí el "cliff": 65 MHz holgado, 70 MHz no coloca, 75 MHz coloca de pura suerte
al 99.5 %.

| Frecuencia | Control Sets | Slices | Régimen |
|-----------:|:------------:|:------:|:--------|
| 60 / 65 MHz | 499 (6 %) | ~58 % | cómodo (sin replicación) |
| 70 MHz | 8117 | overflow | cliff (no coloca) |
| 75 MHz | 7935 (97 %) | 99.5 % | cliff (coloca con suerte) |

---

## 4. Comparación con los barridos previos

| | DATA_WIDTH=64 ([sweep](report-fmax-sweep-20260628.md)) | DATA_WIDTH=64 + dump 10 ([dm10](report-fmax-sweep-dm10-20260628.md)) | DATA_WIDTH=32 (este) |
|---|---|---|---|
| LUTs | 7935 (38 %) | ~7974 | **5412 (26 %)** |
| 65 MHz | ❌ no coloca (8409) | — | ✅ **+0.206 ns, 58 % slices** |
| 75 MHz | ⚠️ +0.122 (suerte) | — | ⚠️ +0.038 (suerte) |
| 100 MHz | ❌ −1.341 (build directo) | ❌ no coloca | ❌ **−1.245 ns** |
| Techo de timing | ~75 MHz | ~75 MHz | **~75 MHz** (sin cambio) |
| Cuello real | utilización (control sets) | utilización (control sets) | **igual: control sets a alta f** |
| Fmax confiable | 60 MHz | 60 MHz | **65 MHz** |

Las tres pruebas convergen en lo mismo: **el techo de timing es ~75 MHz y lo pone el camino
de dump posedge→negedge** (medio período de presupuesto, 72 % de ruteo según
[`report-20260628.md`](report-20260628.md) §2). Ni reducir el dump (dm10) ni angostar el
datapath (este) mueven ese techo, porque ninguno toca ese camino. Lo que sí logró el
datapath de 32 bits es **descongestionar lo suficiente para subir el confiable de 60 a
65 MHz**.

---

## 5. Por qué no llegamos a 100 MHz (y qué haría falta)

100 MHz exige que el camino de dump (`RegisterFile`/`DataMemory` → `msb_byte` →
`r_tx_data`) cierre en **medio período = 5 ns**, y mide ~6.4 ns. Eso es independiente de
`DATA_WIDTH` (el 72 % es ruteo) y de cuántos words dumpea. Para llegar a 100 MHz hay que
**romper ese camino**, no angostar datos:

1. **Registrar la lectura del dump** (Opción A de [`report-20260628.md`](report-20260628.md) §4):
   insertar un FF entre el core y la DebugUnit. Parte la cadena posedge→negedge en tramos de
   período completo. Latencia extra irrelevante en un dump serie a 19200 baud.
2. **Re-clockear la DebugUnit en posedge** (Opción C): elimina la penalización de medio
   período de raíz. Más riesgoso (rediseña el gating del pipeline).
3. **Memoria de datos a BRAM:** además de timing, **colapsa los control sets** (saca ~4096
   FFs con enables propios de la lógica), lo que eliminaría el "cliff" de placement y
   permitiría empujar la frecuencia sin saturar el device.

`DATA_WIDTH=32` es complementario a estas, no sustituto.

---

## 6. Decisión y cambios aplicados

- **`DATA_WIDTH = 32` queda como default** en `RiscvTop.sv` (pedido del usuario). Es además
  lo correcto para un RV32 y reduce un tercio de las LUTs.
- **Reloj del SoC: 65 MHz** (MMCM `M=6.5 / O=10`, `CLK = 65_000_000`). Es el **máximo
  confiable** medido: el build con la config final (`build_out/RiscvTop_65MHz/`) cierra con
  **WNS +0.319 ns** y coloca cómodo (61 % slices, 6 % control sets, lejos del cliff). Sube el
  operativo desde los 60 MHz previos.
- **GUI:** `tools/gui/uart.py` → `WORD_BYTES = 4` (cada registro/word de memoria del dump
  ahora son 4 bytes; el PC sigue en 8 porque `NB_PC=64`). **Imprescindible** o la GUI
  desalinea el dump.
- **Fix de timing latente:** `MemoryAccessStage.sv` (cast del target de JALR a ancho de PC).

**Fallback conservador:** 60 MHz sigue disponible (WNS +0.380 ns) si se prioriza margen; ya
estaba validado en placa.

---

## 7. Cómo reproducir

```bash
# Barrido principal (DATA_WIDTH=32 ya es default) — driver en scratchpad de la sesión:
python3 sweep_dw32.py          # 75,100,120,137.5,150,171.4,200 MHz
python3 sweep_dw32_refine.py   # 65,70,75,78,80,85 MHz (afinado del techo)

# Build/confirmación de un punto (65 MHz): RiscvTop.sv ya en M=6.5/O=10, DATA_WIDTH=32
TOP=RiscvTop SRC_GLOBS="src/sources_1/**/*.sv" XDC=src/constrs_1/new/basys3_riscv.xdc \
  OUTDIR=build_out/RiscvTop_65MHz bash .claude/skills/program-board/scripts/build.sh
```

### Referencias
- **Explicación de bajo nivel** (LUTs, replicación de registros, control sets, el "cliff"):
  [`performance-fpga-timing.md`](performance-fpga-timing.md)
- Barrido base (DATA_WIDTH=64): [`report-fmax-sweep-20260628.md`](report-fmax-sweep-20260628.md)
- Barrido con dump reducido: [`report-fmax-sweep-dm10-20260628.md`](report-fmax-sweep-dm10-20260628.md)
- Camino crítico del dump (posedge→negedge): [`report-20260628.md`](report-20260628.md)
- Fix de ancho JALR: `src/sources_1/MEM/MemoryAccessStage.sv`
- Reportes de este barrido: `build_out/sweep_dw32/<f>MHz/`, `build_out/sweep_dw32_refine/<f>MHz/`
