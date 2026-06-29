"""Capa de comunicación UART con el procesador RISC-V (Stage 9b).

Implementa el protocolo de la DebugUnit (src/sources_1/Debug/DebugUnit.sv):

  Comandos (1 byte):
      1 = WRITE_IM       cargar programa
      2 = CONTINUE       ejecución continua hasta HALT
      3 = STEP_BY_STEP   entrar en modo paso a paso
      4 = SEND_INFO      volcar estado sin ejecutar
      5 = STEP           ejecutar un ciclo

  Carga: tras 0x01 se envían IM_WORDS instrucciones × 4 bytes, MSB-first.
  Dump : PC (4 bytes) -> 32 registros × 4 bytes -> DM_DEPTH words × 4 bytes,
         todo MSB-first / big-endian.

Config serie: 19200 8N1 (igual que el MIPS de base, para reusar herramientas).

El datapath RISC-V es de 32 bits (DATA_WIDTH=32). La DebugUnit dumpea cada valor
(incluido el PC) a ancho NB_BYTES = DATA_WIDTH/8 = 4 bytes; del PC de 64 bits se
mandan solo los 32 bits bajos (suficiente: el PC nunca supera el rango de la IMEM).
WORD_BYTES = PC_BYTES = DATA_WIDTH/8; si se cambia DATA_WIDTH, actualizar acá.
"""

import serial

# --- Comandos (deben coincidir con DebugUnit.sv) -----------------------------
CMD_WRITE_IM     = 1
CMD_CONTINUE     = 2
CMD_STEP_BY_STEP = 3
CMD_SEND_INFO    = 4
CMD_STEP         = 5

# --- Geometría del dump (debe coincidir con los parámetros de RiscvTop) -------
IM_WORDS   = 64    # instrucciones del programa (con padding)
N_REG      = 32    # registros volcados
N_MEM      = 64    # words de memoria de datos volcados
WORD_BYTES = 4     # 32 bits por valor del dump (DATA_WIDTH=32)
PC_BYTES   = 4     # el dump del PC usa NB_BYTES=DATA_WIDTH/8 -> 4 bytes (los 32 bits
                   # bajos del PC; NB_PC=64 pero la FSM dumpea a ancho de valor)


class Uart:
    def __init__(self, port, baud=19200):
        self.ser = serial.Serial(
            port=port,
            baudrate=baud,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            bytesize=serial.EIGHTBITS,
            timeout=5.0,
        )

    def close(self):
        self.ser.close()

    # --- Envío -------------------------------------------------------------
    def send_command(self, cmd):
        self.ser.write(bytes([cmd & 0xFF]))

    def send_program(self, words):
        """Envía la lista de instrucciones (enteros de 32 bits), MSB-first,
        con padding de ceros hasta IM_WORDS."""
        if len(words) > IM_WORDS:
            raise ValueError(f"programa de {len(words)} words; el máximo es {IM_WORDS}")
        padded = list(words) + [0] * (IM_WORDS - len(words))
        self.send_command(CMD_WRITE_IM)
        for w in padded:
            self.ser.write(bytes([(w >> 24) & 0xFF, (w >> 16) & 0xFF,
                                   (w >> 8) & 0xFF, w & 0xFF]))

    # --- Recepción ---------------------------------------------------------
    def _read_word(self, nbytes=WORD_BYTES):
        """Lee nbytes bytes MSB-first y los arma en un entero."""
        raw = self.ser.read(nbytes)
        if len(raw) != nbytes:
            raise TimeoutError("timeout leyendo un word del dump")
        value = 0
        for b in raw:
            value = (value << 8) | b
        return value

    def receive_dump(self):
        """Lee el dump completo. Devuelve (pc, regs[N_REG], mem[N_MEM]).

        El PC son PC_BYTES (8, NB_PC=64); cada registro/word de memoria son
        WORD_BYTES (4, DATA_WIDTH=32).
        """
        pc = self._read_word(PC_BYTES)
        regs = [self._read_word() for _ in range(N_REG)]
        mem = [self._read_word() for _ in range(N_MEM)]
        return pc, regs, mem
