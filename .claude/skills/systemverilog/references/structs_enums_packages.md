# Structs, Enums, Packages, Interfaces y Funciones

## Structs packed

### Por qué usarlos

Cuando un módulo pasa 15-20 señales relacionadas a otro módulo, esas señales
aparecen en 6 lugares: input port, output port, declaración interna, reset,
asignación normal, assign de salida. Agregar un campo nuevo significa tocar
todos esos lugares.

Con un struct: definís el tipo una vez y lo pasás como un único puerto.
Agregar un campo nuevo requiere **un solo cambio** (en la definición del struct).

### Sintaxis

```systemverilog
typedef struct packed {
    logic [31:0] data;
    logic        valid;
    logic [4:0]  tag;
    logic [1:0]  status;
} packet_t;

// Uso
packet_t in_pkt, out_pkt;
out_pkt.data   = in_pkt.data + 1;
out_pkt.valid  = 1'b1;
out_pkt        = '0;            // cero todos los campos

// En port list
module my_proc (
    input  packet_t i_pkt,
    output packet_t o_pkt
);
```

### Packed vs unpacked

```systemverilog
typedef struct packed   { logic [31:0] a; logic [7:0] b; } packed_t;   // sintetizable
typedef struct          { logic [31:0] a; logic [7:0] b; } unpacked_t; // solo simulación
```

**Para RTL sintetizable, siempre `packed`.**

### Asignación parcial y casting

```systemverilog
// Asignar por campo
out.data  = 32'hDEAD_BEEF;
out.valid = 1'b1;

// Asignar todo a cero o uno
out <= '0;
out <= '1;

// Cast desde vector de bits (cuando necesitás asignar desde lógica bit a bit)
logic [38:0] raw_bits;
packet_t     pkt;
assign pkt = packet_t'(raw_bits);   // cast explícito
```

---

## Enums tipados

### El problema con `localparam`

En Verilog se definen estados como localparams. Si dos FSMs distintas usan el
mismo valor numérico para estados diferentes, y accidentalmente asignás
`STATE_A_FSM1` donde va `STATE_A_FSM2`, compila sin error aunque la lógica esté mal.

### Sintaxis

```systemverilog
typedef enum logic [1:0] {
    S_IDLE  = 2'b00,
    S_FETCH = 2'b01,
    S_EXEC  = 2'b10,
    S_DONE  = 2'b11
} state_t;

state_t state, state_next;
```

El compilador **rechaza** asignar enums de tipos distintos, aunque los valores numéricos
coincidan. Esto previene mezcla accidental entre FSMs.

### Comparación con `localparam`

| Aspecto | `localparam` | `enum` |
|---|---|---|
| Tipado fuerte | No (solo números) | Sí (tipos incompatibles entre sí) |
| Ancho explícito | Sí | Sí |
| Debug en waveform | Muestra número | Muestra el nombre del estado |
| Cast numérico | Directo | Requiere `state_t'(valor)` |

### Patrón FSM recomendado

```systemverilog
typedef enum logic [1:0] { S_IDLE, S_RUN, S_DONE } fsm_t;
fsm_t state, state_next;

// Registro de estado
always_ff @(posedge clk) begin
    if (rst) state <= S_IDLE;
    else     state <= state_next;
end

// Lógica de transición (combinacional)
always_comb begin
    state_next = state;     // default: retener estado
    unique case (state)
        S_IDLE: if (start) state_next = S_RUN;
        S_RUN:  if (done)  state_next = S_DONE;
        S_DONE:            state_next = S_IDLE;
    endcase
end

// Outputs (Moore)
always_comb begin
    o_busy = (state == S_RUN);
    o_done = (state == S_DONE);
end
```

---

## Packages

### Por qué usarlos

Sin packages, los types y constants se duplican en cada módulo que los usa.
Si cambia un opcode, hay que editar varios archivos. Un package centraliza
esas definiciones en un solo lugar.

### Sintaxis

```systemverilog
// types_pkg.sv
package types_pkg;

    localparam int NB_DATA = 32;

    typedef enum logic [5:0] {
        OP_NOP = 6'd0,
        OP_ADD = 6'd1,
        OP_SUB = 6'd2,
        OP_AND = 6'd3,
        OP_OR  = 6'd4,
        OP_SHL = 6'd5
    } opcode_t;

    typedef struct packed {
        logic [NB_DATA-1:0] a, b;
        opcode_t            op;
        logic [4:0]         shamt;
    } alu_req_t;

    typedef struct packed {
        logic [NB_DATA-1:0] result;
        logic               zero;
        logic               overflow;
    } alu_resp_t;

endpackage : types_pkg
```

