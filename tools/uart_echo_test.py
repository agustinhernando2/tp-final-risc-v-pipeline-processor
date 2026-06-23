#!/usr/bin/env python3
"""Test de eco (loopback) para la UART del procesador RISC-V — Stage 9a.

Envía una secuencia de bytes por el puerto serie y verifica que el FPGA
(corriendo UartLoopbackTop) los reenvíe idénticos.

Config serie: 19200 baud, 8 bits de datos, sin paridad, 1 stop bit (8N1),
igual que la referencia MIPS (GUI/uart.py) para poder reusar herramientas en 9b.

Dependencias:
    pip install pyserial

Uso:
    python tools/uart_echo_test.py --port /dev/ttyUSB1
    python tools/uart_echo_test.py --port /dev/ttyUSB1 --text "Hola RISC-V"
    python tools/uart_echo_test.py --port /dev/ttyUSB1 --baud 19200

Tip: para encontrar el puerto, conectá la placa y corré `ls /dev/ttyUSB*`.
"""

import argparse
import sys
import time

try:
    import serial  # pyserial
except ImportError:
    sys.exit("Falta pyserial. Instalalo con: pip install pyserial")


def open_port(port, baud):
    """Abre el puerto serie con la config 8N1 estándar."""
    return serial.Serial(
        port=port,
        baudrate=baud,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        bytesize=serial.EIGHTBITS,
        timeout=2.0,  # segundos de espera por byte de eco
    )


def echo_test(ser, payload):
    """Envía payload byte a byte y compara con el eco recibido.

    Se hace byte por byte (enviar, esperar el eco) para que un fallo señale
    exactamente en qué byte se rompió la comunicación.
    """
    ok = 0
    for i, tx in enumerate(payload):
        ser.write(bytes([tx]))
        rx = ser.read(1)
        if len(rx) == 0:
            print(f"[{i:3}] TX=0x{tx:02X}  ->  TIMEOUT (no llegó eco)")
            return False, ok
        rx = rx[0]
        status = "OK" if rx == tx else "MISMATCH"
        if rx == tx:
            ok += 1
        else:
            print(f"[{i:3}] TX=0x{tx:02X}  RX=0x{rx:02X}  {status}")
            return False, ok
    return True, ok


def main():
    ap = argparse.ArgumentParser(description="Test de eco UART (Stage 9a).")
    ap.add_argument("--port", required=True, help="Puerto serie, ej. /dev/ttyUSB1")
    ap.add_argument("--baud", type=int, default=19200, help="Baud rate (default 19200)")
    ap.add_argument("--text", default=None, help="Enviar este texto en vez de 0x00..0xFF")
    args = ap.parse_args()

    if args.text is not None:
        payload = args.text.encode("utf-8")
    else:
        payload = bytes(range(256))  # barrido completo 0x00..0xFF

    print(f"Abriendo {args.port} @ {args.baud} baud (8N1)...")
    with open_port(args.port, args.baud) as ser:
        # Pequeña pausa para que el puente USB-UART se estabilice.
        time.sleep(0.2)
        ser.reset_input_buffer()
        ser.reset_output_buffer()

        print(f"Enviando {len(payload)} byte(s) y verificando eco...")
        passed, ok = echo_test(ser, payload)

    print("-" * 40)
    print(f"Bytes correctos: {ok}/{len(payload)}")
    if passed:
        print("RESULTADO: PASS ✔  La UART hace eco correctamente.")
        sys.exit(0)
    else:
        print("RESULTADO: FAIL  Revisar baud rate, pines (B18/A18) o el bitstream.")
        sys.exit(1)


if __name__ == "__main__":
    main()
