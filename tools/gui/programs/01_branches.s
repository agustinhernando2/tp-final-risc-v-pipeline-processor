# 01_branches.s Branches: BEQ no tomado inicialmente y BNE tomado
#
# resultados esperados
# x1: 7 
# x2: 7
# x3: 12
# x4: 0

        addi x1, x0, 7
        addi x2, x0, 5
	add  x3, x1, x2
back:
        addi x2, x2, 1 
        beq  x1, x2, fin     
        bne  x1, x2, back     
        addi x4, x3, 3
fin:
        halt

