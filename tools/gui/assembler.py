#!/usr/bin/env python3
"""Ensamblador RISC-V para el procesador de este proyecto.

Traduce texto assembly (ej. `addi x1, x0, 5`) a código máquina de 32 bits, listo
para cargar en la `InstructionMemory` vía la GUI/CLI o para volcar a un `.hex`
(formato `$readmemh`).

Soporta el subset RV32I que decodifica el hardware (ver `isa.py`), labels para
saltos/branches, y un puñado de pseudo-instrucciones. Trabaja en dos pasadas:

    1) registra las labels (`nombre:`) con el índice de instrucción al que apuntan;
    2) codifica cada instrucción, resolviendo los offsets de branch/jal en bytes
       (PC byte-direccionado, +4 por instrucción — ver docs/CONSIDERACIONES.md C-001).

Uso como librería:
    from assembler import assemble, assemble_file
    words = assemble("addi x1, x0, 5\\nhalt")

Uso como CLI:
    python assembler.py entrada.s              # imprime el hex por stdout
    python assembler.py entrada.s -o salida.hex # escribe el .hex
"""

import re
import sys

import isa


class AssemblerError(Exception):
    """Error de ensamblado con número de línea para mensajes claros."""

    def __init__(self, lineno, message):
        super().__init__(f"línea {lineno}: {message}")
        self.lineno = lineno


# --- Parseo de operandos -----------------------------------------------------

def _reg(token, lineno):
    name = token.strip().lower()
    if name not in isa.REGISTERS:
        raise AssemblerError(lineno, f"registro inválido: '{token}'")
    return isa.REGISTERS[name]


def _imm(token, lineno):
    """Inmediato numérico: decimal, hex (0x), binario (0b) o negativo."""
    t = token.strip().lower()
    try:
        return int(t, 0)  # int con base 0 reconoce 0x / 0b / decimal y signo
    except ValueError:
        raise AssemblerError(lineno, f"inmediato inválido: '{token}'")


def _check_range(value, lineno, lo, hi, what, even=False):
    if value < lo or value > hi:
        raise AssemblerError(lineno, f"{what} fuera de rango [{lo}, {hi}]: {value}")
    if even and value % 2 != 0:
        raise AssemblerError(lineno, f"{what} debe ser par (alineado a 2 bytes): {value}")


_MEM_RE = re.compile(r"^\s*(?P<off>[^()]+?)?\s*\(\s*(?P<reg>\w+)\s*\)\s*$")


def _mem(token, lineno):
    """Parsea un operando de memoria `offset(reg)`. Devuelve (offset, reg_idx)."""
    m = _MEM_RE.match(token)
    if not m:
        raise AssemblerError(lineno, f"se esperaba 'offset(reg)', se obtuvo '{token}'")
    off = _imm(m.group("off"), lineno) if m.group("off") else 0
    return off, _reg(m.group("reg"), lineno)


def _split_operands(rest):
    """Separa la parte de operandos por comas, descartando vacíos."""
    return [op.strip() for op in rest.split(",") if op.strip()]


def _need(ops, n, mnemonic, lineno):
    if len(ops) != n:
        raise AssemblerError(
            lineno, f"'{mnemonic}' espera {n} operando(s), recibió {len(ops)}")


# --- Pasada 1: tokenizar y registrar labels ----------------------------------

_LABEL_RE = re.compile(r"^([A-Za-z_]\w*)\s*:\s*")


def _strip_comment(line):
    return line.split("#", 1)[0].split("//", 1)[0].strip()


