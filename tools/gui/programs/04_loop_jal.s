# 04_loop_jal.s - Bucle con branch hacia atrás + subrutina con JAL/JALR
#
# Qué demuestra: un bucle controlado por un branch hacia atrás (acumula una suma)
# y una llamada a subrutina con JAL (guarda la dirección de retorno en ra) que
# vuelve con JALR x0, 0(ra).
#
# Nota: la memoria de datos se direcciona por palabra (offset = índice de word).
#
# Resultado esperado:  x5 = 15 (1+2+3+4+5), mem[0] = 15,
#                      x10 = 30 (duplicado por la subrutina), mem[1] = 30

        addi x1, x0, 5        # contador i = 5
        addi x5, x0, 0        # acumulador = 0
loop:
        add  x5, x5, x1       # acc += i
        addi x1, x1, -1       # i--
        bne  x1, x0, loop     # repetir mientras i != 0  (branch hacia atrás)

        sw   x5, 0(x0)        # mem[0] = 15

        addi x10, x5, 0       # argumento de la subrutina = 15
        jal  ra, doble        # llamar 'doble' (retorno -> ra)
        sw   x10, 1(x0)       # mem[1] = 30
        halt

doble:                        # subrutina: x10 = x10 * 2
        add  x10, x10, x10
        jalr x0, 0(ra)        # vuelve a quien llamó
