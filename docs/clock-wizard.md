# Clocking Wizard y lectura del Timing Summary (Vivado)

**Fecha:** 2026-07-04
**Contexto:** cómo reemplazar el `MMCME2_BASE` instanciado a mano en `RiscvTop` por el
IP **Clocking Wizard** desde la GUI de Vivado, y cómo interpretar el reporte de timing.

---

## 1. Punto de partida: qué hay hoy

En [`src/sources_1/Top/RiscvTop.sv`](../src/sources_1/Top/RiscvTop.sv) el reloj del SoC
se genera instanciando el **primitivo `MMCME2_BASE` directamente** (no el IP), con estos
parámetros:

| Parámetro | Valor | Significado |
|-----------|-------|-------------|
| `CLKIN1_PERIOD` | `10.000` | 100 MHz de entrada (pin W5) |
| `DIVCLK_DIVIDE` | `1` | — |
| `CLKFBOUT_MULT_F` | `6.500` | VCO = 100 × 6.5 = **650 MHz** (en rango) |
| `CLKOUT0_DIVIDE_F` | `10.000` | salida = 650 / 10 = **65 MHz** |

La salida `CLKOUT0` pasa por un `BUFG` (`w_clk`) y alimenta todo el SoC. La
realimentación `CLKFBOUT → CLKFBIN` también pasa por un `BUFG`. El `w_locked` del MMCM
se usa para mantener el reset activo hasta que el reloj engancha.

**Por qué se usó el primitivo y no el IP:** para que el flujo *batch sin proyecto*
(`vivado -mode tcl`, sin `.xpr` commiteado) siga siendo autocontenido. El IP Clocking
Wizard genera archivos `.xci` que hay que regenerar dentro de un proyecto/script.

---

## 2. Migrar al Clocking Wizard (GUI)

1. **Flow Navigator → IP Catalog** (o `Window → IP Catalog`).
2. Buscá **"Clocking Wizard"** y doble clic.
3. En el diálogo **Add IP** elegí **`Customize IP`** (agrega el IP como **módulo RTL**).
   - ❌ *No* uses "Add IP to Block Design" — eso es para el flujo de diagramas de bloques
     (IP Integrator), que este proyecto no usa.
4. Pestaña **Clocking Options**:
   - Primitive: **MMCM**.
   - Input Clock: `Primary` = **100.000 MHz**, source *Single ended clock capable pin* (W5).
   - Se puede dejar que calcule M/D, o forzar **M = 6.5**, **D = 1** (VCO 650 MHz).
5. Pestaña **Output Clocks**:
   - `clk_out1` → **Requested Output Freq = 65.000 MHz** (queda `CLKOUT0_DIVIDE = 10`).
   - En **Enable Optional Ports**, activar **`locked`** (se usa para el reset).
6. **OK → Generate Output Products**.

El IP genera un módulo (típicamente `clk_wiz_0`) con puertos `clk_in1`, `clk_out1`,
`locked` (+ `reset` opcional). El BUFG de salida y la realimentación los mete el propio
IP internamente, así que al migrar se **eliminan** los `BUFG` y el `MMCME2_BASE` a mano.

### Instancia en `RiscvTop.sv`

```systemverilog
clk_wiz_0 u_clk_wiz (
    .clk_in1 (i_clk),      // 100 MHz de W5
    .clk_out1(w_clk),      // 65 MHz al SoC
    .locked  (w_locked)
    // .reset (i_reset)    // solo si se habilitó el puerto reset
);
```

El resto de la lógica de reset (`w_async_rst`, el `always_ff @(posedge w_clk ...)`)
queda **igual**, porque sigue usando `w_locked` y `w_clk`.

---

## 3. Trade-off: IP vs. primitivo

| Opción | Pro | Contra |
|--------|-----|--------|
| **`MMCME2_BASE`** (actual) | Autocontenido, sin IP, funciona en batch tal cual | Config "a mano", menos visual |
| **Clocking Wizard IP** | Config visual, fácil re-tunear frecuencia y agregar salidas | Rompe el flujo batch autocontenido: hay que commitear el `.xci` y agregar `read_ip` + `generate_target all` / `synth_ip` al script de síntesis |

