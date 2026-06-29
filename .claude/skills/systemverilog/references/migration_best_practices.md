# Migración Verilog→SV, Operadores, Assertions, Errores y Toolchain

## Estrategia de migración paso a paso

SV es superset de Verilog: podés mezclar `.v` y `.sv` en el mismo proyecto.
Migrá gradualmente para poder validar en cada paso.

### Fase 1 — Cambios mecánicos (una tarde, riesgo mínimo)

1. Renombrá archivos `.v` → `.sv`.
2. Reemplazá `reg`/`wire` → `logic`.
3. Reemplazá `always @(*)` → `always_comb`.
4. Reemplazá `always @(posedge clk)` con cuerpo 100% síncrono → `always_ff @(posedge clk)`.
5. Compilá. El compilador reportará latches inferidos y mezclas de bloqueante/no-bloqueante
   que antes pasaban silenciosos.

### Fase 2 — Centralización de tipos (una tarde, riesgo bajo)

1. Creá un `types_pkg.sv` con opcodes, constantes y typedefs.
2. Reemplazá `localparam` dispersos por imports del package.
3. Convertí `localparam` de FSMs en `enum` tipados.

### Fase 3 — Structs en módulos de paso de datos (2-3 días, riesgo medio)

1. Definí un struct por cada grupo de señales relacionadas.
2. Reescribí los módulos que mueven esas señales usando el struct.
3. Modificá los módulos adyacentes para producir/consumir el struct.
4. Reemplazá ~100 wires individuales en el top-level por N structs.

Requiere test suite para validar que no rompiste nada.

### Fase 4 — Refactor de control logic (1 día)

Convertí el `case` gigante en `always_comb` + defaults + `unique case`.
Ver sección "unique/priority case" más abajo.

### Fase 5 — Assertions (continuo)

Cada vez que arregles un bug, agregá una assertion. Con el tiempo el set
de assertions se convierte en red de seguridad automática.

### Fase 6 (opcional) — Interfaces

Solo si los structs ya no alcanzan para describir un protocolo complejo.

---

## Operadores nuevos en SV

### `inside` — reemplaza cadenas de OR

```systemverilog
// Verilog
if (op == LW || op == LH || op == LB || op == LWU || op == LBU) ...

// SystemVerilog
if (op inside {OP_LW, OP_LH, OP_LB, OP_LWU, OP_LBU}) ...
```

### `'0`, `'1`, `'x` — asignación de todos los bits

```systemverilog
logic [31:0] r32;
r32 <= '0;   // 32 ceros (antes: 32'b0 o 32'd0)
r32 <= '1;   // 32 unos
r32 <= 'x;   // 32 X — útil para debug
```

### Operadores lógicos vs bitwise

```systemverilog
// Lógico (resultado 1 bit) — preferido para condiciones
if (a == 1'b1 && b == 1'b1) ...
if (!valid) ...

// Bitwise (opera bit a bit) — para transformaciones de vectores
result = a & b;
result = a | b;
result = ~a;
```

### Streaming (reordenar bits)

```systemverilog
logic [7:0] x = 8'b10110010;
logic [7:0] reversed = {<<{x}};   // 8'b01001101 — útil para UART/serialización
```

---

## `unique case` y `priority case`

### El problema con `case` estándar

```verilog
case (opcode)
    OP_A: ...;
    OP_B: ...;
    // ¿Falta algún caso? Verilog no avisa.
    // ¿Hay solapamiento? Verilog no avisa.
endcase
```

### `unique case`

Declara que los casos son **mutuamente excluyentes** y que siempre hay un match
(o hay `default`). El compilador y simulador lo verifican.

```systemverilog
always_comb begin
    // Defaults primero para evitar latches en cualquier señal no cubierta
    out_a = '0;
    out_b = '0;
    flag  = 1'b0;

    unique case (opcode)
        OP_ADD: begin out_a = a + b; flag = 1'b1; end
        OP_SUB: out_a = a - b;
        OP_AND: out_a = a & b;
        OP_OR:  out_a = a | b;
        default: ;   // out_a y flag ya tienen default arriba
    endcase
end
```

Beneficio de síntesis: el sintetizador puede optimizar más agresivamente
al saber que los casos son mutuamente excluyentes.

### `priority case`

