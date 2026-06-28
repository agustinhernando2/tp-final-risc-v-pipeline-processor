"""Tablas del set de instrucciones RISC-V y codificadores de bajo nivel.

Define EXACTAMENTE el subset RV32I que decodifica el hardware de este proyecto
(ver `src/sources_1/ID/ControlUnit.sv` y `src/sources_1/EX/ALUControl.sv`), más la
instrucción de parada custom `HALT`.

Acá vive toda la "matemática" del encoding (armar la palabra de 32 bits, con el
bit-scrambling de los inmediatos B/J), separada del parseo del ensamblador
(`assembler.py`). Eso lo hace fácil de leer y de testear de forma aislada.

Convención de campos de una instrucción RISC-V de 32 bits:

    R:  funct7[31:25] rs2[24:20] rs1[19:15] funct3[14:12] rd[11:7] opcode[6:0]
    I:  imm[31:20]               rs1[19:15] funct3[14:12] rd[11:7] opcode[6:0]
    S:  imm[31:25]    rs2[24:20] rs1[19:15] funct3[14:12] imm[11:7] opcode[6:0]
    B:  imm[31:25]    rs2[24:20] rs1[19:15] funct3[14:12] imm[11:7] opcode[6:0]  (bits revueltos)
    U:  imm[31:12]                                        rd[11:7] opcode[6:0]
    J:  imm[31:12]                                        rd[11:7] opcode[6:0]  (bits revueltos)
"""

# --- Opcodes (bits [6:0]) ----------------------------------------------------
OPCODE_RTYPE  = 0b0110011  # add, sub, ...
OPCODE_IARITH = 0b0010011  # addi, slli, ...
OPCODE_LOAD   = 0b0000011  # lb, lh, lw, ...
OPCODE_STORE  = 0b0100011  # sb, sh, sw
OPCODE_BRANCH = 0b1100011  # beq, bne, ...
OPCODE_JAL    = 0b1101111  # jal
OPCODE_JALR   = 0b1100111  # jalr
OPCODE_LUI    = 0b0110111  # lui
OPCODE_HALT   = 0b0001011  # custom-0: parada

# Palabra completa de HALT (toda la instrucción es 0x0000000B). Todo programa
# debe terminar con ella (ver docs/CONSIDERACIONES.md C-004).
HALT_WORD = 0x0000000B

# --- Registros: x0..x31 y alias ABI ------------------------------------------
_ABI = [
    "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
    "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
    "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
    "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6",
]
REGISTERS = {f"x{i}": i for i in range(32)}
REGISTERS.update({name: i for i, name in enumerate(_ABI)})
REGISTERS["fp"] = 8  # alias de s0

# --- Tablas por tipo de instrucción ------------------------------------------
# R-type:  mnemónico -> (funct3, funct7_bit5)   (bit 30 de la palabra)
R_TYPE = {
    "add":  (0b000, 0), "sub":  (0b000, 1),
    "sll":  (0b001, 0), "slt":  (0b010, 0), "sltu": (0b011, 0),
    "xor":  (0b100, 0), "srl":  (0b101, 0), "sra":  (0b101, 1),
    "or":   (0b110, 0), "and":  (0b111, 0),
}

# I-arith:  mnemónico -> (funct3, es_shift, funct7_bit5)
# En los shifts el inmediato es shamt[4:0] y funct7_bit5 distingue srli/srai.
I_ARITH = {
    "addi": (0b000, False, 0), "slti": (0b010, False, 0), "sltiu": (0b011, False, 0),
    "xori": (0b100, False, 0), "ori":  (0b110, False, 0), "andi":  (0b111, False, 0),
    "slli": (0b001, True, 0),  "srli": (0b101, True, 0),  "srai":  (0b101, True, 1),
}

# Loads / Stores / Branches:  mnemónico -> funct3
LOADS    = {"lb": 0b000, "lh": 0b001, "lw": 0b010, "lbu": 0b100, "lhu": 0b101, "lwu": 0b110}
STORES   = {"sb": 0b000, "sh": 0b001, "sw": 0b010}
BRANCHES = {"beq": 0b000, "bne": 0b001, "blt": 0b100, "bge": 0b101, "bltu": 0b110, "bgeu": 0b111}


# --- Codificadores: arman la palabra de 32 bits ------------------------------
# No validan rangos (de eso se encarga assembler.py, que reporta línea); asumen
# que registros e inmediatos ya vienen recortados al ancho correspondiente.

def encode_r(funct3, funct7_bit5, rd, rs1, rs2):
    funct7 = (funct7_bit5 & 1) << 5
    return ((funct7 << 25) | (rs2 << 20) | (rs1 << 15)
            | (funct3 << 12) | (rd << 7) | OPCODE_RTYPE)


def encode_i(opcode, funct3, rd, rs1, imm):
    return (((imm & 0xFFF) << 20) | (rs1 << 15)
            | (funct3 << 12) | (rd << 7) | opcode)


def encode_i_shift(funct3, funct7_bit5, rd, rs1, shamt):
    """I-type de shift: imm[11:5] lleva funct7, imm[4:0] el shamt."""
    imm = ((funct7_bit5 & 1) << 10) | (shamt & 0x1F)
    return encode_i(OPCODE_IARITH, funct3, rd, rs1, imm)


def encode_s(funct3, rs1, rs2, imm):
    imm &= 0xFFF
    return (((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15)
            | (funct3 << 12) | ((imm & 0x1F) << 7) | OPCODE_STORE)


def encode_b(funct3, rs1, rs2, imm):
    """B-type: el offset (en bytes) se reparte en bits revueltos; el LSB se
    descarta (los destinos están alineados a 2 bytes)."""
    imm &= 0x1FFF  # 13 bits con signo
    return ((((imm >> 12) & 1) << 31) | (((imm >> 5) & 0x3F) << 25)
            | (rs2 << 20) | (rs1 << 15) | (funct3 << 12)
            | (((imm >> 1) & 0xF) << 8) | (((imm >> 11) & 1) << 7) | OPCODE_BRANCH)


def encode_u(rd, imm):
    """U-type (lui): imm es el valor de 20 bits que va a parar a inst[31:12]."""
    return ((imm & 0xFFFFF) << 12) | (rd << 7) | OPCODE_LUI


def encode_j(rd, imm):
    """J-type (jal): offset en bytes con bits revueltos; LSB descartado."""
    imm &= 0x1FFFFF  # 21 bits con signo
    return ((((imm >> 20) & 1) << 31) | (((imm >> 1) & 0x3FF) << 21)
            | (((imm >> 11) & 1) << 20) | (((imm >> 12) & 0xFF) << 12)
            | (rd << 7) | OPCODE_JAL)
