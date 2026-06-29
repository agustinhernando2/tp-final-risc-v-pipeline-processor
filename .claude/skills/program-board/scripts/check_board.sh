#!/usr/bin/env bash
# =============================================================================
# check_board.sh  -  Chequeo previo del entorno antes de programar / probar UART
# -----------------------------------------------------------------------------
# Verifica que la Basys-3 este enumerada, lista los puertos serie y avisa de los
# dos problemas tipicos: cable Digilent sin drivers y pyserial instalado en otro
# interprete de Python (el que corre el test debe ser el mismo que tiene serial).
# No modifica nada; solo informa.
# =============================================================================
set -u

echo "=== 1) Placa en USB (FT2232 = 0403:6010) ==="
if lsusb 2>/dev/null | grep -iE "0403:6010|digilent|future technology"; then
    echo "   OK: la placa enumera."
else
    echo "   NO aparece. Conectala al puerto PROG/UART y encendela (LED POWER)."
    echo "   Si sigue sin verse -> drivers del cable Digilent (skill vivado-linux-debug)."
fi

echo
echo "=== 2) Puertos serie ==="
# En la Basys-3 el FT2232 expone 2 canales: ttyUSB0=JTAG, ttyUSB1=UART.
if ls /dev/ttyUSB* >/dev/null 2>&1; then
    ls -l /dev/ttyUSB*
    echo "   -> Para el test de UART usar el SEGUNDO (normalmente /dev/ttyUSB1)."
else
    echo "   No hay /dev/ttyUSB*. Revisar conexion/drivers."
fi

echo
echo "=== 3) pyserial en el python3 que corre el test ==="
if python3 -c "import serial; print('   OK pyserial', serial.__version__)" 2>/dev/null; then
    :
else
    echo "   FALTA pyserial en: $(command -v python3)"
    echo "   Instalar EN ESE interprete (ojo si hay varios python3, ej. brew vs sistema):"
    echo "     python3 -m pip install --break-system-packages pyserial"
fi