def _first_pass(text):
    """Devuelve (instrucciones, labels).

    instrucciones: lista de (idx, mnemonic, operands, lineno).
    labels: dict nombre -> idx de la instrucción a la que apunta.
    """
    instructions = []
    labels = {}
    idx = 0
    for lineno, raw in enumerate(text.splitlines(), start=1):
        line = _strip_comment(raw)
        # Una línea puede tener varias labels al frente: "a: b: instr".
        while True:
            m = _LABEL_RE.match(line)
            if not m:
                break
            name = m.group(1)
            if name in labels:
                raise AssemblerError(lineno, f"label duplicada: '{name}'")
            labels[name] = idx
            line = line[m.end():].strip()
        if not line:
            continue
        parts = line.split(None, 1)
        mnemonic = parts[0].lower()
        operands = _split_operands(parts[1]) if len(parts) > 1 else []
        instructions.append((idx, mnemonic, operands, lineno))
        idx += 1
    return instructions, labels


# --- Pasada 2: codificar -----------------------------------------------------

def _resolve_target(operand, cur_idx, labels, lineno):
    """Resuelve el offset en bytes de un branch/jal: acepta una label o un
    offset numérico (en bytes) directo."""
    operand = operand.strip()
    if operand in labels:
        return (labels[operand] - cur_idx) * 4
    if re.match(r"^[A-Za-z_]\w*$", operand):
        raise AssemblerError(lineno, f"label no definida: '{operand}'")
    return _imm(operand, lineno)


def _encode_one(idx, mnemonic, ops, lineno, labels):
    # --- Pseudo-instrucciones (se reescriben a instrucciones reales) ---------
    if mnemonic == "nop":
        _need(ops, 0, "nop", lineno)
        return isa.encode_i(isa.OPCODE_IARITH, 0b000, 0, 0, 0)  # addi x0, x0, 0
    if mnemonic == "halt":
        _need(ops, 0, "halt", lineno)
        return isa.HALT_WORD
    if mnemonic == "j":  # j label  ->  jal x0, label
        _need(ops, 1, "j", lineno)
        mnemonic, ops = "jal", ["x0", ops[0]]
    if mnemonic == "mv":  # mv rd, rs  ->  addi rd, rs, 0
        _need(ops, 2, "mv", lineno)
        mnemonic, ops = "addi", [ops[0], ops[1], "0"]
    if mnemonic == "li":  # li rd, imm  ->  addi rd, x0, imm (sólo 12 bits)
        _need(ops, 2, "li", lineno)
        val = _imm(ops[1], lineno)
        if not (-2048 <= val <= 2047):
            raise AssemblerError(
                lineno, f"li sólo soporta inmediatos de 12 bits con signo; usá lui para {val}")
        mnemonic, ops = "addi", [ops[0], "x0", ops[1]]
    if mnemonic in ("beqz", "bnez"):  # b*z rs, label  ->  b* rs, x0, label
        _need(ops, 2, mnemonic, lineno)
        mnemonic, ops = ("beq" if mnemonic == "beqz" else "bne"), [ops[0], "x0", ops[1]]
    if mnemonic == "ret":  # ret  ->  jalr x0, 0(ra)
        _need(ops, 0, "ret", lineno)
        mnemonic, ops = "jalr", ["x0", "0(ra)"]

    # --- Instrucciones reales ------------------------------------------------
    if mnemonic in isa.R_TYPE:
        _need(ops, 3, mnemonic, lineno)
        funct3, funct7 = isa.R_TYPE[mnemonic]
        return isa.encode_r(funct3, funct7,
                            _reg(ops[0], lineno), _reg(ops[1], lineno), _reg(ops[2], lineno))

    if mnemonic in isa.I_ARITH:
        _need(ops, 3, mnemonic, lineno)
        funct3, is_shift, funct7 = isa.I_ARITH[mnemonic]
        rd, rs1 = _reg(ops[0], lineno), _reg(ops[1], lineno)
        imm = _imm(ops[2], lineno)
        if is_shift:
            _check_range(imm, lineno, 0, 31, "shamt")
            return isa.encode_i_shift(funct3, funct7, rd, rs1, imm)
        _check_range(imm, lineno, -2048, 2047, "inmediato")
        return isa.encode_i(isa.OPCODE_IARITH, funct3, rd, rs1, imm)

    if mnemonic in isa.LOADS:
        _need(ops, 2, mnemonic, lineno)
        rd = _reg(ops[0], lineno)
        off, rs1 = _mem(ops[1], lineno)
        _check_range(off, lineno, -2048, 2047, "offset")
        return isa.encode_i(isa.OPCODE_LOAD, isa.LOADS[mnemonic], rd, rs1, off)

    if mnemonic in isa.STORES:
        _need(ops, 2, mnemonic, lineno)
        rs2 = _reg(ops[0], lineno)
        off, rs1 = _mem(ops[1], lineno)
        _check_range(off, lineno, -2048, 2047, "offset")
        return isa.encode_s(isa.STORES[mnemonic], rs1, rs2, off)

    if mnemonic in isa.BRANCHES:
        _need(ops, 3, mnemonic, lineno)
        rs1, rs2 = _reg(ops[0], lineno), _reg(ops[1], lineno)
        off = _resolve_target(ops[2], idx, labels, lineno)
        _check_range(off, lineno, -4096, 4095, "offset de branch", even=True)
        return isa.encode_b(isa.BRANCHES[mnemonic], rs1, rs2, off)

    if mnemonic == "jal":
        _need(ops, 2, "jal", lineno)
        rd = _reg(ops[0], lineno)
        off = _resolve_target(ops[1], idx, labels, lineno)
        _check_range(off, lineno, -(1 << 20), (1 << 20) - 1, "offset de jal", even=True)
        return isa.encode_j(rd, off)

    if mnemonic == "jalr":
        _need(ops, 2, "jalr", lineno)
        rd = _reg(ops[0], lineno)
        off, rs1 = _mem(ops[1], lineno)
        _check_range(off, lineno, -2048, 2047, "offset")
        return isa.encode_i(isa.OPCODE_JALR, 0b000, rd, rs1, off)

    if mnemonic == "lui":
        _need(ops, 2, "lui", lineno)
        rd = _reg(ops[0], lineno)
        imm = _imm(ops[1], lineno)
        _check_range(imm, lineno, 0, 0xFFFFF, "inmediato de lui")
        return isa.encode_u(rd, imm)

    raise AssemblerError(lineno, f"instrucción desconocida: '{mnemonic}'")


