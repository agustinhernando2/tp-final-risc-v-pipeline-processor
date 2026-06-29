# Reporte — Barrido de frecuencia con dump reducido (DM_DEPTH=10) — RiscvTop (Basys-3)

**Fecha:** 2026-06-28
**Top:** `RiscvTop` (`src/sources_1/Top/RiscvTop.sv`)
**Device:** Artix-7 `xc7a35tcpg236-1` (Basys-3), speed grade **-1**
**Constraint:** `src/constrs_1/new/basys3_riscv.xdc` — entrada de 100 MHz en W5; reloj
del SoC generado por el MMCM (`MMCME2_BASE`).
**Cambio bajo prueba:** `DM_DEPTH = 10` (el dump trae **solo 10 words** de memoria de
datos en vez de 64). Resto del diseño idéntico.
**Frecuencias:** **75 MHz** (M=7.5 / O=10, VCO 750) y **100 MHz** (M=10 / O=10, VCO 1000).
**Método:** mismo flujo batch que [`report-fmax-sweep-20260628.md`](report-fmax-sweep-20260628.md)
(`synth_design → opt → place → route → report_timing_summary`), agregando
`report_utilization` tras synth para medir el área.

> **Resumen ejecutivo:** bajar el dump a 10 words **no ayuda**. Ni 75 ni 100 MHz
> llegan a colocarse: ambos **fallan en `place_design` por falta de área**, igual que
> 65/70/80 MHz en el barrido original. La razón es que `DM_DEPTH` **solo controla cuántos
> words itera la FSM del dump**, no el tamaño del hardware: la memoria de datos sigue siendo
> de 64 words (4096 FFs) y el mux de lectura del dump sigue siendo **64:1**. La utilización
> es prácticamente idéntica a la del diseño con `DM_DEPTH=64` (F8 muxes 1328 → 1312, FFs sin
> cambio). El Fmax confiable **sigue siendo 60 MHz**.

---

## 1. Resultados del barrido (DM_DEPTH=10)

| Frecuencia | MMCM (M / O) | VCO | WNS (setup) | Slices requeridos | Slices disponibles | Resultado |
|-----------:|:------------:|:---:|:-----------:|:-----------------:|:------------------:|:----------|
| 75 MHz | 7.5 / 10.0 | 750 MHz | — | **8555** | 8048 | ❌ no coloca (área) |
| 100 MHz | 10.0 / 10.0 | 1000 MHz | — | **8126** | 8048 | ❌ no coloca (área) |

Error idéntico en ambos:

```
ERROR: [Place 30-487] The packing of instances into the device could not be obeyed.
There are a total of 8150 slices in the device, of which 8048 slices are available,
however, the unplaced instances require 8555 slices (75 MHz) / 8126 (100 MHz).
ERROR: [Common 17-69] Command failed: Placer could not place all instances
```

No hay WNS porque el flujo **nunca llegó a rutear**: la implementación aborta en
`place_design`. La síntesis sí terminó (0 errores, 0 critical warnings) en los dos casos.

---

## 2. El hallazgo: `DM_DEPTH` no reduce el hardware

Se comparó la utilización de **síntesis** (independiente de la frecuencia) entre el diseño
original (`DM_DEPTH=64`) y el reducido (`DM_DEPTH=10`):

| Recurso | DM_DEPTH=64 (baseline) | DM_DEPTH=10 @75 | DM_DEPTH=10 @100 | Δ |
|---------|:---------------------:|:---------------:|:----------------:|:--|
| Slice LUTs | 7935 | 7974 | 7978 | ~igual (incluso +) |
| Slice Registers (FF) | 15746 | 15736 | 15743 | sin cambio |
| F7 Muxes | 2917 | 2904 | 2904 | −13 |
| F8 Muxes | 1328 | 1312 | 1312 | −16 |

La reducción es **despreciable**: los FFs no cambian y los muxes anchos (F7/F8) bajan
~1 %. Bajar el dump de 64 a 10 words **no achicó el datapath**.

### Por qué

`DM_DEPTH` es un parámetro de la **FSM** (`DebugUnit.sv`): controla hasta qué índice
cuenta `r_mem_idx` en el estado `SEND_MEM` (`SEND_MEM`: `r_mem_idx == DM_DEPTH-1`). Es decir,
solo afecta **cuántos words se transmiten por UART**, no el hardware que los produce:

1. **La memoria de datos sigue siendo de 64 words.** `DataMemory` se instancia con
   `NB_ADDR=6` → `r_mem[64]` de 64 bits = **4096 FFs**, los escriba el core o no. `DM_DEPTH`
   no la toca.
2. **El mux de lectura del dump sigue siendo 64:1.** `DataMemory.sv:62`
   (`assign o_dbg_data = r_mem[i_dbg_addr]`) usa `i_dbg_addr` de 6 bits → mux 64:1 de 64 bits.
   Aunque la FSM ahora solo pide direcciones 0..9, ese rango **no se propaga** a través del
   registro de dirección ni del borde del módulo, así que Vivado construye el mux completo.
   La única lógica que se ahorra es el contador `r_mem_idx` (de ahí los ~16 F8 muxes menos).

