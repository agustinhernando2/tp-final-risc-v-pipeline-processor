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
#   x10 (lb  mem[0]) = -1   (0xFF con signo: bits altos en 1)
#   x11 (lbu mem[0]) = 255  (0x000000FF, sin signo)
#   mem[1] = 0x00008000
#   x12 (lh  mem[1]) negativo (bit 15 en 1, sign-extend)
#   x13 (lhu mem[1]) = 0x00008000 (zero-extend)

        li   x1, 255          # 0x000000FF
        sw   x1, 0(x0)        # mem[0] = 0x000000FF

        lb   x10, 0(x0)       # byte CON signo  -> 0xFF se interpreta como -1
        lbu  x11, 0(x0)       # byte SIN signo  -> 255

        lui  x2, 0x8          # x2 = 0x00008000 (bit 15 en 1)
        sw   x2, 1(x0)        # mem[1] = 0x00008000
        lh   x12, 1(x0)       # halfword CON signo -> negativo
        lhu  x13, 1(x0)       # halfword SIN signo -> 0x00008000
        lw   x14, 1(x0)       # word completo      -> 0x00008000

        sh   x1, 2(x0)        # store halfword -> mem[2] = 0x00FF
        sb   x1, 3(x0)        # store byte     -> mem[3] = 0xFF
        halt
