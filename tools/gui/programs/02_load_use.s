# 02_load_use.s  Dependencia lectura-tras-escritura (RAW) y load-use
#
# El `addi` necesita el resultado del `lw`, que todavía
# está viajando por el pipeline: el hardware inserta una burbuja (stall load-use) y
# luego hace forwarding del dato. El resultado final debe ser correcto igual.
#
# Nota: la memoria de datos se direcciona por palabra (offset = índice de word).
#
# Resultado:  
# x1 = 10, 
# mem[0] = 10, 
# x3 = 10 (leído), 
# x4 = 15 (10 + 5)

        addi x1, x0, 10
        sw   x1, 0(x0)
        lw   x3, 0(x0)
        addi x4, x3, 5
        halt
