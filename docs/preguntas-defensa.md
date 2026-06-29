# Preguntas probables de defensa

---

## 1. Pipeline general

**P: ¿Por qué un pipeline de 5 etapas y cuáles son?**
Seguimos el modelo clásico de Patterson & Hennessy: IF (busco la instrucción en memoria), ID (la decodifico, leo el register file y genero los inmediatos y señales de control), EX (la ALU hace la operación o calcula la dirección efectiva), MEM (accedo a memoria de datos en loads/stores) y WB (escribo el resultado de vuelta al register file). La idea del pipeline es solapar etapas: mientras una instrucción está en EX, la siguiente está en ID y la otra en IF, así tengo idealmente una instrucción terminando por ciclo en vez de esperar 5 ciclos por instrucción.

**P: ¿Qué separa una etapa de otra?**
Buffers de pipeline: IF/ID, ID/EX, EX/MEM y MEM/WB. Son registros que capturan en el flanco de clock todo lo que la etapa siguiente necesita (datos, señales de control, PC, etc.). Sin ellos no habría pipeline, todo sería combinacional.

**P: El PC, ¿de cuántos bits es y por qué incrementa de a 4?**
El datapath es de 32 bits (RV32) pero el PC lo mantengo de 64. Incrementa de a 4 porque está direccionado a byte, igual que en el libro: las instrucciones RISC-V son de 32 bits = 4 bytes, entonces la siguiente instrucción está 4 bytes más adelante. La memoria de instrucciones internamente indexa con `PC >> 2` porque está organizada en palabras.

---

## 2. Hazards de datos (forwarding + stall)

**P: ¿Qué es un hazard de datos y cómo lo resolvés?**
Es cuando una instrucción necesita un dato que todavía no se escribió en el register file porque la instrucción que lo produce sigue en el pipeline. Lo resuelvo con la **Forwarding Unit**: en vez de esperar a que el dato llegue a WB, lo adelanto desde EX/MEM o MEM/WB directo a las entradas de la ALU. Así evito stalls en la mayoría de los casos.

**P: ¿El forwarding resuelve todos los casos?**
No. El caso que el forwarding no puede salvar es el **load-use hazard**: una instrucción que usa el resultado de un load justo después. El dato del load recién está disponible al final de MEM, pero la instrucción siguiente lo necesitaría al inicio de EX, y no puedo adelantar hacia atrás en el tiempo. Ahí la **Hazard Detection Unit** mete un stall de un ciclo (burbuja) y después el forwarding completa el adelanto. Es el único caso que cuesta un ciclo.

**P: ¿Cómo se hace el stall físicamente?**
Congelo el PC y el buffer IF/ID (no avanzan), e inyecto una burbuja poniendo en cero las señales de control en ID/EX, así la instrucción que entra a EX no hace nada ese ciclo.

---

## 3. Hazards de control (branches y jumps)

**P: ¿Cómo manejás los saltos?**
Uso **assume-not-taken**: asumo que el branch no se toma y sigo trayendo instrucciones secuenciales. El branch se resuelve en la frontera EX/MEM. Si resultó tomado, las dos instrucciones que entraron por detrás (las que están en IF/ID e ID/EX) son inválidas, así que las **flusheo** poniéndolas en NOP. El costo es de 2 ciclos de penalidad solo cuando el salto se toma; si no se toma, no pago nada.

**P: ¿Qué branches soportás?**
BEQ y BNE, que es lo que pedía el TP. Se distinguen con `funct3[0]`. Los jumps son JAL y JALR. Cosas como `J` y `JR` de MIPS no necesitan hardware dedicado: el ensamblador las emite como `JAL x0` y `JALR x0` (escriben en x0, que se descarta).

---

## 4. UART y Debug Unit

**P: ¿Cómo cargás el programa a la placa?**
Por UART. El host (la GUI/CLI en Python) manda el binario por serie, y una **Debug Unit** —que es una FSM— lo recibe y lo escribe en la memoria de instrucciones. Después esa misma FSM controla la ejecución: modo continuo (corre hasta el HALT) o paso a paso (avanza una instrucción y dumpea el estado del PC y los registros/memoria).

