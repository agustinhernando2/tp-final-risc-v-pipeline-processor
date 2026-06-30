# 01_branches.s — Branches: BEQ no tomado y BNE tomado
#
# Qué demuestra: el manejo de hazards de control. Cuando un branch SE TOMA, las
# instrucciones que ya entraron al pipeline detrás de él se descartan (flush), así
# que la instrucción salteada nunca llega a escribir su resultado.
#
# Resultado esperado:  x5 = 111  (la del branch no tomado SÍ se ejecuta)
#                      x6 = 0    (la del branch tomado se saltea / flush)

        addi x1, x0, 7
        addi x2, x0, 7
        addi x3, x0, 9
        addi x5, x0, 0
        addi x6, x0, 0

        beq  x1, x3, skip_a   # 7 == 9 ? NO  -> branch NO tomado, sigue derecho
        addi x5, x5, 111      # se ejecuta      -> x5 = 111
skip_a:
        bne  x1, x3, fin      # 7 != 9 ? SÍ  -> branch TOMADO, salta a 'fin'
        addi x6, x6, 222      # NUNCA se ejecuta (queda detrás del branch tomado)
fin:
        halt
