# Performance y bajo nivel: LUTs, control sets y cierre de timing en FPGA

Este documento explica, de menor a mayor nivel, **por qué este procesador no cierra
timing a 100 MHz** y por qué el techo práctico está en ~65 MHz, en términos del hardware
real del FPGA (no del RTL). Es el "por qué físico" detrás de los reportes de barrido de
frecuencia.

1. [El sustrato físico: LUT, FF y slice](#1-el-sustrato-físico-lut-ff-y-slice)
2. [Análisis de timing estático (STA) y el slack](#2-análisis-de-timing-estático-sta-y-el-slack)
3. [El camino crítico: el dump y el cruce posedge→negedge](#3-el-camino-crítico-el-dump-y-el-cruce-posedgenegedge)
4. [Optimización dirigida por timing: replicación de registros](#4-optimización-dirigida-por-timing-replicación-de-registros)
5. [Control sets: por qué el cuello no son los LUTs](#5-control-sets-por-qué-el-cuello-no-son-los-luts)
6. [El "cliff": cómo se encadena todo](#6-el-cliff-cómo-se-encadena-todo)
7. [Qué movería el techo de verdad](#7-qué-movería-el-techo-de-verdad)
8. [Glosario rápido](#8-glosario-rápido)

> Datos concretos de este diseño tomados de los reportes
> [`report-20260628.md`](report-20260628.md),
> [`report-fmax-sweep-20260628.md`](report-fmax-sweep-20260628.md) y
> [`report-fmax-sweep-dw32-20260629.md`](report-fmax-sweep-dw32-20260629.md).

---

## 1. El sustrato físico: LUT, FF y slice

Un FPGA no "ejecuta" tu Verilog: lo **mapea** a celdas físicas fijas. Tres piezas alcanzan
para entender todo lo demás.

### LUT (Look-Up Table) — la lógica combinacional

Es el ladrillo de **lógica combinacional**. En el Artix-7 (Basys-3) son **LUT6**: una tabla
de verdad de 2⁶ = 64 bits que implementa **cualquier** función booleana de hasta 6 entradas.
Al configurar el FPGA se graban esos 64 bits y el LUT "se convierte" en tu compuerta, mux o
rebanada de sumador.

Todo lo combinacional del datapath se mapea a miles de LUTs: la ALU, los muxes de
forwarding, el decode, los comparadores de branch, los muxes anchos del dump. En este diseño
con `DATA_WIDTH=32`: **5410 LUTs** (26 % de los 20800 disponibles).

> Cuando varios LUTs se combinan para formar un mux más ancho que 6 entradas, el slice usa
> los **muxes dedicados F7/F8** (de ahí las columnas "F7 Muxes / F8 Muxes" del reporte de
> utilización: son los muxes 32:1 / 64:1 del dump de registros y memoria).

### FF (flip-flop) — el estado

El elemento **secuencial**: guarda 1 bit y lo actualiza en el flanco de reloj. Son tus
registros: el banco de 32, la memoria de datos (64 words), los buffers del pipeline,
los registros de la DebugUnit. En este diseño: **12316 FFs** (30 %).

### Slice — la celda que los empaqueta

La unidad física que el placer ubica. Cada slice del Artix-7 contiene **4 LUT6 + 8 FFs** +
carry + los muxes F7/F8. El `xc7a35t` tiene **8150 slices**. Esta es la métrica que termina
saturándose (§5), y la razón es **cómo** se pueden empaquetar los FFs, no cuántos hay.

---

## 2. Análisis de timing estático (STA) y el slack

El STA verifica que **cada** señal se propague por la lógica combinacional y quede estable
en la entrada del FF que la captura **antes** del flanco de reloj, con su margen de setup.
La métrica es el **slack**:

```
slack = tiempo_disponible − retardo_del_camino
```

- **retardo_del_camino** = lógica (LUTs) + ruteo (cables). Es ~**fijo**: el dato tarda lo
  que tarda en cruzar el silicio.
- **tiempo_disponible** = lo fija el reloj. **Se achica cuando subís la frecuencia.**

`slack ≥ 0` → cierra. `slack < 0` → el FF puede capturar basura (metaestabilidad). La regla
de cierre del diseño es **WNS ≥ 0** (Worst Negative Slack, el slack del peor camino).

**El mecanismo central de todo este documento:** el retardo del camino no cambia con la
frecuencia, pero el tiempo disponible sí. Subir la frecuencia es ir comiéndose el margen
hasta que el peor camino ya no entra.

---

## 3. El camino crítico: el dump y el cruce posedge→negedge

El peor camino de este diseño **no es la ALU**, sino la **lectura de estado para el dump de
debug**: `RegisterFile`/`DataMemory` → mux ancho → `msb_byte` → `r_tx_data` de la DebugUnit.

Y tiene un agravante: el core corre en **flanco de subida** (`posedge`) y la DebugUnit en
**flanco de bajada** (`negedge`, intencional, para estabilizar `pipeline_enable`/`imem_wr`;
ver [`DEBUG_UNIT.md` §9](DEBUG_UNIT.md#9-mecanismos-clave)). Un camino que sale en `rise@0` y
se captura en `fall@T/2` tiene de presupuesto **medio período**, no el período entero.

Con un retardo de camino de ~7.4 ns (≈72 % ruteo), el medio período manda:

| Freq | Período | **Medio período (presupuesto)** | Retardo (~fijo) | Slack |
|-----:|:-------:|:-------------------------------:|:---------------:|:-----:|
| 65 MHz | 15.38 ns | **7.69 ns** | ~7.37 ns | **+0.32** ✅ |
| 75 MHz | 13.33 ns | **6.67 ns** | ~6.6 ns | **+0.04** ⚠️ |
| 100 MHz | 10.00 ns | **5.00 ns** | ~6.25 ns | **−1.25** ❌ |

Por eso el ancho del datapath casi no movió el techo: el cuello es **ruteo en un camino con
presupuesto de medio período**, no la cantidad de bits de la lógica. El detalle del camino
está en [`report-20260628.md`](report-20260628.md) §2-3.

---

## 4. Optimización dirigida por timing: replicación de registros

Acá aparece el comportamiento que sorprende. El optimizador de Vivado (`opt_design`,
`phys_opt_design`, el placer) tiene **una sola meta: WNS ≥ 0**, y su esfuerzo es
**proporcional a lo apretado que esté el timing**:

- **Timing holgado (≤65 MHz):** no tiene nada que perseguir → deja el netlist **como salió de
  síntesis**. Los registros quedan como instancias únicas. **No replica nada.**
- **Timing justo o fallando (≥70 MHz):** intenta recuperar slack, y una de sus herramientas
  principales es **replicar registros**.

### ¿Por qué replicar un registro acelera?

Un camino crítico típico es un FF que maneja **muchas cargas dispersas** por el chip (alto
*fanout*): el cable hasta la carga más lejana es largo → mucho **retardo de ruteo** (y en
este diseño el ruteo es el 72 % del retardo). La cura: hacer **copias del mismo FF**, cada
una ubicada cerca de un grupo de cargas, para que todas manejen cables cortos. Cambia
**área por velocidad**.

```
Antes (1 FF, fanout alto, ruteo largo):     Después (replicado, rutas cortas):

         ┌──► cargas A (cerca)              FF₁ ──► cargas A
   FF ───┤                                  FF₂ ──► cargas B   (cada copia,
         └──► cargas B (LEJOS) ◄ crítico    FF₃ ──► cargas C    cerca de su grupo)
```

El optimizador hace lo mismo con retiming y "break lutnm for timing". Funciona para el
slack… pero tiene un efecto colateral caro, que es el punto siguiente.

---

## 5. Control sets: por qué el cuello no son los LUTs

Un dato del barrido que no cierra a primera vista: con `DATA_WIDTH=32` los LUTs bajan al
**26 %**, pero una corrida que **sí coloca** a 75 MHz reporta el device **al 99.5 % de
slices**. ¿Cómo, si sobran LUTs?

La respuesta es el **control set**: la combinación única de `{clock, clock-enable,
set/reset}` que comparte un grupo de FFs. La restricción física clave:

> **Un slice solo puede alojar FFs de UN control set.** Sus 8 FFs tienen que compartir el
> mismo enable y el mismo reset.

Entonces, si hay **N control sets distintos**, necesitás **al menos ~N slices** para los FFs,
**sin importar cuántos LUTs uses**. Y la replicación de §4 **fragmenta los control sets**:
donde antes muchos FFs compartían una red de enable (1 control set), tras replicar/
reestructurar hay muchas redes distintas.

Medido en este diseño:

| Régimen | Control Sets | Slices | Estado |
|--------:|:------------:|:------:|:-------|
| ≤65 MHz (timing holgado) | **499** (6 %) | 58–61 % | cómodo, sin replicación |
| ≥70 MHz (timing apretado) | **~8000** (97 %) | **99.5 %** | al borde / overflow |

Con ~8000 control sets el diseño reclama ~8000 de los 8150 slices **aunque los LUTs estén al
26 %**. Por eso **el cuello de área no son los LUTs ni los FFs en sí, sino los control
sets**, y por eso angostar el datapath (que baja LUTs) no descongestiona a alta frecuencia.

---

## 6. El "cliff": cómo se encadena todo

Juntando §2–§5, la cadena causal completa:

```
frecuencia ↑
   │
   ▼
medio período ↓   (el retardo del dump es ~fijo)
   │
   ▼
slack ↓  →  el optimizador DEBE perseguir timing
   │
   ▼
replica / reestructura registros   (§4)
   │
   ▼
control sets:  499 → ~8000   (§5)
   │
   ▼
slices:  58 % → 99.5 %
   │
   ▼
placement AL BORDE  →  no-determinista (a veces ni coloca)
```

Esto explica los tres síntomas del barrido:

- **≤65 MHz:** slack cómodo → sin replicación → 499 control sets → 58 % slices → coloca
  holgado y reproducible. **Es el régimen sano** (el default actual: 65 MHz, WNS +0.319 ns).
- **70 MHz:** slack apretado → replicación → control sets explotan → **no entró** (overflow).
- **75 MHz:** mismo régimen de explosión, pero **coloca de pura suerte** al 99.5 %; un rebuild
  podría no rutear.

El umbral ~65–70 MHz **no es un número mágico**: es justo donde el retardo (fijo) del camino
de dump empieza a perderle al medio período (que se achica), forzando al optimizador a entrar
en modo agresivo. Mové el camino crítico y el umbral se mueve con él.

---

## 7. Qué movería el techo de verdad

Como el cuello es el camino de dump `posedge→negedge` (timing) y los control sets que su
optimización dispara (área), las palancas reales **no** son el ancho de datos ni la cantidad
de words del dump:

1. **Registrar la lectura del dump** (Opción A de [`report-20260628.md`](report-20260628.md) §4):
   meter un FF entre el core y la DebugUnit parte la cadena `posedge→negedge` en tramos de
   **período completo**. La latencia extra es irrelevante en un dump serie a 19200 baud.
2. **Re-clockear la DebugUnit en posedge** (Opción C): elimina la penalización de medio
   período de raíz. Más riesgoso (rediseña el gating del pipeline).
3. **Memoria de datos a BRAM:** además del timing, **colapsa los control sets** (saca ~4096
   FFs con enables propios de la lógica), eliminando el "cliff" de placement y dejando empujar
   la frecuencia sin saturar el device.

`DATA_WIDTH=32` es **complementario** a estas (baja LUTs, subió el confiable de 60 a 65 MHz),
no un sustituto.

---

## 8. Glosario rápido

| Término | Qué es |
|---------|--------|
| **LUT** | *Look-Up Table*; tabla de verdad de 6 entradas, el ladrillo de lógica combinacional del FPGA. |
| **FF** | Flip-flop; elemento de 1 bit de estado, actualizado por flanco de reloj. |
| **Slice** | Celda física que empaqueta 4 LUT6 + 8 FFs + carry + muxes F7/F8. |
| **F7/F8 mux** | Muxes dedicados del slice que combinan LUTs para formar muxes anchos (>6 entradas). |
| **Slack** | `tiempo_disponible − retardo`; margen de timing. Negativo = violación. |
| **WNS / TNS** | Worst / Total Negative Slack: peor camino / suma de los que fallan. |
| **Setup** | El dato debe llegar *temprano* antes del flanco. Falla si la lógica es lenta. |
| **Control set** | Combinación única `{clock, clock-enable, set/reset}`. Un slice aloja FFs de uno solo. |
| **Replicación de registros** | Copiar un FF para acortar rutas de alto fanout; canjea área por velocidad. |
| **Retiming** | Mover registros a través de lógica para balancear retardos entre etapas. |
| **STA** | *Static Timing Analysis*; verificación de timing sin simular, sobre todos los caminos. |

### Referencias

- Camino crítico del dump: [`report-20260628.md`](report-20260628.md)
- Barrido con datapath de 64 bits: [`report-fmax-sweep-20260628.md`](report-fmax-sweep-20260628.md)
- Barrido con datapath de 32 bits (control sets, cliff): [`report-fmax-sweep-dw32-20260629.md`](report-fmax-sweep-dw32-20260629.md)
- Por qué el `negedge` de la DebugUnit: [`DEBUG_UNIT.md` §9](DEBUG_UNIT.md#9-mecanismos-clave)
