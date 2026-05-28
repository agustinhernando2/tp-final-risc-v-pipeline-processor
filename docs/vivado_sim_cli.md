# Vivado CLI Simulation Flow

Tres herramientas en cadena: **xvlog → xelab → xsim**.

## xvlog — Compilación

Analiza y compila los archivos fuente. Detecta errores de sintaxis y de tipo.

```bash
xvlog --sv src/sources_1/**/*.sv src/sim_1/<tb_dir>/<tb>.sv
```

- `--sv` habilita SystemVerilog.
- Genera objetos en `xsim.dir/work/`. No produce un ejecutable todavía.

## xelab — Elaboración

Enlaza todos los módulos, resuelve instancias y expande parámetros. Produce el snapshot de simulación.

```bash
xelab -debug typical <top_module> -s <snapshot_name>
```

- `<top_module>`: nombre del testbench (ej. `tb_RegisterFile`).
- `-s <snapshot_name>`: nombre del snapshot que usará `xsim`.
- `-debug typical`: guarda visibilidad de señales internas (necesario para el waveform viewer).

Si cambiás el top-level o los parámetros, hay que re-elaborar.

## xsim — Simulación

Ejecuta el snapshot generado por `xelab`.

```bash
xsim <snapshot_name> --runall
```

- `--runall`: corre hasta que el testbench llame a `$finish`.
- Sin `--runall` abre una consola interactiva donde podés avanzar ciclo a ciclo.

## Flujo completo (ejemplo)

```bash
mkdir -p sim_out && cd sim_out
xvlog --sv ../src/sources_1/**/*.sv ../src/sim_1/ID/tb_RegisterFile.sv
xelab -debug typical tb_RegisterFile -s sim_rf
xsim sim_rf --runall
```