**Recomendación:** si el objetivo es solo *cambiar la frecuencia*, no hace falta el
Wizard — alcanza con editar `CLKFBOUT_MULT_F` y `CLKOUT0_DIVIDE_F` en el primitivo, sin
tocar la toolchain. El Wizard conviene si se van a usar **múltiples salidas de reloj** o
se quiere la GUI para validar el rango del VCO.

---

## 4. Obtener el Timing Summary (GUI)

1. Correr al menos **Synthesis**; idealmente **Implementation** (el timing post-route es
   el que vale de verdad — el post-synth es estimado, sin routing real).
2. **Flow Navigator → Open Implemented Design**.
3. Menú: **Reports → Timing → Report Timing Summary…** → **OK**.
4. Se abre la pestaña **Timing** → **Design Timing Summary**.

Alternativa rápida: al terminar Implementation, la ventana **Design Runs** ya muestra las
columnas **WNS / TNS / WHS / THS**. Equivalente Tcl: `report_timing_summary`.

---

## 5. Cómo interpretar el Design Timing Summary

El análisis de timing estático (STA) verifica que toda señal se propague por la lógica
combinacional y quede estable **antes** del flanco de reloj que la captura.

```
slack = tiempo_disponible − tiempo_requerido
```

- **slack ≥ 0** → llega con margen → ✅ cumple.
- **slack < 0** → llega tarde → ❌ violación (el flip-flop puede capturar basura/metaestable).

### Setup (define la frecuencia máxima — es el bloque que importa)

| Campo | Qué es | Cómo se lee |
|-------|--------|-------------|
| **WNS** (Worst Negative Slack) | el peor slack de setup del diseño | **positivo = cierra timing**; negativo = no cierra |
| **TNS** (Total Negative Slack) | suma de todos los slacks negativos | `0.000` = ningún camino falla |
| **Number of Failing Endpoints** | cuántos caminos violan setup | debe ser **0** |
| **Total Number of Endpoints** | total analizado | referencia de tamaño |

### Hold (tiempos de retención)

- **WHS** (Worst Hold Slack): margen para que el dato no cambie *demasiado pronto* tras el
  flanco. Es chico por naturaleza; **mientras sea positivo, OK**.
- **THS** / failing endpoints: igual que en setup, deben ser `0`.

### Pulse Width

- **WPWS** (Worst Pulse Width Slack): verifica ancho mínimo de pulso de reloj / requisitos
  de los primitivos. Positivo y sin failing = OK.

### El veredicto

El cartel **"All user specified timing constraints are met."** es la conclusión: el
diseño **cierra timing** tal como está.

### Frecuencia real

El WNS es respecto al reloj del **SoC (~65 MHz, `clk_out1`)**, no a los 100 MHz de
entrada. Para confirmar a qué frecuencia se cierra, abrir **Clock Summary** en el panel
izquierdo: lista cada reloj con su **período y frecuencia** reales. Un WNS holgado (p. ej.
> +1 ns) indica margen para **subir la frecuencia** si se quiere.

### Warnings que NO bloquean

- `no_input_delay` / `no_output_delay` (⚠️): puertos de I/O (`i_rx`, `o_tx`, LEDs) sin
  constraint de delay externo. No afectan el timing interno ni el veredicto; solo
  significan que el timing *hacia los pines* no se está chequeando. Irrelevante para una
  UART lenta.

---

## Referencias

- Reporte detallado de timing @ 100 MHz (no cerraba): [`docs/reports/report-20260628.md`](reports/report-20260628.md)
- Barrido de Fmax con datapath de 32 bits: [`docs/reports/report-fmax-sweep-dw32-20260629.md`](reports/report-fmax-sweep-dw32-20260629.md)
- Módulo top: [`src/sources_1/Top/RiscvTop.sv`](../src/sources_1/Top/RiscvTop.sv)