Importar en módulos:

```systemverilog
// Opción 1: importar todo (wildcard) — conveniente para módulos simples
import types_pkg::*;
module alu (input alu_req_t i_req, output alu_resp_t o_resp);

// Opción 2: importar específico — más explícito, evita colisiones de nombres
module alu
    import types_pkg::opcode_t, types_pkg::alu_req_t, types_pkg::alu_resp_t;
(
    input  alu_req_t  i_req,
    output alu_resp_t o_resp
);
```

### Reglas de orden de compilación

El package debe compilarse **antes** que cualquier módulo que lo importe.
- Vivado: lo maneja automáticamente si los archivos están en el proyecto.
- Verilator/iverilog: listar el .sv del package primero en la línea de comandos.

### Funciones en packages

```systemverilog
package alu_pkg;
    import types_pkg::*;

    function automatic logic [31:0] alu_compute(
        input logic [31:0] a, b,
        input logic [4:0]  shamt,
        input opcode_t     op
    );
        unique case (op)
            OP_ADD: return a + b;
            OP_SUB: return a - b;
            OP_AND: return a & b;
            OP_OR:  return a | b;
            OP_SHL: return a << shamt;
            default: return '0;
        endcase
    endfunction

endpackage : alu_pkg
```

Reglas para funciones sintetizables:
- Solo lógica combinacional (no `always_ff` adentro).
- Sin delays (`#N`).
- `automatic`: permite reentrancia. Poner siempre.

---

## Interfaces y modports

### Cuándo usarlos

- ✅ Buses con muchas señales (AXI, Wishbone, AHB, handshake válid/ready).
- ✅ Conexiones que se replican en muchos lugares del diseño.
- ❌ Conexiones simples punto-a-punto entre dos módulos (un struct alcanza).
- ❌ Si el equipo no domina la sintaxis de modport.

### Sintaxis básica

```systemverilog
interface handshake_if #(parameter int DW = 32);
    logic        valid;
    logic        ready;
    logic [DW-1:0] data;

    modport source (output valid, output data, input ready);
    modport sink   (input  valid, input  data, output ready);
endinterface

module producer (handshake_if.source hs);
    assign hs.valid = 1'b1;
    assign hs.data  = 32'hDEAD;
    // hs.ready es input aquí
endmodule

module consumer (handshake_if.sink hs);
    assign hs.ready = 1'b1;
    // hs.valid, hs.data son inputs aquí
endmodule

module top;
    handshake_if #(.DW(32)) hs();
    producer u_prod (hs.source);
    consumer u_cons (hs.sink);
endmodule
```

### Regla práctica

Para pipelines con structs bien definidos, los **interfaces no aportan nada
extra** respecto de pasar el struct directamente. Reservalos para cuando
necesitás describir un protocolo con dirección de señales variable (master/slave).

---

## Type parameters — módulos genéricos

```systemverilog
// Un único módulo para cualquier tipo de dato
module pipeline_buffer #(
    parameter type T = logic [31:0]
) (
    input  logic i_clk, i_rst, i_en,
    input  T     i_data,
    output T     o_data
);
    T r;
    always_ff @(posedge i_clk) begin
        if (i_rst)     r <= '0;
        else if (i_en) r <= i_data;
    end
    assign o_data = r;
endmodule

// Instanciaciones con distintos structs
pipeline_buffer #(.T(if_id_t))  u_if_id  (.i_clk(clk), .i_rst(rst), .i_en(en_if), .i_data(if_id_in), .o_data(if_id_out));
pipeline_buffer #(.T(id_ex_t))  u_id_ex  (.i_clk(clk), .i_rst(rst), .i_en(en_id), .i_data(id_ex_in), .o_data(id_ex_out));
pipeline_buffer #(.T(ex_mem_t)) u_ex_mem (.i_clk(clk), .i_rst(rst), .i_en(en_ex), .i_data(ex_mem_in), .o_data(ex_mem_out));
```

Esto permite tener **un solo archivo de buffer** en lugar de uno por etapa del pipeline.
