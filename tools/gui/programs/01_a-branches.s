        addi x1, x0, 7
        addi x2, x0, 5
back:
        addi x2, x2, 1 
        beq  x1, x2, fin     
        bne  x1, x2, back     
fin:
        halt
