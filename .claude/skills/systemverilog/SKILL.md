---
name: systemverilog
description: >
  Asistencia completa para diseño RTL en SystemVerilog: migración desde Verilog,
  tipado (`logic`, structs packed, enums, typedefs), bloques procedurales
  (`always_ff`, `always_comb`, `always_latch`), packages, interfaces/modports,
  parámetros de tipo, assertions, buenas prácticas y errores comunes.
  También cubre formateo de código con verible-verilog-format.
  Usar SIEMPRE que el usuario mencione SystemVerilog, migración Verilog→SV,
  latches inferidos, always_comb, always_ff, structs en RTL, enums tipados,
  packages SV, modports, pipeline buffers genéricos, unique case, verificación
  con assertions, formatear archivos .sv, verible, o cualquier pregunta sobre
  diseño RTL sintetizable en SV.
---

# SystemVerilog — Skill de diseño RTL

Esta skill cubre SystemVerilog (IEEE 1800) para **diseño RTL sintetizable**.
No cubre POO (clases, herencia) ni coverage avanzado: esas features solo aplican
a testbenches y no sintetizan.

## Qué encontrar en los archivos de referencia

```
references/
├── types_and_blocks.md       → Sistema de tipos, logic, packed/unpacked,
│                               always_ff, always_comb, always_latch
├── structs_enums_packages.md → Structs packed, enums tipados, typedef,
│                               packages, interfaces/modports, funciones
└── migration_best_practices.md → Estrategia de migración Verilog→SV,
                                  operadores nuevos, unique/priority case,
                                  generate, parámetros, assertions,
                                  errores comunes, toolchain
```

Leer solo la sección relevante. Si la consulta cubre varias áreas, leer más de un archivo.

---

## Conceptos clave rápidos

### Tipos

```systemverilog
logic [31:0] data;          // reemplaza reg y wire — usar siempre en RTL
logic [7:0]  byte_val;
int          idx;           // solo para índices de loops en simulación
```

### Bloques procedurales

```systemverilog
always_ff @(posedge clk) begin   // registros — solo <=
    if (rst) q <= '0;
    else     q <= d;
end

always_comb begin               // lógica combinacional — solo =
    out = '0;                   // default antes del case/if
    case (sel)
        2'b00: out = a;
        2'b01: out = b;
    endcase
end
```

> **Regla de oro**: `always_ff` → `<=`, `always_comb` → `=`, nunca mezclar.
> El compilador lo verifica y detecta latches inferidos.

### Structs para agrupar señales

```systemverilog
typedef struct packed {
    logic [31:0] data;
    logic        valid;
    logic [4:0]  tag;
} packet_t;

packet_t in_pkt, out_pkt;
out_pkt.data = in_pkt.data + 1;
```

### Enums tipados

```systemverilog
typedef enum logic [1:0] {
    S_IDLE = 2'b00,
    S_RUN  = 2'b01,
    S_DONE = 2'b10
} state_t;

state_t state, state_next;
```

### Package (una sola fuente de verdad)

```systemverilog
// types_pkg.sv
package types_pkg;
    typedef enum logic [5:0] { OP_ADD = 6'd0, OP_SUB = 6'd1 } opcode_t;
    typedef struct packed { logic [31:0] a, b; opcode_t op; } op_req_t;
endpackage

// módulo consumidor
import types_pkg::*;
module my_unit (input op_req_t i_req, ...);
```

### Buffer genérico con type parameter

```systemverilog
module pipeline_buffer #(parameter type T = logic [31:0]) (
    input  logic i_clk, i_rst, i_en,
    input  T     i_data,
    output T     o_data
);
    T r;
    always_ff @(posedge i_clk) begin
        if (i_rst)    r <= '0;
        else if (i_en) r <= i_data;
    end
    assign o_data = r;
endmodule

// uso: pipeline_buffer #(.T(op_req_t)) u_buf (.i_clk(clk), ...);
```

---

## Cuándo leer qué referencia

| Consulta del usuario | Archivo a leer |
|---|---|
| Diferencia `reg`/`wire`/`logic`, packed vs unpacked, `always` vs `always_ff` | `types_and_blocks.md` |
| Structs, enums, typedef, packages, import, interfaces, modports, funciones | `structs_enums_packages.md` |
| Migración paso a paso, `unique case`, operadores (`inside`, `'0`), assertions, errores comunes, Vivado/Verilator | `migration_best_practices.md` |

---

## Patrones de respuesta

## Formateo de código con Verible

[Verible](https://github.com/chipsalliance/verible) es el formateador estándar para SystemVerilog. No viene con Vivado; hay que instalarlo por separado.

### Instalación

```bash
# Verificar si ya está instalado
which verible-verilog-format

# Si no está: descargar binario pre-compilado (reemplazar TAG por la versión actual)
TAG=$(curl -s https://api.github.com/repos/chipsalliance/verible/releases/latest | grep -o '"tag_name": "[^"]*"' | head -1 | cut -d'"' -f4)
curl -sL "https://github.com/chipsalliance/verible/releases/download/${TAG}/verible-${TAG}-linux-static-x86_64.tar.gz" -o /tmp/verible.tar.gz
tar -xzf /tmp/verible.tar.gz -C /tmp
mkdir -p ~/.local/bin && cp /tmp/verible-${TAG}/bin/verible-verilog-format ~/.local/bin/
export PATH="$HOME/.local/bin:$PATH"
```

En este proyecto el binario ya está en `~/.local/bin/verible-verilog-format`. Agregar `~/.local/bin` al PATH de forma permanente en `~/.zshrc` o `~/.bashrc` si aún no está.

### Uso

```bash
export PATH="$HOME/.local/bin:$PATH"

# Formatear un archivo
verible-verilog-format --inplace --indentation_spaces=4 src/sources_1/IF/InstructionFetch.sv

# Formatear todos los fuentes del proyecto
find src/sources_1 -name "*.sv" | xargs verible-verilog-format --inplace --indentation_spaces=4

# Formatear también los testbenches
find src/sim_1 -name "*.sv" | xargs verible-verilog-format --inplace --indentation_spaces=4
```

### Notas

- `--inplace` edita los archivos directamente; sin esa flag imprime en stdout.
- `--indentation_spaces=4` coincide con la convención del proyecto (4 espacios).
- El formateador solo cambia estilo (indentación, alineación de puertos); nunca altera la lógica.
- Después de formatear, siempre correr el test suite para confirmar que nada se rompió.

---

## Patrones de respuesta

Cuando el usuario pida migrar código Verilog a SV:
1. Identificar el tipo de bloque (`always @(*)` → `always_comb`, `always @(posedge clk)` → `always_ff`).
2. Reemplazar `reg`/`wire` por `logic`.
3. Si hay señales agrupadas lógicamente, proponer struct packed.
4. Si hay localparams que modelan estados o codificaciones, proponer enum.
5. Agregar `default: '0` antes de cualquier case sin coverage total.
6. Señalar latches potenciales y explicar cómo los detecta `always_comb`.

Cuando el usuario pregunte sobre errores de compilación:
- Ver sección "Errores comunes" en `migration_best_practices.md`.
- Explicar el *por qué* del error, no solo el fix.

Cuando el usuario pida diseñar un módulo nuevo en SV:
- Usar `always_ff` / `always_comb` según corresponda.
- Declarar defaults antes de case en bloques combinacionales.
- Exportar tipos a un package si el módulo forma parte de un sistema mayor.
