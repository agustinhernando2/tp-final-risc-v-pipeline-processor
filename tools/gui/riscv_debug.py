#!/usr/bin/env python3
"""CLI de depuración del procesador RISC-V vía UART (Stage 9b).

Carga programas, ejecuta en modo continuo o paso a paso, y muestra el volcado de
estado (PC, registros, memoria de datos).

Acepta dos formatos de entrada en `load`/`loadrun`, según la extensión:
  - `.s` / `.asm`  -> assembly, se ensambla en el momento con `assembler.py`.
  - cualquier otra  -> código máquina hex (formato $readmemh: un word de 32 bits
                       por línea). La instrucción de parada es HALT = 0x0000000B.

Dependencias:  pip install pyserial

Ejemplos:
    # cargar y correr de una, mostrando el estado final
    python riscv_debug.py --port /dev/ttyUSB1 loadrun programa.hex

    # cargar, después correr en invocaciones separadas
    python riscv_debug.py --port /dev/ttyUSB1 load programa.hex
    python riscv_debug.py --port /dev/ttyUSB1 run

    # volcar estado sin ejecutar / un paso
    python riscv_debug.py --port /dev/ttyUSB1 info
    python riscv_debug.py --port /dev/ttyUSB1 step
"""

import argparse
import sys

try:
    import assembler
    from uart import Uart, CMD_CONTINUE, CMD_SEND_INFO, CMD_STEP_BY_STEP, CMD_STEP
except ImportError:
    sys.exit("No se encontró uart.py/assembler.py (corré el script desde tools/gui/) o falta pyserial.")


def parse_hex_program(path):
    """Lee un archivo con un word hexadecimal de 32 bits por línea.
    Ignora líneas vacías, comentarios (# o //) y el prefijo 0x."""
    words = []
    with open(path) as f:
        for raw in f:
            line = raw.split("#", 1)[0].split("//", 1)[0].strip()
            if not line:
                continue
            line = line[2:] if line.lower().startswith("0x") else line
            words.append(int(line, 16) & 0xFFFFFFFF)
    return words


def load_program(path):
    """Ensambla (.s/.asm) o parsea hex según la extensión del archivo."""
    if path.lower().endswith((".s", ".asm")):
        try:
            return assembler.assemble_file(path)
        except assembler.AssemblerError as e:
            sys.exit(f"error de ensamblado en {path}: {e}")
    return parse_hex_program(path)


def print_dump(pc, regs, mem):
    print(f"PC = 0x{pc:016x}")
    print("Registros:")
    for i, v in enumerate(regs):
        print(f"  x{i:<2} = 0x{v:016x} ({v})")
    print("Memoria de datos (words distintos de 0):")
    any_mem = False
    for i, v in enumerate(mem):
        if v != 0:
            print(f"  [{i:<2}] = 0x{v:016x} ({v})")
            any_mem = True
    if not any_mem:
        print("  (todo en 0)")


def main():
    ap = argparse.ArgumentParser(description="CLI de debug RISC-V vía UART.")
    ap.add_argument("--port", required=True, help="Puerto serie, ej. /dev/ttyUSB1")
    ap.add_argument("--baud", type=int, default=19200)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("run", help="ejecución continua hasta HALT + dump")
    sub.add_parser("info", help="volcar estado sin ejecutar")
    sub.add_parser("step", help="entrar en paso a paso y ejecutar un ciclo + dump")
    p_load = sub.add_parser("load", help="cargar un programa hex")
    p_load.add_argument("file")
    p_loadrun = sub.add_parser("loadrun", help="cargar + ejecutar + dump")
    p_loadrun.add_argument("file")

    args = ap.parse_args()
    u = Uart(args.port, args.baud)
    try:
        if args.cmd in ("load", "loadrun"):
            words = load_program(args.file)
            print(f"Cargando {len(words)} instrucción(es) desde {args.file}...")
            u.send_program(words)
            if args.cmd == "load":
                print("Programa cargado (estado READY).")
                return

        if args.cmd == "info":
            u.send_command(CMD_SEND_INFO)
        elif args.cmd == "step":
            u.send_command(CMD_STEP_BY_STEP)
            u.send_command(CMD_STEP)
        else:  # run / loadrun
            u.send_command(CMD_CONTINUE)

        print("Esperando dump...")
        pc, regs, mem = u.receive_dump()
        print_dump(pc, regs, mem)
    finally:
        u.close()


if __name__ == "__main__":
    main()