Evalúa en orden, solo el primer match cuenta. Equivale a `if/else if/else if`.

```systemverilog
priority case (1'b1)
    irq_high:  handler = HANDLER_HIGH;
    irq_med:   handler = HANDLER_MED;
    irq_low:   handler = HANDLER_LOW;
    default:   handler = HANDLER_NONE;
endcase
```

---

## Generate: replicación de hardware

```systemverilog
genvar i;
generate
    for (i = 0; i < N; i++) begin : gen_units
        my_unit #(.ID(i)) u_inst (
            .a  (a_vec[i]),
            .b  (b_vec[i]),
            .out(out_vec[i])
        );
    end
endgenerate

// Acceso jerárquico: top.gen_units[2].u_inst.out
```

Aplicación típica: inicializar arrays en reset con valores distintos por índice.

---

## Parámetros

### `parameter` vs `localparam`

- `parameter`: puede ser sobreescrito al instanciar el módulo.
- `localparam`: constante interna, no sobreescribible desde afuera.

```systemverilog
module fifo #(
    parameter int DEPTH = 16,
    parameter int WIDTH = 32
) (
    input  logic             i_clk, i_rst, i_push, i_pop,
    input  logic [WIDTH-1:0] i_data,
    output logic [WIDTH-1:0] o_data,
    output logic             o_full, o_empty
);
    logic [WIDTH-1:0] mem [DEPTH];
    localparam int PTR_W = $clog2(DEPTH);
    // ...
endmodule

fifo #(.DEPTH(64), .WIDTH(8)) u_uart_fifo (...);
```

### Type parameters

Ver `structs_enums_packages.md` sección "Type parameters".

---

## Assertions

Las assertions verifican comportamiento del diseño en simulación. El sintetizador
las ignora (no generan hardware).

### Immediate assertions

```systemverilog
always_ff @(posedge clk) begin
    assert (!(wr_en && rd_en))
        else $error("simultaneous read and write");
end
```

### Concurrent assertions

```systemverilog
// Propiedad: si valid sube, no debe bajar hasta que ready lo acepta
property hold_valid;
    @(posedge clk) disable iff (rst)
    (valid && !ready) |=> valid;
endproperty
a_hold_valid: assert property (hold_valid) else $error("valid dropped early");

// Implicación: req en ciclo N → grant en ciclo N+1
property req_grant;
    @(posedge clk) req |=> grant;
endproperty
a_req_grant: assert property (req_grant);

// Temporal: start dispara done exactamente 5 ciclos después
property latency_5;
    @(posedge clk) start |-> ##5 done;
endproperty
```

### Operadores temporales

| Operador | Significado |
|---|---|
| `\|->` | implicación en el mismo ciclo |
| `\|=>` | implicación en el ciclo siguiente |
| `##N` | N ciclos después |
| `##[M:N]` | entre M y N ciclos después |
| `disable iff (cond)` | suspender assertion cuando cond es true |

### Assertions útiles en RTL general

```systemverilog
// FIFO: full y empty son mutuamente excluyentes
assert property (@(posedge clk) !(o_full && o_empty));

// Señal one-hot
assert property (@(posedge clk) $onehot0(grant_vec));

// No escribir sobre registro de solo lectura
assert property (@(posedge clk) !(wr_en && wr_addr == READONLY_ADDR));

// Handshake: data válido mientras valid=1 y ready=0
property stable_data;
    @(posedge clk) (valid && !ready) |=> $stable(data);
endproperty
```

---

## Errores comunes y cómo evitarlos

### 1. Mezclar `=` y `<=` en el mismo bloque

```systemverilog
// MAL
always_ff @(posedge clk) begin
    a = b;    // bloqueante en secuencial: race condition
    c <= d;
end
// BIEN: siempre <= en always_ff
always_ff @(posedge clk) begin
    a <= b;
    c <= d;
end
```

`always_ff` lanza error de compilación si usás `=`.

### 2. Latch inferido — olvidar default o `else`

```systemverilog
// MAL — always_comb detecta esto como error
always_comb begin
    if (enable) out = a;   // sin else → latch
end

// BIEN
always_comb begin
    out = '0;              // default
    if (enable) out = a;
end
```

### 3. Multidrive — dos bloques asignan la misma señal