El área del SoC está dominada por `DATA_WIDTH=64` a lo ancho del datapath, la memoria de
datos 64×64 en FFs y los muxes de dump full-width — nada de eso depende de `DM_DEPTH`.

---

## 3. Comparación con el barrido original (`report-fmax-sweep-20260628.md`)

| | Barrido original (DM_DEPTH=64) | Este barrido (DM_DEPTH=10) |
|---|---|---|
| 75 MHz | ⚠️ cierra al límite (WNS +0.122 ns) | ❌ no coloca (8555 slices) |
| 100 MHz | no probado en el barrido (el build directo daba WNS −1.341 ns, ver [`report-20260628.md`](report-20260628.md)) | ❌ no coloca (8126 slices) |
| 65 / 70 / 80 MHz | ❌ no rutean (8409 / 8130 / 8086 slices) | — |
| Cuello de botella | **utilización del device (~99 %)** | **igual: utilización del device** |
| Slices requeridos | 8086–8409 | 8126–8555 |

Los "slices requeridos" del placer son del **mismo orden** con DM=10 que con DM=64
(8126–8555 vs 8086–8409). Es más, 75 MHz con DM=10 pide **8555** — *más* que cualquier
punto del barrido original. Esto es consistente con dos cosas: (a) reducir el dump no liberó
área, y (b) el placer es **no-determinista** cerca del 100 % de ocupación, así que la cifra
exacta de "slices requeridos" varía entre corridas (replicación/retiming timing-driven) sin
que el diseño base haya cambiado de tamaño.

> **Conclusión de la comparación:** el experimento confirma la tesis del reporte original
> ([`report-fmax-sweep-20260628.md`](report-fmax-sweep-20260628.md) §2): **el cuello no es
> el WNS sino la utilización del device.** Tocar `DM_DEPTH` no mueve esa aguja porque no
> reduce el hardware. Para subir el Fmax hay que **bajar la utilización de verdad** (mover la
> memoria de datos a BRAM, o reducir `DATA_WIDTH` / `NB_DADDR`), no la cantidad de words que
> el dump transmite.

---

## 4. Qué *sí* habría que reducir

Si el objetivo es achicar el datapath de dump para que el device coloque a frecuencias más
altas, hay que atacar el **hardware**, no el contador:

1. **Mover la memoria de datos a BRAM** (`(* ram_style="block" *)` o un macro BRAM): saca
   ~4096 FFs + el mux 64:1 de la lógica. Es el lever de mayor impacto (Opción del
   [`report-20260628.md`](report-20260628.md) §4).
2. **Reducir `NB_DADDR`** (p. ej. de 6 → 4 = 16 words): achica el array *y* el mux de dump
   a 16:1. Esto sí reduce hardware, a costa de menos memoria de datos.
3. **Reducir `DATA_WIDTH`** (64 → 32): mitad de FFs y muxes en todo el datapath.
4. **Registrar/serializar la lectura del dump** (Opción A del `report-20260628.md`): ataca el
   timing del cruce posedge→negedge, no el área — complementario.

`DM_DEPTH=10` por sí solo no logra nada de esto: el diseño quedó del mismo tamaño.

---

## 5. Recomendación

1. **Mantener 60 MHz** como Fmax confiable (sin cambios): el barrido original ya lo validó
   en placa (WNS +0.704 ns, ver [`report-fmax-sweep-20260628.md`](report-fmax-sweep-20260628.md) §4).
2. **No esperar mejora de timing/área bajando `DM_DEPTH`**: este reporte muestra que es un
   parámetro de protocolo (cuántos words manda la UART), no de tamaño del hardware.
3. **Para subir el Fmax**: aplicar §4.1 (BRAM) o §4.2 (`NB_DADDR`), que sí liberan slices y
   le dan aire al placer.

---

## 6. Cómo reproducir

```bash
# Barrido con DM_DEPTH=10 (timing+util, sin bitstream) — driver en scratchpad de la sesión:
#   parchea DM_DEPTH=10 y el MMCM por frecuencia, corre Vivado y junta WNS/util.
python3 sweep_dm10.py     # frecuencias: 75, 100 MHz

# Baseline de utilización con DM_DEPTH=64 (synth-only):
vivado -mode batch -source synth_only.tcl   # report_utilization sobre RiscvTop
```

### Referencias
- Barrido original (DM_DEPTH=64) y tesis de utilización: [`report-fmax-sweep-20260628.md`](report-fmax-sweep-20260628.md)
- Camino crítico del dump (posedge→negedge): [`report-20260628.md`](report-20260628.md)
- Memoria de datos (array + mux 64:1 de dump): `src/sources_1/MEM/DataMemory.sv:20,62`
- FSM del dump (`DM_DEPTH` solo controla la iteración): `src/sources_1/Debug/DebugUnit.sv:39,330-348`
- Reportes de este barrido: `build_out/sweep_dm10/<f>MHz/` (logs de place-fail + `util_synth.rpt`)