# --- API pública -------------------------------------------------------------

def assemble(text):
    """Ensambla `text` y devuelve la lista de instrucciones (enteros de 32 bits).

    No agrega padding: devuelve solo las instrucciones reales (el padding a 64
    words lo hace `uart.send_program()` al enviar a la placa)."""
    instructions, labels = _first_pass(text)
    return [_encode_one(idx, mnemonic, ops, lineno, labels)
            for idx, mnemonic, ops, lineno in instructions]


def assemble_file(path):
    with open(path) as f:
        return assemble(f.read())


def to_hex_lines(words):
    """Formatea las instrucciones como líneas hex de 8 dígitos (formato $readmemh)."""
    return [f"{w:08x}" for w in words]


# --- CLI ---------------------------------------------------------------------

def main():
    import argparse
    ap = argparse.ArgumentParser(description="Ensamblador RISC-V (.s -> hex).")
    ap.add_argument("source", help="archivo assembly de entrada (.s/.asm)")
    ap.add_argument("-o", "--output", help="archivo .hex de salida (default: stdout)")
    args = ap.parse_args()
    try:
        words = assemble_file(args.source)
    except AssemblerError as e:
        sys.exit(f"error de ensamblado en {args.source}: {e}")
    lines = to_hex_lines(words)
    if args.output:
        with open(args.output, "w") as f:
            f.write("\n".join(lines) + "\n")
        print(f"{len(words)} instrucción(es) -> {args.output}")
    else:
        print("\n".join(lines))


if __name__ == "__main__":
    main()