```systemverilog
// MAL — error de compilación
always_ff  @(posedge clk) my_signal <= ...;
always_comb              my_signal = ...;

// BIEN: una señal, un driver
```

### 4. Truncado silencioso de anchos

```systemverilog
logic [7:0]  a;
logic [31:0] b = 32'hDEAD_BEEF;
assign a = b;           // Verilog: trunca silenciosamente
assign a = b[7:0];      // BIEN: explícito
assign a = 8'(b);       // BIEN: cast explícito con truncado documentado
```

### 5. Comparación con X

```systemverilog
// Si valid = 1'bx, == da resultado indeterminado (ni true ni false)
if (valid == 1'b1) ...

// Para comparar incluyendo X y Z
if (valid === 1'b1) ...    // === es case-equality, incluye X/Z

// En RTL sintetizable, generalmente querés:
if (valid) ...
```

### 6. Enums de tipos diferentes con mismo valor numérico

```systemverilog
typedef enum logic [1:0] { A_IDLE, A_RUN } fsm_a_t;
typedef enum logic [1:0] { B_IDLE, B_RUN } fsm_b_t;
fsm_a_t sa;
fsm_b_t sb;
sa = B_IDLE;   // ERROR: tipos incompatibles — el compilador te salva
```

### 7. `parameter type` vs `parameter int`

```systemverilog
module flop #(parameter type T = logic) ( ... );
flop #(.T(32)) u (...);             // ERROR: 32 no es un tipo
flop #(.T(logic [31:0])) u (...);   // OK
```

### 8. Package importado pero no compilado primero

El package debe estar en el proyecto y compilarse antes que los módulos
que lo importan. En iverilog/verilator, listarlo primero en la línea de comandos.

---

## Toolchain

### Vivado

- Soporte completo de SV sintetizable desde 2014.
- Project Settings → General → Target language: SystemVerilog.
- Archivos `.sv` se reconocen automáticamente por extensión.
- XSim soporta assertions y constructs de testbench completos.

### Verilator (lint y simulación rápida)

```bash
# Solo lint (detecta errores sin compilar simulación)
verilator --lint-only --top-module top_module types_pkg.sv top_module.sv

# Compilar simulación
verilator -Wall --cc --exe tb_top.cpp types_pkg.sv top_module.sv -o sim/Vtop

# Con assertions habilitadas
verilator --assert --cc types_pkg.sv top_module.sv
```

Verilator solo soporta RTL sintetizable (no POO ni coverage avanzado),
pero es muy rápido y es open source.

### Icarus Verilog

Soporte parcial de SV. Conveniente para Verilog clásico, pero limitado
para SV moderno. Preferir Verilator para proyectos nuevos en SV.

### Resumen de herramientas

| Herramienta | SV RTL | Assertions | Velocidad | Licencia |
|---|---|---|---|---|
| Vivado XSim | Sí | Sí | Media | Gratis (Xilinx) |
| ModelSim/QuestaSim | Sí | Sí | Media | Comercial |
| Verilator | Sí (solo RTL) | Sí | Muy rápida | Open source |
| Icarus Verilog | Parcial | No | Rápida | Open source |

---

## Buenas prácticas — resumen

### Convenciones de nombres

```systemverilog
// Tipos: snake_case con sufijo _t
typedef enum { ... } state_t;
typedef struct packed { ... } packet_t;

// Constantes: UPPER_SNAKE
localparam int FIFO_DEPTH = 16;

// Señales: snake_case con prefijo i_/o_
input  logic        i_clk;
output logic [31:0] o_result;

// Instancias: prefijo u_
my_module u_inst (.clk(clk), ...);

// Generate blocks: prefijo gen_
for (genvar i = 0; ...) begin : gen_pipeline_stages
```

### Checklist antes de sintetizar

- [ ] Todos los `always @(*)` reemplazados por `always_comb`.
- [ ] Todos los `always @(posedge clk)` reemplazados por `always_ff`.
- [ ] Todos los `reg`/`wire` reemplazados por `logic`.
- [ ] Todo `always_comb` tiene default asignado antes del case/if.
- [ ] Ningún bloque mezcla `=` y `<=`.
- [ ] States de FSMs definidos como `enum`.
- [ ] Types compartidos entre módulos centralizados en package.
- [ ] Assertions en propiedades no obvias del diseño.
