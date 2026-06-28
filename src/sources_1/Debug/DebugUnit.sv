`timescale 1ns / 1ps

// =============================================================================
// DebugUnit  -  Unidad de depuración / control del procesador vía UART
// -----------------------------------------------------------------------------
// FSM que maneja la interfaz externa del RISC-V (portada de debug_unit.v del
// proyecto MIPS de base, ahora en SystemVerilog y para datapath de 64 bits):
//
//   - Carga de programa: recibe los bytes del programa por UART, los ensambla
//     en words de 32 bits (instrucciones RISC-V) y los escribe en la memoria
//     de instrucciones del core (puerto i_imem_wr/addr/data).
//   - Ejecución continua: corre el pipeline hasta detectar HALT (i_halt) y
//     después vuelca el estado.
//   - Paso a paso: ejecuta exactamente un ciclo por comando y vuelca el estado.
//   - Volcado (dump): transmite PC, los 32 registros y la memoria de datos.
//
// Protocolo UART (8N1, MSB-first / big-endian), compatible con la GUI Python:
//   Comandos (1 byte): 1=WRITE_IM, 2=CONTINUE, 3=STEP_BY_STEP, 4=SEND_INFO, 5=STEP
//   Carga: tras 0x01, IM_WORDS instrucciones × 4 bytes (primero el byte más
//          significativo de cada instrucción).
//   Dump : PC (8 bytes) -> 32 registros × 8 bytes -> DM_DEPTH words × 8 bytes.
//
// Nota de temporización: la FSM corre en **flanco descendente** del reloj. El
// pipeline corre en flanco de subida y muestrea o_pipeline_enable / o_imem_wr;
// al actualizar la FSM en el flanco opuesto, esas señales quedan estables antes
// del flanco de subida que las usa (evita carreras). Es el patrón del MIPS de
// base, válido en FPGA.
// =============================================================================
module DebugUnit #(
    parameter int NB_DATA = 8,  // ancho de byte UART
    parameter int NB_PC = 64,  // ancho del PC
    parameter int DATA_WIDTH = 64,  // ancho de registros / memoria de datos
    parameter int NB_REG = 5,  // bits de dirección del banco de registros (32 regs)
    parameter int NB_IADDR = 8,  // bits de dirección de la memoria de instrucciones (word index)
    parameter int NB_INST = 32,  // ancho de instrucción
    parameter int NB_DADDR = 6,  // bits de dirección de la memoria de datos (64 words)
    parameter int IM_WORDS = 64,  // instrucciones del programa (debe coincidir con la GUI)
    parameter int RB_DEPTH = 32,  // cantidad de registros a volcar
    parameter int DM_DEPTH = 64  // cantidad de words de memoria de datos a volcar
) (
    input logic i_clk,
    input logic i_reset,

    // Estado del procesador
    input logic                  i_halt,      // HALT llegó a MEM (fin de programa)
    input logic [     NB_PC-1:0] i_pc,        // PC actual
    input logic [DATA_WIDTH-1:0] i_reg_data,  // registro leído en o_reg_addr
    input logic [DATA_WIDTH-1:0] i_mem_data,  // word de mem de datos leído en o_mem_data_addr

    // UART
    input  logic               i_rx_done,  // byte recibido
    input  logic               i_tx_done,  // byte transmitido
    input  logic [NB_DATA-1:0] i_rx_data,  // byte recibido
    output logic [NB_DATA-1:0] o_tx_data,  // byte a transmitir
    output logic               o_tx_start, // iniciar transmisión

    // Carga de memoria de instrucciones
    output logic                o_imem_wr,    // write enable a la IM del core
    output logic [NB_IADDR-1:0] o_imem_addr,  // índice de word de la IM
    output logic [ NB_INST-1:0] o_imem_data,  // instrucción ensamblada (32 bits)

    // Direcciones de lectura para el dump
    output logic [  NB_REG-1:0] o_reg_addr,      // registro a leer
    output logic [NB_DADDR-1:0] o_mem_data_addr, // word de mem de datos a leer

    // Control del pipeline
    output logic o_pipeline_enable,  // 1 = el core avanza; 0 = congelado

    // Estado de la FSM (one-hot, para LEDs de debug)
    output logic [7:0] o_state
);

    localparam int NB_BYTES = DATA_WIDTH / 8;  // bytes por valor del dump (= 8)

    // -------------------------------------------------------------------------
    // Comandos UART
    // -------------------------------------------------------------------------
    localparam logic [NB_DATA-1:0] CMD_WRITE_IM = 8'd1;
    localparam logic [NB_DATA-1:0] CMD_CONTINUE = 8'd2;
    localparam logic [NB_DATA-1:0] CMD_STEP_BY_STEP = 8'd3;
    localparam logic [NB_DATA-1:0] CMD_SEND_INFO = 8'd4;
    localparam logic [NB_DATA-1:0] CMD_STEP = 8'd5;

    // -------------------------------------------------------------------------
    // Estados (one-hot: cada estado enciende un LED distinto)
    // -------------------------------------------------------------------------
    typedef enum logic [7:0] {
        INITIAL   = 8'b0000_0001,  // reposo: espera WRITE_IM o SEND_INFO
        WRITE_IM  = 8'b0000_0010,  // recibiendo y escribiendo el programa
        READY     = 8'b0000_0100,  // programa cargado: espera CONTINUE / STEP_BY_STEP
        RUN       = 8'b0000_1000,  // ejecución continua hasta HALT
        STEP_MODE = 8'b0001_0000,  // paso a paso: espera STEP / CONTINUE
        SEND_PC   = 8'b0010_0000,  // transmitiendo el PC
        SEND_REG  = 8'b0100_0000,  // transmitiendo el banco de registros
        SEND_MEM  = 8'b1000_0000   // transmitiendo la memoria de datos
    } state_t;

    // -------------------------------------------------------------------------
    // Registros de estado
    // -------------------------------------------------------------------------
    state_t r_state, w_next_state;
    state_t r_prev, w_next_prev;  // estado al que volver tras el dump

    // Carga de IM
    logic [NB_IADDR-1:0] r_word_count, w_next_word_count;  // word actual
    logic [1:0] r_byte_in_word, w_next_byte_in_word;
    logic [NB_INST-1:0] r_im_acc, w_next_im_acc;  // acumulador de 4 bytes
    logic r_mem_wr, w_next_mem_wr;
    logic [NB_IADDR-1:0] r_im_addr, w_next_im_addr;
    logic [NB_INST-1:0] r_im_data, w_next_im_data;

    // Dump
    logic [2:0] r_byte_idx, w_next_byte_idx;  // byte dentro del valor (0..7)
    logic [NB_REG-1:0] r_reg_idx, w_next_reg_idx;  // registro actual (0..31)
    logic [NB_DADDR-1:0] r_mem_idx, w_next_mem_idx;  // word actual (0..63)

    // UART / control
    logic r_tx_start, w_next_tx_start;
    logic [NB_DATA-1:0] r_tx_data, w_next_tx_data;
    logic r_pipeline_enable, w_next_pipeline_enable;

    // -------------------------------------------------------------------------
    // Selección del byte MSB-first de un valor de DATA_WIDTH bits
    //   idx=0 -> byte más significativo ... idx=NB_BYTES-1 -> byte menos sig.
    // -------------------------------------------------------------------------
    function automatic logic [NB_DATA-1:0] msb_byte(input logic [DATA_WIDTH-1:0] val,
                                                    input logic [2:0] idx);
        msb_byte = val[(NB_BYTES-1-idx)*8+:8];
    endfunction

    // -------------------------------------------------------------------------
    // Bloque secuencial (flanco descendente, reset síncrono activo-alto)
    // -------------------------------------------------------------------------
    always_ff @(negedge i_clk) begin
        if (i_reset) begin
            r_state           <= INITIAL;
            r_prev            <= INITIAL;
            r_word_count      <= '0;
            r_byte_in_word    <= '0;
            r_im_acc          <= '0;
            r_mem_wr          <= 1'b0;
            r_im_addr         <= '0;
            r_im_data         <= '0;
            r_byte_idx        <= '0;
            r_reg_idx         <= '0;
            r_mem_idx         <= '0;
            r_tx_start        <= 1'b0;
            r_tx_data         <= '0;
            r_pipeline_enable <= 1'b0;
        end else begin
            r_state           <= w_next_state;
            r_prev            <= w_next_prev;
            r_word_count      <= w_next_word_count;
            r_byte_in_word    <= w_next_byte_in_word;
            r_im_acc          <= w_next_im_acc;
            r_mem_wr          <= w_next_mem_wr;
            r_im_addr         <= w_next_im_addr;
            r_im_data         <= w_next_im_data;
            r_byte_idx        <= w_next_byte_idx;
            r_reg_idx         <= w_next_reg_idx;
            r_mem_idx         <= w_next_mem_idx;
            r_tx_start        <= w_next_tx_start;
            r_tx_data         <= w_next_tx_data;
            r_pipeline_enable <= w_next_pipeline_enable;
        end
    end

    // -------------------------------------------------------------------------
    // Bloque combinacional de próximo estado
    // -------------------------------------------------------------------------
    always_comb begin
        // por defecto: mantener todo
        w_next_state           = r_state;
        w_next_prev            = r_prev;
        w_next_word_count      = r_word_count;
        w_next_byte_in_word    = r_byte_in_word;
        w_next_im_acc          = r_im_acc;
        w_next_mem_wr          = 1'b0;  // pulso: 0 por defecto
        w_next_im_addr         = r_im_addr;
        w_next_im_data         = r_im_data;
        w_next_byte_idx        = r_byte_idx;
        w_next_reg_idx         = r_reg_idx;
        w_next_mem_idx         = r_mem_idx;
        w_next_tx_start        = r_tx_start;
        w_next_tx_data         = r_tx_data;
        w_next_pipeline_enable = r_pipeline_enable;

        case (r_state)
            // --- Reposo --------------------------------------------------
            INITIAL: begin
                w_next_pipeline_enable = 1'b0;
                if (i_rx_done) begin
                    case (i_rx_data)
                        CMD_WRITE_IM: begin
                            w_next_state        = WRITE_IM;
                            w_next_word_count   = '0;
                            w_next_byte_in_word = '0;
                            w_next_im_acc       = '0;
                        end
                        CMD_SEND_INFO: begin
                            w_next_state    = SEND_PC;
                            w_next_prev     = INITIAL;
                            w_next_byte_idx = '0;
                        end
                        default: ;
                    endcase
                end
            end

            // --- Carga del programa --------------------------------------
            WRITE_IM: begin
                w_next_pipeline_enable = 1'b0;
                if (i_rx_done) begin
                    // ensamblar MSB-first: el 1er byte queda en [31:24]
                    w_next_im_acc = {r_im_acc[NB_INST-9:0], i_rx_data};
                    if (r_byte_in_word == 2'd3) begin
                        // 4to byte: escribir el word completo en la IM
                        w_next_mem_wr       = 1'b1;
                        w_next_im_addr      = r_word_count;
                        w_next_im_data      = {r_im_acc[NB_INST-9:0], i_rx_data};
                        w_next_byte_in_word = 2'd0;
                        if (r_word_count == NB_IADDR'(IM_WORDS - 1)) begin
                            w_next_state      = READY;
                            w_next_word_count = '0;
                        end else begin
                            w_next_word_count = r_word_count + 1'b1;
                        end
                    end else begin
                        w_next_byte_in_word = r_byte_in_word + 1'b1;
                    end
                end
            end

            // --- Programa cargado ----------------------------------------
            READY: begin
                w_next_pipeline_enable = 1'b0;
                if (i_rx_done) begin
                    case (i_rx_data)
                        CMD_CONTINUE:     w_next_state = RUN;
                        CMD_STEP_BY_STEP: w_next_state = STEP_MODE;
                        CMD_SEND_INFO: begin
                            w_next_state    = SEND_PC;
                            w_next_prev     = READY;
                            w_next_byte_idx = '0;
                        end
                        default:          ;
                    endcase
                end
            end

            // --- Ejecución continua --------------------------------------
            RUN: begin
                w_next_pipeline_enable = 1'b1;  // el core avanza
                if (i_halt) begin
                    w_next_state           = SEND_PC;
                    w_next_prev            = READY;  // tras el dump, queda listo
                    w_next_byte_idx        = '0;
                    w_next_pipeline_enable = 1'b0;
                end
            end

            // --- Paso a paso ---------------------------------------------
            STEP_MODE: begin
                w_next_pipeline_enable = 1'b0;  // congelado entre pasos
                if (i_halt) begin
                    w_next_state    = SEND_PC;
                    w_next_prev     = READY;
                    w_next_byte_idx = '0;
                end else if (i_rx_done) begin
                    case (i_rx_data)
                        CMD_STEP: begin
                            // avanza exactamente un ciclo: enable=1 ahora, y
                            // SEND_PC lo vuelve a 0 en el próximo flanco
                            w_next_pipeline_enable = 1'b1;
                            w_next_state           = SEND_PC;
                            w_next_prev            = STEP_MODE;
                            w_next_byte_idx        = '0;
                        end
                        CMD_CONTINUE: w_next_state = RUN;
                        CMD_SEND_INFO: begin
                            w_next_state    = SEND_PC;
                            w_next_prev     = STEP_MODE;
                            w_next_byte_idx = '0;
                        end
                        default:      ;
                    endcase
                end
            end

            // --- Dump: PC (8 bytes, MSB-first) ---------------------------
            SEND_PC: begin
                w_next_pipeline_enable = 1'b0;
                w_next_tx_start        = 1'b1;
                w_next_tx_data         = msb_byte(i_pc, r_byte_idx);
                if (i_tx_done) begin
                    w_next_tx_start = 1'b0;
                    if (r_byte_idx == 3'(NB_BYTES - 1)) begin
                        w_next_byte_idx = '0;
                        w_next_reg_idx  = '0;
                        w_next_state    = SEND_REG;
                    end else begin
                        w_next_byte_idx = r_byte_idx + 1'b1;
                    end
                end
            end

            // --- Dump: 32 registros × 8 bytes ----------------------------
            SEND_REG: begin
                w_next_pipeline_enable = 1'b0;
                w_next_tx_start        = 1'b1;
                w_next_tx_data         = msb_byte(i_reg_data, r_byte_idx);
                if (i_tx_done) begin
                    w_next_tx_start = 1'b0;
                    if (r_byte_idx == 3'(NB_BYTES - 1)) begin
                        w_next_byte_idx = '0;
                        if (r_reg_idx == NB_REG'(RB_DEPTH - 1)) begin
                            w_next_reg_idx = '0;
                            w_next_mem_idx = '0;
                            w_next_state   = SEND_MEM;
                        end else begin
                            w_next_reg_idx = r_reg_idx + 1'b1;
                        end
                    end else begin
                        w_next_byte_idx = r_byte_idx + 1'b1;
                    end
                end
            end

            // --- Dump: memoria de datos × 8 bytes ------------------------
            SEND_MEM: begin
                w_next_pipeline_enable = 1'b0;
                w_next_tx_start        = 1'b1;
                w_next_tx_data         = msb_byte(i_mem_data, r_byte_idx);
                if (i_tx_done) begin
                    w_next_tx_start = 1'b0;
                    if (r_byte_idx == 3'(NB_BYTES - 1)) begin
                        w_next_byte_idx = '0;
                        if (r_mem_idx == NB_DADDR'(DM_DEPTH - 1)) begin
                            w_next_mem_idx = '0;
                            w_next_state   = r_prev;  // vuelve al estado previo
                        end else begin
                            w_next_mem_idx = r_mem_idx + 1'b1;
                        end
                    end else begin
                        w_next_byte_idx = r_byte_idx + 1'b1;
                    end
                end
            end

            default: w_next_state = INITIAL;
        endcase
    end

    // -------------------------------------------------------------------------
    // Salidas
    // -------------------------------------------------------------------------
    assign o_tx_data         = r_tx_data;
    assign o_tx_start        = r_tx_start;
    assign o_imem_wr         = r_mem_wr;
    assign o_imem_addr       = r_im_addr;
    assign o_imem_data       = r_im_data;
    assign o_reg_addr        = r_reg_idx;
    assign o_mem_data_addr   = r_mem_idx;
    assign o_pipeline_enable = r_pipeline_enable;
    assign o_state           = r_state;

endmodule