**P: ¿Cómo sabe el procesador que el programa terminó?**
Todo programa termina con una instrucción `HALT` dedicada, que es un opcode custom (`0x0000000B`). El loader rellena el resto de la memoria con ceros, y los ceros se decodifican como NOPs, así que no hay basura ejecutándose.

---

## 5. Timing / FPGA

**P: ¿A qué frecuencia corre y por qué no a 100 MHz?**
No cerró timing a 100 MHz. Puse un **MMCM** que clockea todo el SoC a **65 MHz**, que es la máxima frecuencia confiable para este datapath de 32 bits (WNS de +0.319 ns). El cuello de botella es el **camino de dump** (core → Debug Unit): cruza de flanco positivo a flanco negativo, entonces tiene solo medio período para cerrar. Es un camino dominado por ruteo, no por el ancho de datos.

**P: ¿Qué ganaste pasando el datapath de 64 a 32 bits?**
Bajé los LUTs ~32% y subí la Fmax confiable de 60 a 65 MHz. Pero pasar de ~70 MHz hace explotar los *control sets*: la herramienta empieza a replicar registros por timing y satura los slices. Para subir más habría que registrar/re-clockear el camino de dump o mover la memoria de datos a BRAM.

**P: ¿Qué placa y qué FPGA?**
Basys-3, familia Artix-7, el chip es el `xc7a35tcpg236-1`, speed grade -1.

---

## 6. Flujo Vivado (RTL Analysis / Synthesis / Implementation / Bitstream)

**P: ¿Qué es RTL Analysis / Synthesis / Implementation / Bitstream?**
Para cargar el binario en la placa primero valido con **RTL Analysis**, que chequea antes de sintetizar si hay errores de código o mal uso de los bloques. Después **Run Synthesis** traduce el RTL a compuertas lógicas (LUTs, flip-flops) y valida que la FPGA pueda representar el diseño. Luego viene **Implementation**, que hace el place & route: ubica esas compuertas en celdas físicas reales del chip y rutea las conexiones, y ahí es donde se cierra el timing. Finalmente genero el **bitstream**, que es el archivo de configuración que cargo a la placa para que configure sus compuertas programables tal como definí el hardware.

---

## 7. Decisiones de diseño (preguntas "tramposas")

**P: El inmediato de un branch (B-type) viene con los bits desordenados en la instrucción. ¿Por qué?**
La notación `imm[12|10:5|...]` no lista los bits en orden: describe en qué posición física de la instrucción está cada trozo del inmediato, y el hardware los rearma. El desorden es a propósito: el bit de signo siempre es `inst[31]` en todos los formatos, así puedo arrancar el sign-extend sin esperar a decodificar el opcode, y los bits comunes entre formatos parecidos (S↔B, U↔J) quedan en la misma posición física para reusar cableado y ahorrar muxes. Es ISA más complejo a cambio de hardware más barato en el camino crítico.

**P: ¿Por qué el libro hace `<< 1` en el branch target y vos no?**
Porque mi `ImmediateExtend` ya appendea un `0` en el LSB del inmediato B/J —ese `1'b0` *es* el `<< 1` del libro—. Como mi PC está en bytes y el inmediato ya es un offset en bytes, el branch target es `PC + imm` directo. Poner otro `<< 1` duplicaría el offset; sería un bug.

**P: Mencionaste que la memoria de datos es word-addressed. ¿Eso es un problema?**
Es deuda conocida. El PC está direccionado a byte, pero la `DataMemory` quedó word-addressed: son dos ejes de direccionamiento independientes. Funciona para lo que pide el TP, pero si quisiera consistencia byte-addressed end-to-end habría que retrabajarla. Está documentado en las consideraciones de diseño.

---

## 8. Verificación

**P: ¿Cómo validaste que funciona?**
Tengo 129 tests pasando en 13 testbenches, desde unidades sueltas (ALU, RegisterFile, ImmediateExtend, ControlUnit, DataMemory) hasta integración completa IF→WB, un testbench de branches con loop de BNE + JAL con flush, y uno del SoC completo end-to-end por UART. Y además está validado sobre la Basys-3 física: carga por UART, debug continuo y paso a paso, y cierre de timing, todo andando en hardware.
