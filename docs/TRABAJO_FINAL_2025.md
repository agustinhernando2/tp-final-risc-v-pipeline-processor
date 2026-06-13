TRABAJO FINAL: PIPELINE
PROCESADOR (RISC-V)

Consigna

• Implementar el pipeline del procesador

RISC-V

Marco Teorico

Etapas

•

•

IF (Instruction Fetch): Búsqueda de la instrucción en la memoria de
programa.

ID (Instruction Decode): Decodiﬁcación de la instrucción y lectura de
registros.

• EX (Excecute): Ejecución de la instrucción propiamente dicha.

• MEM (Memory Access): Lectura o escritura desde/hacia la memoria de

datos.

• WB (Write back): Escritura de resultados en los registros.

Riegos

• Tipos:

• Estructurales. Se producen cuando dos instrucciones tratan de

utilizar el mismo recurso en el mismo ciclo.

• De datos. Se intenta utilizar un dato antes de que este preparado.

Mantenimiento del orden estricto de lecturas y escrituras.

• De control. Intentar tomar una decisión sobre una condición todavía

no evaluada.

Campos de las
instrucciones

Tipo R

• Son operaciones aritméticas y lógicas

Tipos de
Instucciones

Tipo I

• Son operaciones Imediatas

• También operaciones de Load

Tipos de
Instucciones

Tipo S

• Son operaciones de Store

Tipos de
Instucciones

Tipo J

• Operaciones de salto incondicional

• La dirección a la que se salta es la
almacenada en el registro «rs».

jal

Tipos de
Instucciones

Requerimientos

● El procesador debe ser capaz de programarse y
reprogramarse a través de comandos de UART.

● El clock no debe verse intervenido en ninguna parte del

proyecto

● Hay elementos que requieren de su ingenio y toma de
decisiones, documenten estas decisiones y su porqué.

● Ser creativos al momento de mostrar los datos e interactuar

con ellos (GUI, TUI, CLI).

Final tips & takeaways

Instrucciones a implementar

• R-type

• SLL, SRL, SRA, SLLV, SRLV, SRAV
ADDU, SUBU AND, OR, XOR, NOR
SLT, SLTU

•

I-Type

• LB, LH, LW, LWU, LBU, LHU, SB, SH,
SW ADDI, ADDIU, ANDI, ORI, XORI,
LUI SLTI, SLTIU, BEQ, BNE J, JAL

•

J-Type

• JR, JALR

Debug unit

• Se deben enviar a la PC a través de la uart:

• El contenido de los 32 registros.

• El contenido de los latches intermedios.

• Contenido de la memoria de datos usada

Carga de Programa

El Programa debe:

• Estar escrito en ensamblador en formato .coe
• Contar con un instrucción HALT o instrucción de stop.

• Permitir la programación del procesador utilizando el software escrito

El Sistema debe:

en formato .coe

• Permitir la reprogramacion del procesador

• Responder a las preguntas:

a. Es necesario vaciar la memoria?
b. Y los registros?
c. Se necesita vaciar el pipeline?
d. Y la memoria de programa?

Modos de operación

• Debe permitir dos modos de operación:

• Continuo, se envía un comando a la fpga por la uart y esta inicia la

ejecución del programa hasta llegar al ﬁnal del mismo. Llegado ese
punto se muestran todos los valores indicados en pantalla.

• Paso a paso: Enviando un comando por la uart se ejecuta un ciclo de

clock. Se debe mostrar a cada paso los valores indicados.

En ambos casos, es necesario que el pipeline quede vacío al momento de
terminar la ejecución.

Responder: Qué sucede si en mi memoria no se encuentra una instrucción
de parada?

Clock

Llegada la integración deben preguntarse.

• Cual es el camino crítico de mi sistema?
• Este camino crítico genera Skew en mi sistema? que consecuencias

tiene esto?

De encontrarse Skew:

• Encontrar la frecuencia de funcionamiento optima de mi sistema.
• Generar métricas de funcionamiento utilizando las herramientas de

Vivado.

• Aplicar la frecuencia de funcionamiento en mi sistema.

Tips

1. No copien, inspirence.
2.
3. Antes de escribir la primera línea:

Investiguen herramientas que brinda Vivado (IPCores, Clock Wizard).

a. Disenien, dibujen, esquematize.
b.

Imaginen los modulos.
i. Piensen en cómo probarlos.
ii. Como interactuan entre si.
iii. Que herramientas que ya usaron o vieron pueden utilizar.

c. Como voy a interactuar con mi sistema?
d. Como puedo interpretar el estado actual de mi sistema mientras lo

uso?

Todo lo que se les pide, ya existe y ya se implementó 1000 veces.
Asegurense del que hagan ustedes sea único.

Es lo ultimo, disfrutenlo

Bibliograﬁa

• Instrucciones:

RISC-V instruction set

• Pipeline:
Libro

