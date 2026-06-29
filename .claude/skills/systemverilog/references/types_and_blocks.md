# Tipos y bloques procedurales en SystemVerilog

## Sistema de tipos

### `logic` reemplaza `reg` y `wire`

En Verilog clásico la distinción `wire`/`reg` es puramente sintáctica:
- `wire` solo se puede asignar con `assign` o por puertos.
- `reg` solo se puede asignar dentro de `always` (no implica registro físico).

**SystemVerilog elimina esta distinción.** Usá `logic` siempre. El sintetizador
infiere si el resultado es combinacional o secuencial según cómo lo asignés.

```systemverilog
// Verilog clásico — confuso
wire [31:0] suma_v;
reg  [31:0] contador_v;
assign suma_v = a + b;
always @(posedge clk) contador_v <= contador_v + 1;

// SystemVerilog — claro
logic [31:0] suma;
logic [31:0] contador;
assign suma = a + b;
always_ff @(posedge clk) contador <= contador + 1;
```

### Tipos primitivos

| Tipo | Bits | Estados | Uso |
|---|---|---|---|
| `logic` | 1 | 4 (0,1,X,Z) | RTL general — usar siempre |
| `logic [N-1:0]` | N | 4 | Buses |
| `bit` | 1 | 2 (0,1) | Testbench |
| `int` | 32 | 2 | Índices de loops |
| `integer` | 32 | 4 | Loops que puedan tomar X/Z |

**Regla práctica:** RTL sintetizable → `logic`. Índices de `for` → `int`.

### Packed vs Unpacked

```systemverilog
// Packed: bits contiguos, sintetizable como un único vector
logic [3:0][7:0] packed_arr;     // 32 bits, acceso: packed_arr[2] = 8'hFF
typedef struct packed { logic [31:0] a; logic [7:0] b; } my_t;

// Unpacked: array de elementos independientes (modela memorias)
logic [7:0] mem [256];           // 256 elementos de 8 bits
mem[42] = 8'hFF;
```

Para estructuras de control de pipeline usá **packed**.
Para memorias (register file, RAM) usá **unpacked**.

---

## Bloques procedurales

### El problema con `always @(*)`

Verilog tiene un solo tipo de bloque procedural. Su comportamiento depende
de la sensitivity list, que es fácil de escribir mal:

```verilog
always @(a) o = a + b;   // BUG: olvida b → latch inferido
always @(*) o = a + b;   // Mejor, pero el compilador no verifica intención
```

Un **latch** se infiere cuando una señal combinacional retiene su valor en
algún camino de ejecución (no tiene asignación en todos los casos).
Los latches son problemáticos en FPGA porque introducen timing ambiguo.

### `always_ff` — registros síncronos

Captura en flanco de clock. El compilador:
- Exige `<=` (no-bloqueante). Error si usás `=`.
- Infiere retención implícita donde no asignás (correcto para registros).

```systemverilog
always_ff @(posedge clk) begin
    if (rst) q <= '0;
    else     q <= d;
end
```

Reset asíncrono (usar con cuidado en FPGA — implica timing especial):
```systemverilog
always_ff @(posedge clk or posedge rst) begin
    if (rst) q <= '0;
    else     q <= d;
end
```

### `always_comb` — lógica combinacional

El compilador:
- Construye automáticamente la sensitivity list (no podés olvidarte una señal).
- Exige `=` (bloqueante). Error si usás `<=`.
- Detecta latches inferidos como **error de compilación**.
- Detecta multidrive (dos bloques asignando la misma señal).

```systemverilog
always_comb begin
    // SIEMPRE poner defaults antes del case/if
    out_a = '0;
    out_b = '0;
    case (sel)
        2'b00: out_a = a;
        2'b01: out_b = b;
        // sin default: OK porque ya asignamos arriba
    endcase
end
```

Sin defaults, un `if` sin `else` o un `case` sin cobertura total infiere latch:

```systemverilog
// MAL — always_comb lo detecta como error
always_comb begin
    if (enable) out = a;
    // sin else: latch inferido
end

// BIEN
always_comb begin
    out = '0;           // default
    if (enable) out = a;
end
```

### `always_latch` — latches explícitos (raro)

Si realmente necesitás un latch transparente, declaralo explícitamente.
En la mayoría de diseños RTL **no querés latches**. Un `always_comb` que
infiere latch es un bug, no un feature.

```systemverilog
always_latch begin
    if (en) q = d;  // latch transparente cuando en=1
end
```

---

## Asignación: bloqueante vs no-bloqueante

| Tipo | Operador | Dónde usar | Cuándo evalúa |
|---|---|---|---|
| No-bloqueante | `<=` | `always_ff` | Al final del time-step (todos simultáneos) |
| Bloqueante | `=` | `always_comb` | Inmediatamente (orden importa) |

Mezclarlos en el mismo bloque causa race conditions en simulación:

```systemverilog
// MAL: mezcla en always_ff
always_ff @(posedge clk) begin
    a = b;    // bloqueante: afecta a antes de que termine el time-step
    c <= d;
end

// BIEN: siempre <= en always_ff
always_ff @(posedge clk) begin
    a <= b;
    c <= d;
end
```

---

## Operador `'0`, `'1`, `'x`

Asigna "todos los bits" del ancho correcto automáticamente:

```systemverilog
logic [31:0] r32;
logic [7:0]  r8;
r32 <= '0;   // 32 ceros (antes: 32'b0)
r8  <= '0;   // 8 ceros
r32 <= '1;   // 32 unos
r32 <= 'x;   // 32 X (útil para debug, no sintetizable)
```

Dentro de structs funciona igualmente: `my_struct <= '0` pone a cero todos
los campos sin importar los tipos que contenga.
