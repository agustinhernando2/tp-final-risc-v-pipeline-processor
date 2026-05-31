# Tests de Integración

Testbenches que ejercitan el pipeline **completo** (IF → ID → EX → MEM → WB)
instanciando el módulo top-level `RISCV`, en vez de un único módulo aislado.

## `tb_IF_to_WB.sv`

Verifica el datapath de 5 etapas en el caso más simple: **sin hazards de datos**.
Las dependencias entre instrucciones se evitan intercalando NOPs, de modo que
no intervienen ni el forwarding ni los stalls — así se aísla y comprueba el
flujo básico del pipeline.

### Programa de prueba

| Dir. | Instrucción        | Efecto                |
|------|--------------------|-----------------------|
| 0x00 | `addi x1, x0, 10`  | x1 = 10               |
| 0x04 | `addi x2, x0, 3`   | x2 = 3                |
| 0x08 | `add  x3, x1, x2`  | x3 = 13               |
| 0x0C | `and  x4, x1, x2`  | x4 = 10 & 3 = 2       |
| 0x10 | `or   x5, x1, x2`  | x5 = 10 \| 3 = 11     |
| 0x14 | `sub  x6, x1, x2`  | x6 = 10 − 3 = 7       |

Entre cada instrucción útil se insertan **3 NOPs** (`addi x0, x0, 0` =
`0x00000013`). Con esa separación, cuando una instrucción dependiente llega a
ID su productora ya pasó por WB y escribió el resultado en el register file, por
lo que no hace falta forwarding.

### Estructura del testbench

- **Parámetros / DUT:** instancia `RISCV` con datos y PC de 32 bits, registros
  de 5 bits (32 registros) y memoria de instrucciones de `2^8 = 256` palabras.
- **Reloj:** periodo de 10 ns. La task `tick` espera el flanco de subida y
  avanza 1 ns para muestrear las señales de forma segura, evitando carreras.
- **`load_instr(addr, instr)`:** carga una palabra de instrucción usando el
  puerto de debug de la memoria (`i_mem_wr` / `i_mem_addr` / `i_mem_data`) — el
  mismo puerto que en hardware usará el cargador por UART.
- **`check(name, got, expected)`:** compara con `===` (igualdad de 4 estados,
  detecta `X`/`Z`) y lleva la cuenta de PASS/FAIL.

### Secuencia de ejecución

1. Inicializa señales (`i_rx = 1`, línea UART idle).
2. **Reset:** mantiene `i_reset = 1` por 2 ciclos con `i_if_enable = 0` (IF
   congelado, el PC no avanza).
3. **Carga** el programa con `load_instr` mientras el PC sigue congelado, de
   modo que no se ejecute nada a medio cargar.
4. `i_if_enable = 1` → libera el fetch; el PC avanza y las instrucciones fluyen
   por el pipeline.
5. `repeat (40) tick` → da tiempo a que la última instrucción (`sub`) llegue a
   WB y escriba.
6. Lee el register file por **acceso jerárquico** (`DUT.ID.RF.r_RF[i]`) y
   verifica los valores esperados.

### Resultados esperados

```
x1 = 10, x2 = 3, x3 = 13, x4 = 2, x5 = 11, x6 = 7
```

Todos los `check` deben dar PASS y el testbench imprime `ALL TESTS PASSED`.

### Cómo correrlo

```bash
mkdir -p sim_out && cd sim_out
xvlog --sv ../src/sources_1/**/*.sv ../src/sim_1/Integrador/tb_IF_to_WB.sv
xelab -debug typical tb_IF_to_WB -s sim_snapshot
xsim sim_snapshot --runall
```
