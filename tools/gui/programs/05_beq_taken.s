# 05_beq_taken.s — BEQ siempre tomado (x0 == x0)
#
# Demuestra el flush por salto tomado. El branch resuelve en MEM (4to ciclo de
# su vida en el pipeline), descartando las instrucciones que entraron detrás.
#
# Esperado:  x6 = 0   (la addi de abajo se saltea/flush)
#            x8 = 3

        beq  x0, x0, fin     # 0x00  siempre tomado -> salta a fin
        addi x6, x6, 222     # 0x04  NUNCA se ejecuta (flush)
fin:
        addi x8, x0, 3       # 0x08  x8 = 3
        halt                 # 0x0C
