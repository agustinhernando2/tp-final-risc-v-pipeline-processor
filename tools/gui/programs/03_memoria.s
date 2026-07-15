# 03_memoria.s — Memoria de datos: stores/loads y extensión de signo
#
# Qué demuestra: los distintos anchos de acceso a memoria (byte/half/word) y la
# diferencia entre carga CON signo (lb/lh, sign-extend) y SIN signo (lbu/lhu,
# zero-extend). También usa `lui` para armar una constante de 16 bits.
#
# Nota: la memoria de datos se direcciona por palabra (offset = índice de word).
#
# Resultado esperado:
#   mem[0] = 0x000000FF
#   x10 (lb  mem[0]) = -1   = 0xffffffff (sign-extend)
#   x11 (lbu mem[0]) = 255  (0x000000FF, sin signo)
#   mem[1] = 0x10008003
#   x12 (lh  mem[1]) = 0xffff8003 (sign-extend)
#   x13 (lhu mem[1]) = 0x00008003 (zero-extend)
#   x14 (lw mem[1]) = 0x10008003 (zero-extend)

        addi x1, x0, 255      # 0x000000FF
        sw   x1, 0(x0)        # mem[0] = 0x000000FF

        lb   x10, 0(x0)       # byte CON signo  -> 0xFF se interpreta como -1
        lbu  x11, 0(x0)       # byte SIN signo  -> 255

        lui  x2, 0x10008      # x2 = 0x10008000 lui carga la parte alta, los primeros 12 bits se carcan con addi
        addi x2, x2, 0x3      # x2 = 0x10008003
        sw   x2, 1(x0)
        lh   x12, 1(x0)
        lhu  x13, 1(x0)
        lw   x14, 1(x0)

        halt
