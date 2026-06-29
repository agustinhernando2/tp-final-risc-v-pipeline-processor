x

Contents

2.16  Real Stuff: MIPS Instructions  145
2.17  Real Stuff: x86 Instructions  146
2.18  Real Stuff: The Rest of the RISC-V Instruction Set  155
2.19  Fallacies and Pitfalls  157
2.20  Concluding Remarks  159
2.21  Historical Perspective and Further Reading  162
2.22  Exercises  162

  3

Arithmetic for Computers  172

Introduction  174

3.1
3.2  Addition and Subtraction  174
3.3  Multiplication  177
3.4  Division  183
3.5  Floating Point  191
3.6  Parallelism and Computer Arithmetic: Subword Parallelism  216
3.7  Real Stuff: Streaming SIMD Extensions and Advanced Vector Extensions

in x86  217

3.8  Going Faster: Subword Parallelism and Matrix Multiply  218
3.9  Fallacies and Pitfalls  222
3.10  Concluding Remarks  225
3.11  Historical Perspective and Further Reading  227
3.12  Exercises  227

  4

The Processor  234

Introduction  236

4.1
4.2  Logic Design Conventions  240
4.3  Building a Datapath  243
4.4  A Simple Implementation Scheme  251
4.5  An Overview of Pipelining  262
4.6  Pipelined Datapath and Control  276
4.7  Data Hazards: Forwarding versus Stalling  294
4.8  Control Hazards  307
4.9  Exceptions  315
4.10  Parallelism via Instructions  321
4.11  Real Stuff: The ARM Cortex-A53 and Intel Core i7 Pipelines  334
4.12  Going Faster: Instruction-Level Parallelism and Matrix Multiply  342
4.13  Advanced Topic: An Introduction to Digital Design Using a Hardware

Design Language to Describe and Model a Pipeline and More Pipelining
Illustrations  345
4.14  Fallacies and Pitfalls  345
4.15  Concluding Remarks  346
4.16  Historical Perspective and Further Reading  347
4.17  Exercises  347

xii

Contents

A P P E N D I X

  A

The Basics of Logic Design  A-2

Introduction  A-3

A.1
A.2  Gates, Truth Tables, and Logic Equations  A-4
A.3  Combinational Logic  A-9
A.4  Using a Hardware Description Language  A-20
A.5  Constructing a Basic Arithmetic Logic Unit  A-26
A.6  Faster Addition: Carry Lookahead  A-37
A.7  Clocks  A-47
A.8  Memory Elements: Flip-Flops, Latches, and Registers  A-49
A.9  Memory Elements: SRAMs and DRAMs  A-57
A.10  Finite-State Machines  A-66
A.11  Timing Methodologies  A-71
A.12  Field Programmable Devices  A-77
A.13  Concluding Remarks  A-78
A.14  Exercises  A-79

Index

I-1

O N L I N E   C O N T E N T

B

Graphics and Computing GPUs  B-2

Introduction  B-3

B.1
B.2  GPU System Architectures  B-7
B.3  Programming GPUs  B-12
B.4  Multithreaded Multiprocessor Architecture  B-25
B.5  Parallel Memory System  B-36
B.6  Floating Point Arithmetic  B-41
B.7  Real Stuff: The NVIDIA GeForce 8800  B-46
B.8  Real Stuff: Mapping Applications to GPUs  B-55
B.9  Fallacies and Pitfalls  B-72
B.10  Concluding Remarks  B-76
B.11  Historical Perspective and Further Reading  B-77

C

Introduction  C-3
Implementing Combinational Control Units  C-4
Implementing Finite-State Machine Control  C-8
Implementing the Next-State Function with a Sequencer  C-22

Mapping Control to Hardware  C-2
C.1
C.2
C.3
C.4
C.5  Translating a Microprogram to Hardware  C-28
C.6  Concluding Remarks  C-32
C.7  Exercises  C-33

4

In a major matter, no
details are small.

French Proverb

The Processor

4.1

4.2

4.3

4.4

4.5

4.6

4.7

4.8

4.9

Introduction  236
Logic Design Conventions  240
Building a Datapath  243
A Simple Implementation Scheme  251
An Overview of Pipelining  262
Pipelined Datapath and Control  276
Data Hazards: Forwarding versus

Stalling  294
Control Hazards  307
Exceptions  315

4.10  Parallelism via Instructions  321

Computer Organization and Design. DOI:© 2016 Elsevier Inc. All rights reserved.http://dx.doi.org/10.1016/B978-0-12-812275-4.00004-X20184.11  Real Stuff: The ARM Cortex-A53 and Intel Core i7 Pipelines  334
4.12  Going Faster: Instruction-Level Parallelism and Matrix

Multiply  342

4.13  Advanced Topic: An Introduction to Digital Design Using a

Hardware Design Language to Describe and Model a Pipeline

4.14

and More Pipelining Illustrations  345
Fallacies and Pitfalls  345
4.15  Concluding Remarks  346
4.16  Historical Perspective and Further Reading  347
4.17

Exercises  347

The Five Classic Components of a Computer

236

Chapter 4  The Processor

  4.1

Introduction

Chapter 1 explains that the performance of a computer is determined by three key
factors: instruction count, clock cycle time, and clock cycles per instruction (CPI).
Chapter 2 explains that the compiler and the instruction set architecture determine
the instruction count required for a given program. However, the implementation
of  the  processor  determines  both  the  clock  cycle  time  and  the  number  of  clock
cycles per instruction. In this chapter, we construct the datapath and control unit
for two different implementations of the RISC-V instruction set.

This chapter contains an explanation of the principles and techniques used in
implementing a processor, starting with a highly abstract and simplified overview
in this section. It is followed by a section that builds up a datapath and constructs a
simple version of a processor sufficient to implement an instruction set like RISC-V.
The bulk of the chapter covers a more realistic pipelined RISC-V implementation,
followed  by  a  section  that  develops  the  concepts  necessary  to  implement  more
complex instruction sets, like the x86.

For  the  reader  interested  in  understanding  the  high-level  interpretation  of
instructions and its impact on program performance, this initial section and Section
4.5 present the basic concepts of pipelining. Current trends are covered in Section
4.10,  and  Section  4.11  describes  the  recent  Intel  Core  i7  and  ARM  Cortex-A53
architectures. Section 4.12 shows how to use instruction-level parallelism to more
than double the performance of the matrix multiply from Section 3.9. These sections
provide enough background to understand the pipeline concepts at a high level.

For the reader interested in understanding the processor and its performance in
more depth, Sections 4.3, 4.4, and 4.6 will be useful. Those interested in learning how
to build a processor should also cover Sections 4.2, 4.7–4.9. For readers with an interest
 Section 4.13 describes how hardware design languages
in modern hardware design,
and CAD tools are used to implement hardware, and then how to use a hardware design
language to describe a pipelined implementation. It also gives several more illustrations
of how pipelining hardware executes.

A Basic RISC-V Implementation

We will be examining an implementation that includes a subset of the core RISC-V
instruction set:

■	 The  memory-reference  instructions

load  doubleword  (ld)  and  store

doubleword (sd)

■	 The arithmetic-logical instructions add, sub, and, and or

■	 The conditional branch instruction branch if equal (beq)

This  subset  does  not  include  all  the  integer  instructions  (for  example,  shift,
multiply, and divide are missing), nor does it include any floating-point instructions.

4.1

Introduction

237

However, it illustrates the key principles used in creating a datapath and designing
the control. The implementation of the remaining instructions is similar.

In  examining  the  implementation,  we  will  have  the  opportunity  to  see  how  the
instruction set architecture determines many aspects of the implementation, and how
the choice of various implementation strategies affects the clock rate and CPI for the
computer. Many of the key design principles introduced in Chapter 1 can be illustrated
by looking at the implementation, such as Simplicity favors regularity. In addition, most
concepts used to implement the RISC-V subset in this chapter are the same basic ideas
that  are  used  to  construct  a  broad  spectrum  of  computers,  from  high-performance
servers to general-purpose microprocessors to embedded processors.

An Overview of the Implementation

In  Chapter  2,  we  looked  at  the  core  RISC-V  instructions,  including  the  integer
arithmetic-logical instructions, the memory-reference instructions, and the branch
instructions. Much of what needs to be done to implement these instructions is the
same, independent of the exact class of instruction. For every instruction, the first
two steps are identical:

1.  Send the program counter (PC) to the memory that contains the code and

fetch the instruction from that memory.

2.  Read one or two registers, using fields of the instruction to select the registers
to read. For the ld instruction, we need to read only one register, but most
other instructions require reading two registers.

After these two steps, the actions required to complete the instruction depend
on  the  instruction  class.  Fortunately,  for  each  of  the  three  instruction  classes
(memory-reference, arithmetic-logical, and branches), the actions are largely the
same,  independent  of  the  exact  instruction.  The  simplicity  and  regularity  of  the
RISC-V instruction set simplify the implementation by making the execution of
many of the instruction classes similar.

For example, all instruction classes use the arithmetic-logical unit (ALU) after
reading the registers. The memory-reference instructions use the ALU for an address
calculation,  the  arithmetic-logical  instructions  for  the  operation  execution,  and
conditional branches for the equality test. After using the ALU, the actions required
to complete various instruction classes differ. A memory-reference instruction will
need to access the memory either to read data for a load or write data for a store.
An  arithmetic-logical  or  load  instruction  must  write  the  data  from  the  ALU  or
memory back into a register. Lastly, for a conditional branch instruction, we may
need to change the next instruction address based on the comparison; otherwise, the
PC should be incremented by four to get the address of the subsequent instruction.
Figure 4.1 shows the high-level view of a RISC-V implementation, focusing on
the various functional units and their interconnection. Although this figure shows
most of the flow of data through the processor, it omits two important aspects of
instruction execution.

First, in several places, Figure 4.1 shows data going to a particular unit as coming
from two different sources. For example, the value written into the PC can come

238

Chapter 4  The Processor

from one of two adders, the data written into the register file can come from either
the ALU or the data memory, and the second input to the ALU can come from
a  register  or  the  immediate  field  of  the  instruction.  In  practice,  these  data  lines
cannot simply be wired together; we must add a logic element that chooses from
among the multiple sources and steers one of those sources to its destination. This
selection is commonly done with a device called a multiplexor, although this device
might better be called a data selector. Appendix A describes the multiplexor, which
selects  from  among  several  inputs  based  on  the  setting  of  its  control  lines.  The
control  lines  are  set  based  primarily  on  information  taken  from  the  instruction
being executed.

The second omission in Figure 4.1 is that several of the units must be controlled
depending on the type of instruction. For example, the data memory must read
on a load and write on a store. The register file must be written only on a load or

4

Add

Add

Data

Register #

PC

Address

Instruction

Registers

ALU

Address

Instruction
memory

Register #

Register #

Data
memory

Data

FIGURE 4.1  An abstract view of the implementation of the RISC-V subset showing the
major functional units and the major connections between them. All instructions start by using
the program counter to supply the instruction address to the instruction memory. After the instruction is
fetched,  the  register  operands  used  by  an  instruction  are  specified  by  fields  of  that  instruction.  Once  the
register operands have been fetched, they can be operated on to compute a memory address (for a load or
store), to compute an arithmetic result (for an integer arithmetic-logical instruction), or an equality check
(for a branch). If the instruction is an arithmetic-logical instruction, the result from the ALU must be written
to a register. If the operation is a load or store, the ALU result is used as an address to either store a value from
the registers or load a value from memory into the registers. The result from the ALU or memory is written
back  into  the  register  file.  Branches  require  the  use  of  the  ALU  output  to  determine  the  next  instruction
address, which comes either from the adder (where the PC and branch offset are summed) or from an adder
that increments the current PC by four. The thick lines interconnecting the functional units represent buses,
which consist of multiple signals. The arrows are used to guide the reader in knowing how information flows.
Since signal lines may cross, we explicitly show when crossing lines are connected by the presence of a dot
where the lines cross.

4.1

Introduction

239

an arithmetic-logical instruction. And, of course, the ALU must perform one of
several operations. (Appendix A describes the detailed design of the ALU.) Like
the multiplexors, control lines that are set based on various fields in the instruction
direct these operations.

Figure 4.2 shows the datapath of Figure 4.1 with the three required multiplexors
added, as well as control lines for the major functional units. A control unit, which
has the instruction as an input, is used to determine how to set the control lines
for the functional units and two of the multiplexors. The top multiplexor, which

Branch

M
u
x

4

Add

Add

M
u
x

ALU operation

Data

Register #

PC

Address Instruction

Registers

Instruction
memory

Register #

Register #

RegWrite

MemWrite

ALU

Address

Zero

Data
memory

M
u
x

Data

MemRead

Control

FIGURE 4.2  The basic implementation of the RISC-V subset, including the necessary multiplexors and control lines. The
top multiplexor (“Mux”) controls what value replaces the PC (PC + 4 or the branch destination address); the multiplexor is controlled by the gate
that “ANDs” together the Zero output of the ALU and a control signal that indicates that the instruction is a branch. The middle multiplexor, whose
output returns to the register file, is used to steer the output of the ALU (in the case of an arithmetic-logical instruction) or the output of the data
memory (in the case of a load) for writing into the register file. Finally, the bottom-most multiplexor is used to determine whether the second ALU
input is from the registers (for an arithmetic-logical instruction or a branch) or from the offset field of the instruction (for a load or store). The
added control lines are straightforward and determine the operation performed at the ALU, whether the data memory should read or write, and
whether the registers should perform a write operation. The control lines are shown in color to make them easier to see.

240

Chapter 4  The Processor

determines whether PC + 4 or the branch destination address is written into the
PC,  is  set  based  on  the  Zero  output  of  the  ALU,  which  is  used  to  perform  the
comparison  of  a  beq  instruction.  The  regularity  and  simplicity  of  the  RISC-V
instruction set mean that a simple decoding process can be used to determine how
to set the control lines.

In the remainder of the chapter, we refine this view to fill in the details, which
requires that we add further functional units, increase the number of connections
between  units,  and,  of  course,  enhance  a  control  unit  to  control  what  actions
are taken for different instruction classes. Sections 4.3 and 4.4 describe a simple
implementation that uses a single long clock cycle for every instruction and follows
the general form of Figures 4.1 and 4.2. In this first design, every instruction begins
execution on one clock edge and completes execution on the next clock edge.

While easier to understand, this approach is not practical, since the clock cycle
must be severely stretched to accommodate the longest instruction. After designing
the control for this simple computer, we will look at pipelined implementation with
all its complexities, including exceptions.

Check
Yourself

How many of the five classic components of a computer—shown on page 235—do
Figures 4.1 and 4.2 include?

  4.2

Logic Design Conventions

To  discuss  the  design  of  a  computer,  we  must  decide  how  the  hardware  logic
implementing the computer will operate and how the computer is clocked. This
section reviews a few key ideas in digital logic that we will use extensively in this
chapter. If you have little or no background in digital logic, you will find it helpful
to read Appendix A before continuing.

The  datapath  elements  in  the  RISC-V  implementation  consist  of  two  different
types  of  logic  elements:  elements  that  operate  on  data  values  and  elements  that
contain state. The elements that operate on data values are all combinational, which
means that their outputs depend only on the current inputs. Given the same input, a
combinational element always produces the same output. The ALU shown in Figure
4.1 and discussed in Appendix A is an example of a combinational element. Given a
set of inputs, it always produces the same output because it has no internal storage.

Other elements in the design are not combinational, but instead contain state. An
element contains state if it has some internal storage. We call these elements state
elements because, if we pulled the power plug on the computer, we could restart it
accurately by loading the state elements with the values they contained before we
pulled the plug. Furthermore, if we saved and restored the state elements, it would
be as if the computer had never lost power. Thus, these state elements completely
characterize  the  computer.  In  Figure  4.1,  the  instruction  and  data  memories,  as
well as the registers, are all examples of state elements.

combinational
element  An operational
element, such as an AND
gate or an ALU

state element  A memory
element, such as a register
or a memory.

4.2  Logic Design Conventions

241

A state element has at least two inputs and one output. The required inputs are
the data value to be written into the element and the clock, which determines when
the data value is written. The output from a state element provides the value that
was  written  in  an  earlier  clock  cycle.  For  example,  one  of  the  logically  simplest
state elements is a D-type flip-flop (see Appendix A), which has exactly these two
inputs (a value and a clock) and one output. In addition to flip-flops, our RISC-V
implementation  uses  two  other  types  of  state  elements:  memories  and  registers,
both of which appear in Figure 4.1. The clock is used to determine when the state
element should be written; a state element can be read at any time.

Logic  components  that  contain  state  are  also  called  sequential,  because  their
outputs  depend  on  both  their  inputs  and  the  contents  of  the  internal  state.  For
example, the output from the functional unit representing the registers depends
both on the register numbers supplied and on what was written into the registers
previously.  Appendix  A  discusses  the  operation  of  both  the  combinational  and
sequential elements and their construction in more detail.

Clocking Methodology

A clocking methodology defines when signals can be read and when they can be
written. It is important to specify the timing of reads and writes, because if a signal
is written at the same time that it is read, the value of the read could correspond
to the old value, the newly written value, or even some mix of the two! Computer
designs cannot tolerate such unpredictability. A clocking methodology is designed
to make hardware predictable.

For  simplicity,  we  will  assume  an  edge-triggered  clocking  methodology.  An
edge-triggered clocking methodology means that any values stored in a sequential
logic element are updated only on a clock edge, which is a quick transition from
low to high or vice versa (see Figure 4.3). Because only state elements can store a
data value, any collection of combinational logic must have its inputs come from a
set of state elements and its outputs written into a set of state elements. The inputs
are values that were written in a previous clock cycle, while the outputs are values
that can be used in a following clock cycle.

State
element
1

Combinational logic

State
element
2

Clock cycle

FIGURE 4.3  Combinational logic, state elements, and the clock are closely related. In a
synchronous digital system, the clock determines when elements with state will write values into internal
storage. Any inputs to a state element must reach a stable value (that is, have reached a value from which
they will not change until after the clock edge) before the active clock edge causes the state to be updated. All
state elements in this chapter, including memory, are assumed positive edge-triggered; that is, they change
on the rising clock edge.

clocking
methodology  The
approach used to
determine when data are
valid and stable relative to
the clock.

edge-triggered
clocking  A clocking
scheme in which all state
changes occur on a clock
edge.

242

Chapter 4  The Processor

control signal  A signal
used for multiplexor
selection or for directing
the operation of a
functional unit; contrasts
with a data signal, which
contains information
that is operated on by a
functional unit.

asserted  The signal is
logically high or true.

deasserted  The signal is
logically low or false.

Figure 4.3 shows the two state elements surrounding a block of combinational
logic, which operates in a single clock cycle: all signals must propagate from state
element 1, through the combinational logic, and to state element 2 in the time of
one clock cycle. The time necessary for the signals to reach state element 2 defines
the length of the clock cycle.

For simplicity, we do not show a write control signal when a state element is
written on every active clock edge. In contrast, if a state element is not updated on
every clock, then an explicit write control signal is required. Both the clock signal
and the write control signal are inputs, and the state element is changed only when
the write control signal is asserted and a clock edge occurs.

We will use the word asserted to indicate a signal that is logically high and assert
to specify that a signal should be driven logically high, and deassert or deasserted
to  represent  logically  low.  We  use  the  terms  assert  and  deassert  because  when
we  implement  hardware,  at  times  1  represents  logically  high  and  at  times  it  can
represent logically low.

An  edge-triggered  methodology  allows  us  to  read  the  contents  of  a  register,
send  the  value  through  some  combinational  logic,  and  write  that  register  in  the
same clock cycle. Figure 4.4 gives a generic example. It doesn’t matter whether we
assume that all writes take place on the rising clock edge (from low to high) or on
the  falling  clock  edge  (from  high  to  low),  since  the  inputs  to  the  combinational
logic block cannot change except on the chosen clock edge. In this book, we use
the  rising  clock  edge.  With  an  edge-triggered  timing  methodology,  there  is  no
feedback within a single clock cycle, and the logic in Figure 4.4 works correctly.
In Appendix A, we briefly discuss additional timing constraints (such as setup and
hold times) as well as other timing methodologies.

For the 64-bit RISC-V architecture, nearly all of these state and logic elements
will have inputs and outputs that are 64 bits wide, since that is the width of most
of the data handled by the processor. We will make it clear whenever a unit has an
input or output that is other than 64 bits in width. The figures will indicate buses,
which  are  signals  wider  than  1  bit,  with  thicker  lines.  At  times,  we  will  want  to
combine several buses to form a wider bus; for example, we may want to obtain
a 64-bit bus by combining two 32-bit buses. In such cases, labels on the bus lines

State
element

Combinational logic

FIGURE  4.4  An  edge-triggered  methodology  allows  a  state  element  to  be  read  and
written in the same clock cycle without creating a race that could lead to indeterminate
data values. Of course, the clock cycle still must be long enough so that the input values are stable when
the active clock edge occurs. Feedback cannot occur within one clock cycle because of the edge-triggered
update  of  the  state  element.  If  feedback  were  possible,  this  design  could  not  work  properly.  Our  designs
in this chapter and the next rely on the edge-triggered timing methodology and on structures like the one
shown in this figure.

4.3  Building a Datapath

243

will  make  it  clear  that  we  are  concatenating  buses  to  form  a  wider  bus.  Arrows
are also added to help clarify the direction of the flow of data between elements.
Finally, color indicates a control signal contrary to a signal that carries data; this
distinction will become clearer as we proceed through this chapter.

True or false: Because the register file is both read and written on the same clock
cycle, any RISC-V datapath using edge-triggered writes must have more than one
copy of the register file.

Check
Yourself

Elaboration:  There is also a 32-bit version of the RISC-V architecture, and, naturally
enough, most paths in its implementation would be 32 bits wide.

  4.3

Building a Datapath

A reasonable way to start a datapath design is to examine the major components
required  to  execute  each  class  of  RISC-V  instructions.  Let’s  start  at  the  top  by
looking at which datapath elements each instruction needs, and then work our
way down through the levels of abstraction. When we show the datapath elements,
we  will  also  show  their  control  signals.  We  use  abstraction  in  this  explanation,
starting from the bottom up.

Figure  4.5a  shows  the  first  element  we  need:  a  memory  unit  to  store  the
instructions of a program and supply instructions given an address.  Figure 4.5b
also shows the program counter (PC), which as we saw in Chapter 2 is a register
that  holds  the  address  of  the  current  instruction.  Lastly,  we  will  need  an  adder
to increment the PC to the address of the next instruction. This adder, which is
combinational, can be built from the ALU described in detail in Appendix A simply
by wiring the control lines so that the control always specifies an add operation. We
will draw such an ALU with the label Add, as in Figure 4.5c, to indicate that it has
been permanently made an adder and cannot perform the other ALU functions.

To  execute  any  instruction,  we  must  start  by  fetching  the  instruction  from
memory. To prepare for executing the next instruction, we must also increment the
program counter so that it points at the next instruction, 4 bytes later. Figure 4.6
shows  how  to  combine  the  three  elements  from  Figure  4.5  to  form  a  datapath
that fetches instructions and increments the PC to obtain the address of the next
sequential instruction.

Now  let’s  consider  the  R-format  instructions  (see  Figure  2.19  on  page  120).
They  all  read  two  registers,  perform  an  ALU  operation  on  the  contents  of  the
registers, and write the result to a register. We call these instructions either R-type
instructions  or  arithmetic-logical  instructions  (since  they  perform  arithmetic  or
logical operations). This instruction class includes add, sub, and, and or, which

datapath element  A
unit used to operate on
or hold data within a
processor. In the RISC-V
implementation, the
datapath elements include
the instruction and data
memories, the register
file, the ALU, and adders.

program counter
(PC)  The register
containing the address
of the instruction in the
program being executed.

244

Chapter 4  The Processor

Instruction
address

Instruction

PC

Add Sum

Instruction
memory

a. Instruction memory

b. Program counter

c. Adder

FIGURE  4.5  Two  state  elements  are  needed  to  store  and  access  instructions,  and  an
adder is needed to compute the next instruction address. The state elements are the instruction
memory  and  the  program  counter.  The  instruction  memory  need  only  provide  read  access  because  the
datapath does not write instructions. Since the instruction memory only reads, we treat it as combinational
logic: the output at any time reflects the contents of the location specified by the address input, and no read
control signal is needed. (We will need to write the instruction memory when we load the program; this is
not hard to add, and we ignore it for simplicity.) The program counter is a 64-bit register that is written at the
end of every clock cycle and thus does not need a write control signal. The adder is an ALU wired to always
add its two 64-bit inputs and place the sum on its output.

were introduced in Chapter 2. Recall that a typical instance of such an instruction
is add x1, x2, x3, which reads x2 and x3 and writes the sum into x1.

The processor’s 32 general-purpose registers are stored in a structure called a
register file. A register file is a collection of registers in which any register can be
read or written by specifying the number of the register in the file. The register file
contains the register state of the computer. In addition, we will need an ALU to
operate on the values read from the registers.

R-format instructions have three register operands, so we will need to read two
data words from the register file and write one data word into the register file for
each instruction. For each data word to be read from the registers, we need an input
to the register file that specifies the register number to be read and an output from
the register file that will carry the value that has been read from the registers. To
write a data word, we will need two inputs: one to specify the register number to be
written and one to supply the data to be written into the register. The register file
always outputs the contents of whatever register numbers are on the Read register
inputs. Writes, however, are controlled by the write control signal, which must be
asserted for a write to occur at the clock edge. Figure 4.7a shows the result; we need
a total of three inputs (two for register numbers and one for data) and two outputs
(both  for  data).  The  register  number  inputs  are  5  bits  wide  to  specify  one  of  32
registers (32 = 25), whereas the data input and two data output buses are each 64
bits wide.

Figure 4.7b shows the ALU, which takes two 64-bit inputs and produces a 64-bit
result, as well as a 1-bit signal if the result is 0. The 4-bit control signal of the ALU
is described in detail in Appendix A; we will review the ALU control shortly when
we need to know how to set it.

register file  A state
element that consists
of a set of registers that
can be read and written
by supplying a register
number to be accessed.

4.3  Building a Datapath

245

Add

4

PC

Read
address

Instruction

Instruction
memory

FIGURE 4.6  A portion of the datapath used for fetching instructions and incrementing
the program counter. The fetched instruction is used by other parts of the datapath.

Register
numbers

Data

5

5

5

Read
register 1

Read
register 2

Write
register

Write
Data

Registers

Read
data 1

Read
data 2

RegWrite

ALU operation

4

Data

ALU

Zero

ALU
result

a. Registers

b. ALU

FIGURE  4.7  The  two  elements  needed  to  implement  R-format  ALU  operations  are  the
register  file  and  the  ALU.  The register file contains all the registers and has two read ports and one
write port. The design of multiported register files is discussed in Section A.8 of Appendix A. The register
file always outputs the contents of the registers corresponding to the Read register inputs on the outputs;
no other control inputs are needed. In contrast, a register write must be explicitly indicated by asserting the
write control signal. Remember that writes are edge-triggered, so that all the write inputs (i.e., the value to
be written, the register number, and the write control signal) must be valid at the clock edge. Since writes
to the register file are edge-triggered, our design can legally read and write the same register within a clock
cycle: the read will get the value written in an earlier clock cycle, while the value written will be available to
a read in a subsequent clock cycle. The inputs carrying the register number to the register file are all 5 bits
wide, whereas the lines carrying data values are 64 bits wide. The operation to be performed by the ALU is
controlled with the ALU operation signal, which will be 4 bits wide, using the ALU designed in Appendix A.
We will use the Zero detection output of the ALU shortly to implement conditional branches.

246

Chapter 4  The Processor

Next, consider the RISC-V load register and store register instructions, which
have  the  general  form  ld  x1,  offset(x2)  or  sd  x1,  offset(x2).  These
instructions compute a memory address by adding the base register, which is x2,
to the 12-bit signed offset field contained in the instruction. If the instruction is a
store, the value to be stored must also be read from the register file where it resides
in x1. If the instruction is a load, the value read from memory must be written into
the register file in the specified register, which is x1. Thus, we will need both the
register file and the ALU from Figure 4.7.

In  addition,  we  will  need  a  unit  to  sign-extend  the  12-bit  offset  field  in  the
instruction to a 64-bit signed value, and a data memory unit to read from or write
to. The data memory must be written on store instructions; hence, data memory
has read and write control signals, an address input, and an input for the data to be
written into memory. Figure 4.8 shows these two elements.

The  beq  instruction  has  three  operands,  two  registers  that  are  compared  for
equality, and a 12-bit offset used to compute the branch target address relative to
the branch instruction address. Its form is beq x1, x2, offset. To implement
this instruction, we must compute the branch target address by adding the sign-
extended  offset  field  of  the  instruction  to  the  PC.  There  are  two  details  in  the
definition of branch instructions (see Chapter 2) to which we must pay attention:

■	 The instruction set architecture specifies that the base for the branch address

calculation is the address of the branch instruction.

■	 The architecture also states that the offset field is shifted left 1 bit so that it is
a half word offset; this shift increases the effective range of the offset field by
a factor of 2.

To deal with the latter complication, we will need to shift the offset field by 1.

As well as computing the branch target address, we must also determine whether
the next instruction is the instruction that follows sequentially or the instruction at the
branch target address. When the condition is true (i.e., two operands are equal), the
branch target address becomes the new PC, and we say that the branch is  taken. If
the operand is not zero, the incremented PC should replace the current PC (just as for
any other normal instruction); in this case, we say that the branch is not taken.

Thus, the branch datapath must do two operations: compute the branch target
address and test the register contents. (Branches also affect the instruction fetch
portion of the datapath, as we will deal with shortly.) Figure 4.9 shows the structure
of  the  datapath  segment  that  handles  branches.  To  compute  the  branch  target
address, the branch datapath includes an immediate generation unit, from Figure
4.8 and an adder. To perform the compare, we need to use the register file shown
in Figure 4.7a to supply two register operands (although we will not need to write
into the register file). In addition, the equality comparison can be done using the
ALU we designed in Appendix A. Since that ALU provides an output signal that
indicates whether the result was 0, we can send both register operands to the ALU

sign-extend  To increase
the size of a data item by
replicating the high-order
sign bit of the original
data item in the high-
order bits of the larger,
destination data item.

branch target
address  The address
specified in a branch,
which becomes the new
program counter (PC) if
the branch is taken. In the
RISC-V architecture, the
branch target is given by
the sum of the offset field
of the instruction and the
address of the branch.

branch taken
A branch where the
branch condition is
satisfied and the program
counter (PC) becomes
the branch target. All
unconditional branches
are taken branches.

branch not taken or
(untaken branch)
A branch where the
branch condition is false
and the program counter
(PC) becomes the address
of the instruction that
sequentially follows the
branch.

4.3  Building a Datapath

247

Address

Write
data

MemWrite

Read
data

Data
memory

MemRead

32

64

Imm
Gen

a. Data memory unit

b. Immediate generation unit

FIGURE  4.8  The  two  units  needed  to  implement  loads  and  stores,  in  addition  to  the
register file and ALU of Figure 4.7, are the data memory unit and the immediate generation
unit. The memory unit is a state element with inputs for the address and the write data, and a single output
for the read result. There are separate read and write controls, although only one of these may be asserted on
any given clock. The memory unit needs a read signal, since, unlike the register file, reading the value of an
invalid address can cause problems, as we will see in Chapter 5. The immediate generation unit (ImmGen) has
a 32-bit instruction as input that selects a 12-bit field for load, store, and branch if equal that is sign-extended
into a 64-bit result appearing on the output (see Chapter 2). We assume the data memory is edge-triggered for
writes. Standard memory chips actually have a write enable signal that is used for writes. Although the write
enable is not edge-triggered, our edge-triggered design could easily be adapted to work with real memory
chips. See Section A.8 of Appendix A for further discussion of how real memory chips work.

with the control set to subtract two values. If the Zero signal out of the ALU unit
is asserted, we know that the register values are equal. Although the Zero output
always signals if the result is 0, we will be using it only to implement the equality
test of conditional branches. Later, we will show exactly how to connect the control
signals of the ALU for use in the datapath.

The  branch  instruction  operates  by  adding  the  PC  with  the  12  bits  of  the
instruction  shifted  left  by  1  bit.  Simply  concatenating  0  to  the  branch  offset
accomplishes this shift, as described in Chapter 2.

Creating a Single Datapath

Now that we have examined the datapath components needed for the individual
instruction classes, we can combine them into a single datapath and add the control
to complete the implementation. This simplest datapath will attempt to execute all
instructions in one clock cycle. This design means that no datapath resource can be
used more than once per instruction, so any element needed more than once must
be duplicated. We therefore need a memory for instructions separate from one for
data. Although some of the functional units will need to be duplicated, many of the
elements can be shared by different instruction flows.

248

Chapter 4  The Processor

PC from instruction datapath

Add Sum

Branch
target

Shift
left 1

ALU operation

4

ALU Zero

To branch
control logic

Instruction

Read
register 1

Read
register 2

Write
register

Write
data

Registers

Read
data 1

Read
data 2

RegWrite

32

64

Imm
Gen

FIGURE  4.9  The  datapath  for  a  branch  uses  the  ALU  to  evaluate  the  branch  condition
and a separate adder to compute the branch target as the sum of the PC and the sign-
extended 12 bits of the instruction (the branch displacement), shifted left 1 bit. The unit
labeled Shift left 1 is simply a routing of the signals between input and output that adds 0two to the low-order
end of the sign-extended offset field; no actual shift hardware is needed, since the amount of the “shift” is
constant. Since we know that the offset was sign-extended from 12 bits, the shift will throw away only “sign
bits.” Control logic is used to decide whether the incremented PC or branch target should replace the PC,
based on the Zero output of the ALU.

To share a datapath element between two different instruction classes, we may
need to allow multiple connections to the input of an element, using a multiplexor
and control signal to select among the multiple inputs.

EXAMPLE

Building a Datapath

The operations of arithmetic-logical (or R-type) instructions and the memory
instructions datapath are quite similar. The key differences are the following:

■	 The arithmetic-logical instructions use the ALU, with the inputs coming
from the two registers. The memory instructions can also use the ALU
to  do  the  address  calculation,  although  the  second  input  is  the  sign-
extended 12-bit offset field from the instruction.

4.3  Building a Datapath

249

■	 The value stored into a destination register comes from the ALU (for an

R-type instruction) or the memory (for a load).

Show how to build a datapath for the operational portion of the memory-
reference  and  arithmetic-logical  instructions  that  uses  a  single  register  file
and a single ALU to handle both types of instructions, adding any necessary
multiplexors.

To create a datapath with only a single register file and a single ALU, we must
support two different sources for the second ALU input, as well as two different
sources for the data stored into the register file. Thus, one multiplexor is placed
at the ALU input and another at the data input to the register file. Figure 4.10
shows the operational portion of the combined datapath.

ANSWER

Now  we  can  combine  all  the  pieces  to  make  a  simple  datapath  for  the  core
RISC-V architecture by adding the datapath for instruction fetch (Figure 4.6), the
datapath from R-type and memory instructions (Figure 4.10), and the datapath for
branches (Figure 4.9). Figure 4.11 shows the datapath we obtain by composing the
separate pieces. The branch instruction uses the main ALU to compare two register
operands for equality, so we must keep the adder from Figure 4.9 for computing
the branch target address. An additional multiplexor is required to select either the
sequentially following instruction address (PC + 4) or the branch target address to
be written into the PC.

Instruction

Read
data 1

Read
data 2

Read
register 1

Read
register 2

Registers

Write
register

Write
data

RegWrite

ALU operation

4

ALU

Zero

ALU
result

ALUSrc

0
M
u
x
1

MemWrite

MemtoReg

Address

Read
data

Data
memory

Write
data

1
M
u
x
0

MemRead

32

64

Imm
Gen

FIGURE 4.10  The datapath for the memory instructions and the R-type instructions. This example shows
how a single datapath can be assembled from the pieces in Figures 4.7 and 4.8 by adding multiplexors. Two multiplexors
are needed, as described in the example.

250

Chapter 4  The Processor

Add

4

PC

Read
address

Instruction

Instruction
memory

PCSrc

M
u
x

Add

Sum

Shift
left 1

ALUSrc

4

ALU operation

ALU

Zero

ALU
result

M
u
x

MemWrite

MemtoReg

Address

Read
data

M
u
x

Write
data

Data
memory

MemRead

Read
register 1

Read
register 2

Read
data 1

Registers

Read
data 2

Write
register

Write
data

RegWrite

32

64

Imm
Gen

FIGURE 4.11  The simple datapath for the core RISC-V architecture combines the elements
required by different instruction classes. The components come from Figures 4.6, 4.9, and 4.10. This
datapath can execute the basic instructions (load-store register, ALU operations, and branches) in a single
clock cycle. Just one additional multiplexor is needed to integrate branches.

Check
Yourself

I.  Which of the following is correct for a load instruction? Refer to Figure 4.10.

a.  MemtoReg should be set to cause the data from memory to be sent to the

register file.

b.  MemtoReg should be set to cause the correct register destination to be

sent to the register file.

c.  We do not care about the setting of MemtoReg for loads.

II.  The single-cycle datapath conceptually described in this section must have

separate instruction and data memories, because

a.  the formats of data and instructions are different in RISC-V, and hence

different memories are needed;

b.  having separate memories is less expensive;
c.  the  processor  operates  in  one  cycle  and  cannot  use  a  (single-ported)

memory for two different accesses within that cycle.

4.4  A Simple Implementation Scheme

251

Now that we have completed this simple datapath, we can add the control unit.
The control unit must be able to take inputs and generate a write signal for each
state element, the selector control for each multiplexor, and the ALU control. The
ALU control is different in a number of ways, and it will be useful to design it first
before we design the rest of the control unit.

Elaboration:  The immediate generation logic must choose between sign-extending
a 12-bit field in instruction bits 31:20 for load instructions, bits 31:25 and 11:7 for
store  instructions,  or  bits  31,  7,  30:25,  and  11:8  for  the  conditional  branch.  Since
the input is all 32 bits of the instruction, it can use the opcode bits of the instruction
to  select  the  proper  field.  RISC-V  opcode  bit  6  happens  to  be  0  for  data  transfer
instructions and 1 for conditional branches, and RISC-V opcode bit 5 happens to be 0
for load instructions and 1 for store instructions. Thus, bits 5 and 6 can control a 3:1
multiplexor inside the immediate generation logic that selects the appropriate 12-bit
field for load, store, and conditional branch instructions.

  4.4

A Simple Implementation Scheme

In this section, we look at what might be thought of as a simple implementation
of our RISC-V subset. We build this simple implementation using the datapath of
the last section and adding a simple control function. This simple implementation
covers load doubleword (ld), store doubleword (sd), branch if equal (beq), and the
arithmetic-logical instructions add, sub, and, and or.

The ALU Control

The RISC-V ALU in Appendix A defines the four following combinations of four
control inputs:

ALU control lines

Function

0000
0001
0010
0110

AND
OR
add
subtract

Depending  on  the  instruction  class,  the  ALU  will  need  to  perform  one  of
these four functions. For load and store instructions, we use the ALU to compute
the memory address by addition. For the R-type instructions, the ALU needs to
perform  one  of  the  four  actions  (AND,  OR,  add,  or  subtract),  depending  on
the value of the 7-bit funct7 field (bits 31:25) and 3-bit funct3 field (bits 14:12) in
the instruction (see Chapter 2). For the conditional branch if equal instruction, the
ALU subtracts two operands and tests to see if the result is 0.

truth table  From logic, a

representation of a logical

operation by listing all the

values of the inputs and

then in each case showing

what the resulting outputs

should be.

252

Chapter 4  The Processor

We can generate the 4-bit ALU control input using a small control unit that has
as inputs the funct7 and funct3 fields of the instruction and a 2-bit control field,
which we call ALUOp. ALUOp indicates whether the operation to be performed
should be add (00) for loads and stores, subtract and test if zero (01) for beq, or
be determined by the operation encoded in the funct7 and funct3 fields (10). The
output of the ALU control unit is a 4-bit signal that directly controls the ALU by
generating one of the 4-bit combinations shown previously.

In Figure 4.12, we show how to set the ALU control inputs based on the 2-bit
ALUOp control, funct7, and funct3 fields. Later in this chapter, we will see how the
ALUOp bits are generated from the main control unit.

This style of using multiple levels of decoding—that is, the main control unit
generates the ALUOp bits, which then are used as input to the ALU control that
generates the actual signals to control the ALU unit—is a common implementation
technique. Using multiple levels of control can reduce the size of the main control
unit. Using several smaller control units may also potentially reduce the latency of
the control unit. Such optimizations are important, since the latency of the control
unit is often a critical factor in determining the clock cycle time.

There are several different ways to implement the mapping from the 2-bit ALUOp
field and the funct fields to the four ALU operation control bits. Because only a small
number of the possible funct field values are of interest and funct fields are used only
when the ALUOp bits equal 10, we can use a small piece of logic that recognizes the
subset of possible values and generates the appropriate ALU control signals.

ALU control lines

Function

0000
0001
0010
0110

AND
OR
add
subtract

Instruction
opcode

ALUOp

Operation

ld
sd
beq
R-type
R-type
R-type

R-type

00
00
01
10
10
10

10

load doubleword
store doubleword
branch if equal
add
sub
and

or

Funct7
ﬁ eld

XXXXXXX
XXXXXXX
XXXXXXX
0000000
0100000
0000000

0000000

Funct3
ﬁ eld

Desired
ALU action

ALU control
input

XXX
XXX
XXX
000
000
111

110

add
add
subtract
add
subtract
AND

OR

0010
0010
0110
0010
0110
0000

0001

FIGURE 4.12  How the ALU control bits are set depends on the ALUOp control bits and the
different opcodes for the R-type instruction. The instruction, listed in the first column, determines
the setting of the ALUOp bits. All the encodings are shown in binary. Notice that when the ALUOp code is
00 or 01, the desired ALU action does not depend on the funct7 or funct3 fields; in this case, we say that we
“don’t care” about the value of the opcode, and the bits are shown as Xs. When the ALUOp value is 10, then
the funct7 and funct3 fields are used to set the ALU control input. See Appendix A.

We can generate the 4-bit ALU control input using a small control unit that has

as inputs the funct7 and funct3 fields of the instruction and a 2-bit control field,

which we call ALUOp. ALUOp indicates whether the operation to be performed

should be add (00) for loads and stores, subtract and test if zero (01) for beq, or

be determined by the operation encoded in the funct7 and funct3 fields (10). The

output of the ALU control unit is a 4-bit signal that directly controls the ALU by

generating one of the 4-bit combinations shown previously.

In Figure 4.12, we show how to set the ALU control inputs based on the 2-bit

ALUOp control, funct7, and funct3 fields. Later in this chapter, we will see how the

ALUOp bits are generated from the main control unit.

This style of using multiple levels of decoding—that is, the main control unit

generates the ALUOp bits, which then are used as input to the ALU control that

generates the actual signals to control the ALU unit—is a common implementation

technique. Using multiple levels of control can reduce the size of the main control

unit. Using several smaller control units may also potentially reduce the latency of

the control unit. Such optimizations are important, since the latency of the control

unit is often a critical factor in determining the clock cycle time.

There are several different ways to implement the mapping from the 2-bit ALUOp

field and the funct fields to the four ALU operation control bits. Because only a small

number of the possible funct field values are of interest and funct fields are used only

when the ALUOp bits equal 10, we can use a small piece of logic that recognizes the

subset of possible values and generates the appropriate ALU control signals.

4.4  A Simple Implementation Scheme

253

truth table  From logic, a
representation of a logical
operation by listing all the
values of the inputs and
then in each case showing
what the resulting outputs
should be.

don’t-care term  An
element of a logical
function in which the
output does not depend
on the values of all the
inputs. Don’t-care terms
may be specified in
different ways.

As a step in designing this logic, it is useful to create a truth table for the interesting
combinations of funct fields and the ALUOp signals, as we’ve done in Figure 4.13; this
truth table shows how the 4-bit ALU control is set depending on these input fields.
Since the full truth table is very large, and we don’t care about the value of the ALU
control for many of these input combinations, we show only the truth table entries
for which the ALU control must have a specific value. Throughout this chapter, we
will use this practice of showing only the truth table entries for outputs that must be
asserted and not showing those that are all deasserted or don’t care. (This practice
has a disadvantage, which we discuss in Section C.2 of

 Appendix C.)

Because in many instances we do not care about the values of some of the inputs,
and because we wish to keep the tables compact, we also include don’t-care terms.
A  don’t-care  term  in  this  truth  table  (represented  by  an  X  in  an  input  column)
indicates that the output does not depend on the value of the input corresponding
to that column. For example, when the ALUOp bits are 00, as in the first row of
Figure 4.13, we always set the ALU control to 0010, independent of the funct fields.
In this case, then, the funct inputs will be don’t cares in this line of the truth table.
Later, we will see examples of another type of don’t-care term. If you are unfamiliar
with the concept of don’t-care terms, see Appendix A for more information.

Once the truth table has been constructed, it can be optimized and then turned
into gates. This process is completely mechanical. Thus, rather than show the final
 Appendix C.
steps here, we describe the process and the result in Section C.2 of

Designing the Main Control Unit

Now  that  we  have  described  how  to  design  an  ALU  that  uses  the  opcode  and  a
2-bit signal as its control inputs, we can return to looking at the rest of the control.
To start this process, let’s identify the fields of an instruction and the control lines
that  are  needed  for  the  datapath  we  constructed  in  Figure  4.11.  To  understand
how to connect the fields of an instruction to the datapath, it is useful to review

ALUOp

Funct7 ﬁ eld

Funct3 ﬁ eld

ALUOp1 ALUOp0 I[31]

I[30]

I[29]

I[28]

I[27]

I[26]

I[25]

I[14]

I[13]

I[12]

Operation

0
X
1
1
1
1

0
1
X
X
X
X

X
X
0
0
0
0

X
X
0
1
0
0

X
X
0
0
0
0

X
X
0
0
0
0

X
X
0
0
0
0

X
X
0
0
0
0

X
X
0
0
0
0

X
X
0
0
1
1

X
X
0
0
1
1

X
X
0
0
1
0

0010
0110
0010
0110
0000
0001

FIGURE 4.13  The truth table for the 4 ALU control bits (called Operation). The inputs are the ALUOp and funct fields. Only the
entries for which the ALU control is asserted are shown. Some don’t-care entries have been added. For example, the ALUOp does not use the
encoding 11, so the truth table can contain entries 1X and X1, rather than 10 and 01. While we show all 10 bits of funct fields, note that the only
bits with different values for the four R-format instructions are bits 30, 14, 13, and 12. Thus, we only need these four funct field bits as input for
ALU control instead of all 10.

254

Chapter 4  The Processor

Name
(Bit position)

31:25

24:20

19:15

14:12

11:7

6:0

Fields

(a) R-type

funct7

rs2

(b)

I-type

immediate[11:0]

(c) S-type

immed[11:5]

(d) SB-type

immed[12,10:5]

rs2

rs2

rs1

rs1

rs1

rs1

funct3

funct3

rd

rd

opcode

opcode

funct3

immed[4:0]

opcode

funct3 immed[4:1,11]

opcode

FIGURE  4.14  The  four  instruction  classes  (arithmetic,  load,  store,  and  conditional  branch)  use  four  different
instruction formats. (a) Instruction format for R-type arithmetic instructions (opcode = 51ten), which have three register operands: rs1, rs2,
and rd. Fields rs1 and rd are sources, and rd is the destination. The ALU function is in the funct3 and funct7 fields and is decoded by the ALU
control design in the previous section. The R-type instructions that we implement are add, sub, and, and or. (b) Instruction format for I-type
load instructions (opcode = 3ten). The register rs1 is the base register that is added to the 12-bit immediate field to form the memory address.
Field rd is the destination register for the loaded value. (c) Instruction format for S-type store instructions (opcode = 35ten). The register rs1 is
the base register that is added to the 12-bit immediate field to form the memory address. (The immediate field is split into a 7-bit piece and a
5-bit piece.) Field rs2 is the source register whose value should be stored into memory. (d) Instruction format for SB-type conditional branch
instructions (opcode = 99ten). The registers rs1 and rs2 compared. The 12-bit immediate address field is sign-extended, shifted left 1 bit, and
added to the PC to compute the branch target address.

opcode  The field that
denotes the operation and
format of an instruction.

the formats of the four instruction classes: arithmetic, load, store, and conditional
branch instructions. Figure 4.14 shows these formats.

There are several major observations about this instruction format that we will

rely on:

■	 The  opcode  field,  which  as  we  saw  in  Chapter  2,  is  always  in  bits  6:0.
Depending on the opcode, the funct3 field (bits 14:12) and funct7 field (bits
31:25) serve as an extended opcode field.

■	 The  first  register  operand  is  always  in  bit  positions  19:15  (rs1)  for  R-type
instructions and branch instructions. This field also specifies the base register
for load and store instructions.

■	 The second register operand is always in bit positions 24:20 (rs2) for R-type
instructions  and  branch  instructions.  This  field  also  specifies  the  register
operand that gets copied to memory for store instructions.

■	 Another  operand  can  also  be  a  12-bit  offset  for  branch  or  load-store

instructions.

■	 The  destination  register  is  always  in  bit  positions  11:7  (rd)  for  R-type

instructions and load instructions.

The first design principle from Chapter 2—simplicity favors regularity—pays off

here in specifying control.

4.4  A Simple Implementation Scheme

255

Add

4

PC

Read
address

Instruction
[31-0]

Instruction
memory

Instruction [19-15]

Instruction [24-20]

Instruction [11-7]

RegWrite

Shift
left 1

Read
register 1

Read
register 2

Write
register

Read
data 1

Read
data 2

Write
data

Registers

ALUSrc

0
M
u
x
1

Instruction [31-0]

32

64

Imm
Gen

Instruction [30,14-12]

ALU
control

ALUOp

PCSrc

0

M
u
x
1

Add

Sum

MemWrite

Zero

ALU

ALU
result

Address

Read
data

MemtoReg

1
M
u
x
0

Data
memory

Write
data

MemRead

FIGURE 4.15  The datapath of Figure 4.11 with all necessary multiplexors and all control
lines identified. The control lines are shown in color. The ALU control block has also been added, which
depends on the funct3 field and part of the funct7 field. The PC does not require a write control, since it is
written once at the end of every clock cycle; the branch control logic determines whether it is written with
the incremented PC or the branch target address.

Using this information, we can add the instruction labels to the simple datapath.
Figure 4.15 shows these additions plus the ALU control block, the write signals for
state elements, the read signal for the data memory, and the control signals for the
multiplexors. Since all the multiplexors have two inputs, they each require a single
control line.

Figure  4.15  shows  six  single-bit  control  lines  plus  the  2-bit  ALUOp  control
signal.  We  have  already  defined  how  the  ALUOp  control  signal  works,  and  it  is
useful to define what the six other control signals do informally before we determine
how to set these control signals during instruction execution. Figure 4.16 describes
the function of these six control lines.

Now  that  we  have  looked  at  the  function  of  each  of  the  control  signals,  we
can look at how to set them. The control unit can set all but one of the control
signals based solely on the opcode and funct fields of the instruction. The PCSrc
control line is the exception. That control line should be asserted if the instruction
is  branch  if  equal  (a  decision  that  the  control  unit  can  make)  and  the  Zero
output of the ALU, which is used for the equality test, is asserted. To generate the
PCSrc signal, we will need to AND together a signal from the control unit, which
we call Branch, with the Zero signal out of the ALU.

256

Chapter 4  The Processor

Signal name

Effect when deasserted

Effect when asserted

etirWgeR

.enoN

ALUSrc

The second ALU operand comes

 le output

(Read data 2).
The PC is replaced by the output of
the adder that computes the value
of PC + 4.
.enoN

PCSrc

daeRmeM

etirWmeM

.enoN

MemtoReg

The value fed to the register Write
data input comes from the ALU.

situpniretsigeretirWehtnoretsigerehT
written with the value on the Write data input.
The second ALU operand is the sign-extended,
12 bits of the instruction.

The PC is replaced by the output of the adder
that computes the branch target.

ehtybdetangisedstnetnocyromemataD
address input are put on the Read data
output.
ehtybdetangisedstnetnocyromemataD
address input are replaced by the value on
the Write data input.
The value fed to the register Write data input
comes from the data memory.

FIGURE 4.16  The effect of each of the six control signals. When the 1-bit control to a two-
way multiplexor is asserted, the multiplexor selects the input corresponding to 1. Otherwise, if the control
is deasserted, the multiplexor selects the 0 input. Remember that the state elements all have the clock as an
implicit input and that the clock is used in controlling writes. Gating the clock externally to a state element
can create timing problems. (See Appendix A for further discussion of this problem.)

These eight control signals (six from Figure 4.16 and two for ALUOp) can now
be set based on the input signals to the control unit, which are the opcode bits 6:0.
Figure 4.17 shows the datapath with the control unit and the control signals.

Before we try to write a set of equations or a truth table for the control unit, it
will be useful to try to define the control function informally. Because the setting
of the control lines depends only on the opcode, we define whether each control
signal should be 0, 1, or don’t care (X) for each of the opcode values. Figure 4.18
defines  how  the  control  signals  should  be  set  for  each  opcode;  this  information
follows directly from Figures 4.12, 4.16, and 4.17.

Operation of the Datapath

With the information contained in Figures 4.16 and 4.18, we can design the control
unit logic, but before we do that, let’s look at how each instruction uses the datapath.
In  the  next  few  figures,  we  show  the  flow  of  three  different  instruction  classes
through  the  datapath. The  asserted  control  signals  and  active  datapath  elements
are  highlighted  in  each  of  these.  Note  that  a  multiplexor  whose  control  is  0  has
a  definite  action,  even  if  its  control  line  is  not  highlighted.  Multiple-bit  control
signals are highlighted if any constituent signal is asserted.

Figure 4.19 shows the operation of the datapath for an R-type instruction, such
as add x1, x2, x3. Although everything occurs in one clock cycle, we can think

4.4  A Simple Implementation Scheme

257

Add

4

Instruction [6-0]

Control

Branch
MemRead
MemtoReg
ALUOp
MemWrite
ALUSrc
RegWrite

PC

Read
address

Instruction
[31-0]

Instruction
memory

Instruction [19-15]

Instruction [24-20]

Instruction [11-7]

Read
register 1

Read
register 2

Read
data 1

Write
register

Read
data 2

Write
data

Registers

0

M
u
x
1

Add

Sum

Shift
left 1

Zero

ALU

ALU
result

0
M
u
x
1

Address

Read
data

Write
data

Data
memory

1
M
u
x
0

Instruction [31-0]

32

64

Imm
Gen

ALU
control

Instruction [30,14-12]

FIGURE 4.17  The simple datapath with the control unit. The input to the control unit is the 7-bit opcode field from the instruction.
The outputs of the control unit consist of two 1-bit signals that are used to control multiplexors (ALUSrc and MemtoReg), three signals for
controlling reads and writes in the register file and data memory (RegWrite, MemRead, and MemWrite), a 1-bit signal used in determining
whether to possibly branch (Branch), and a 2-bit control signal for the ALU (ALUOp). An AND gate is used to combine the branch control
signal and the Zero output from the ALU; the AND gate output controls the selection of the next PC. Notice that PCSrc is now a derived signal,
rather than one coming directly from the control unit. Thus, we drop the signal name in subsequent figures.

of  four  steps  to  execute  the  instruction;  these  steps  are  ordered  by  the  flow  of
information:

1.  The instruction is fetched, and the PC is incremented.

2.  Two  registers,  x2  and  x3,  are  read  from  the  register  file;  also,  the  main

control unit computes the setting of the control lines during this step.

3.  The ALU operates on the data read from the register file, using portions of

the opcode to generate the ALU function.

4.  The result from the ALU is written into the destination register (x1) in the

register file.

258

Chapter 4  The Processor

Instruction ALUSrc

Memto-
Reg

Reg-
Write

Mem-
Read

Mem -
Write

Branch ALUOp1

ALUOp0

R-format
ld
sd
beq

0
1
1
0

0
1
X
X

1
1
0
0

0
1
0
0

0
0
1
0

0
0
0
1

1
0
0
0

0
0
0
1

FIGURE 4.18  The setting of the control lines is completely determined by the opcode fields of the instruction. The first
row of the table corresponds to the R-format instructions (add, sub, and, and or). For all these instructions, the source register fields are rs1
and rs2, and the destination register field is rd; this defines how the signals ALUSrc is set. Furthermore, an R-type instruction writes a register
(RegWrite = 1), but neither reads nor writes data memory. When the Branch control signal is 0, the PC is unconditionally replaced with PC +
4; otherwise, the PC is replaced by the branch target if the Zero output of the ALU is also high. The ALUOp field for R-type instructions is set
to 10 to indicate that the ALU control should be generated from the funct fields. The second and third rows of this table give the control signal
settings for ld and sd. These ALUSrc and ALUOp fields are set to perform the address calculation. The MemRead and MemWrite are set to
perform the memory access. Finally, RegWrite is set for a load to cause the result to be stored in the rd register. The ALUOp field for branch is
set for subtract (ALU control = 01), which is used to test for equality. Notice that the MemtoReg field is irrelevant when the RegWrite signal is
0: since the register is not being written, the value of the data on the register data write port is not used. Thus, the entry MemtoReg in the last
two rows of the table is replaced with X for don’t care. This type of don’t care must be added by the designer, since it depends on knowledge of
how the datapath works.

Add

4

Instruction [6–0]

Control

Branch
MemRead
MemtoReg
ALUOp
MemWrite
ALUSrc
RegWrite

PC

Read
address

Instruction
[31–0]

Instruction
memory

Instruction [19–15]

Instruction [24–20]

Instruction [11–7]

Read
register 1

Read
register 2

Read
data 1

Write
register

Read
data 2

Write
data

Registers

0

M
u
x
1

Add

Sum

Shift
left 1

Zero

ALU

ALU
result

0
M
u
x
1

Address

Read
data

Write
data

Data
memory

1
M
u
x
0

Instruction [31–0]

32

64

Imm
Gen

ALU
control

Instruction [30,14–12]

FIGURE 4.19  The datapath in operation for an R-type instruction, such as add x1, x2, x3. The control lines, datapath
units, and connections that are active are highlighted.

4.4  A Simple Implementation Scheme

259

Similarly, we can illustrate the execution of a load register, such as

ld  x1,  offset(x2)

in a style similar to Figure 4.19. Figure 4.20 shows the active functional units and
asserted control lines for a load. We can think of a load instruction as operating in
five steps (similar to how the R-type executed in four):

1.  An  instruction  is  fetched  from  the  instruction  memory,  and  the  PC  is

incremented.

2.  A register (x2) value is read from the register file.

3.  The ALU computes the sum of the value read from the register file and the

sign-extended 12 bits of the instruction (offset).

4.  The sum from the ALU is used as the address for the data memory.

5.  The data from the memory unit is written into the register file (x1).

Add

4

Instruction [6–0]

Control

Branch
MemRead
MemtoReg
ALUOp
MemWrite
ALUSrc
RegWrite

PC

Read
address

Instruction
[31–0]

Instruction
memory

Instruction [19–15]

Instruction [24–20]

Instruction [11–7]

Read
register 1

Read
register 2

Read
data 1

Write
register

Read
data 2

Write
data

Registers

0

M
u
x
1

Add

Sum

Shift
left 1

Zero

ALU

ALU
result

0
M
u
x
1

Address

Read
data

Write
data

Data
memory

1
M
u
x
0

Instruction [31–0]

32

64

Imm
Gen

ALU
control

Instruction [30,14-12]

FIGURE 4.20  The datapath in operation for a load instruction. The control lines, datapath units, and connections that are active
are highlighted. A store instruction would operate very similarly. The main difference would be that the memory control would indicate a write
rather than a read, the second register value read would be used for the data to store, and the operation of writing the data memory value to
the register file would not occur.

260

Chapter 4  The Processor

Finally, we can show the operation of the branch-if-equal instruction, such as
beq  x1,  x2,  offset,  in  the  same  fashion.  It  operates  much  like  an  R-format
instruction, but the ALU output is used to determine whether the PC is written with
PC + 4 or the branch target address. Figure 4.21 shows the four steps in execution:

1.  An  instruction  is  fetched  from  the  instruction  memory,  and  the  PC  is

incremented.

2.  Two registers, x1 and x2, are read from the register file.

3.  The ALU subtracts one data value from the other data value, both read from
the register file. The value of PC is added to the sign-extended, 12 bits of
the instruction (offset) left shifted by one; the result is the branch target
address.

4.  The Zero status information from the ALU is used to decide which adder

result to store in the PC.

Add

4

Instruction [6–0]

Control

Branch
MemRead
MemtoReg
ALUOp
MemWrite
ALUSrc
RegWrite

PC

Read
address

Instruction
[31–0]

Instruction
memory

Instruction [19–15]

Instruction [24–20]

Instruction [11–7]

Read
register 1

Read
register 2

Read
data 1

Write
register

Read
data 2

Write
data

Registers

0

M
u
x
1

Add

Sum

Shift
left 1

Zero

ALU

ALU
result

0
M
u
x
1

Address

Read
data

Write
data

Data
memory

1
M
u
x
0

Instruction [31–0]

32

64

Imm
Gen

ALU
control

Instruction [30,14-12]

FIGURE 4.21  The datapath in operation for a branch-if-equal instruction. The control lines, datapath units, and connections
that are active are highlighted. After using the register file and ALU to perform the compare, the Zero output is used to select the next program
counter from between the two candidates.

4.4  A Simple Implementation Scheme

261

Finalizing Control

Now that we have seen how the instructions operate in steps, let’s continue with
the control implementation. The control function can be precisely defined using
the contents of Figure 4.18. The outputs are the control lines, and the inputs are the
opcode bits. Thus, we can create a truth table for each of the outputs based on the
binary encoding of the opcodes.

Figure  4.22  defines  the  logic  in  the  control  unit  as  one  large  truth  table  that
combines  all  the  outputs  and  that  uses  the  opcode  bits  as  inputs.  It  completely
specifies  the  control  function,  and  we  can  implement  it  directly  in  gates  in  an
automated fashion. We show this final step in Section C.2 in

 Appendix C.

Why a Single-Cycle Implementation is not Used Today

Although the single-cycle design will work correctly, it is too inefficient to be used
in modern designs. To see why this is so, notice that the clock cycle must have the
same length for every instruction in this single-cycle design. Of course, the longest
possible path in the processor determines the clock cycle. This path is most likely a
load instruction, which uses five functional units in series: the instruction memory,

Input or
output

stupnI

Outputs

Signal name

R-format

ld

sd

beq

]6[I
I[5]
I[4]
I[3]
I[2]
I[1]
I[0]
ALUSrc
MemtoReg
RegWrite
MemRead
MemWrite
Branch
ALUOp1
ALUOp0

0
1
1
0
0
1
1
0
0
1
0
0
0
1
0

0
0
0
0
0
1
1
1
1
1
1
0
0
0
0

0
1
0
0
0
1
1
1
X
0
0
1
0
0
0

1
1
0
0
0
1
1
0
X
0
0
0
1
0
1

FIGURE  4.22  The  control  function  for  the  simple  single-cycle  implementation  is
completely specified by this truth table. The top half of the table gives the combinations of input
signals that correspond to the four instruction classes, one per column, that determine the control output
settings. The bottom portion of the table gives the outputs for each of the four opcodes. Thus, the output
RegWrite is asserted for two different combinations of the inputs. If we consider only the four opcodes shown
in this table, then we can simplify the truth table by using don’t cares in the input portion. For example, we
can detect an R-format instruction with the expression Op4 ∙ Op5, since this is sufficient to distinguish the
R-format instructions from ld, sd, and beq. We do not take advantage of this simplification, since the rest
of the RISC-V opcodes are used in a full implementation.

262

Chapter 4  The Processor

the register file, the ALU, the data memory, and the register file. Although the CPI
is 1 (see Chapter 1), the overall performance of a single-cycle implementation is
likely to be poor, since the clock cycle is too long.

The penalty for using the single-cycle design with a fixed clock cycle is significant,
but might be considered acceptable for this small instruction set. Historically, early
computers with very simple instruction sets did use this implementation technique.
However, if we tried to implement the floating-point unit or an instruction set with
more complex instructions, this single-cycle design wouldn’t work well at all.

Because we must assume that the clock cycle is equal to the worst-case delay
for all instructions, it’s useless to try implementation techniques that reduce the
delay of the common case but do not improve the worst-case cycle time. A single-
cycle implementation thus violates the great idea from Chapter 1 of making the
common case fast.

In  next  section,  we’ll  look  at  another  implementation  technique,  called
pipelining,  that  uses  a  datapath  very  similar  to  the  single-cycle  datapath  but  is
much  more  efficient  by  having  a  much  higher  throughput.  Pipelining  improves
efficiency by executing multiple instructions simultaneously.

Check
Yourself

Look at the control signals in Figure 4.22. Can you combine any together? Can
any control signal output in the figure be replaced by the inverse of another?
(Hint: take into account the don’t cares.) If so, can you use one signal for the other
without adding an inverter?

Never waste time.
American proverb

pipelining  An
implementation technique
in which multiple
instructions are overlapped
in execution, much like an
assembly line.

  4.5

An Overview of Pipelining

Pipelining  is  an  implementation  technique  in  which  multiple  instructions  are
overlapped in execution. Today, pipelining is nearly universal.

This section relies heavily on one analogy to give an overview of the pipelining
terms and issues. If you are interested in just the big picture, you should concentrate
on  this  section  and  then  skip  to  Sections  4.10  and  4.11  to  see  an  introduction
to  the  advanced  pipelining  techniques  used  in  recent  processors  such  as  the
Intel  Core  i7  and  ARM  Cortex-A53.  If  you  are  curious  about  exploring  the
anatomy of a pipelined computer, this section is a good introduction to Sections 4.6
through 4.9.

Anyone who has done a lot of laundry has intuitively used pipelining. The non-

pipelined approach to laundry would be as follows:

1.  Place one dirty load of clothes in the washer.

2.  When the washer is finished, place the wet load in the dryer.

3.  When the dryer is finished, place the dry load on a table and fold.

4.  When folding is finished, ask your roommate to put the clothes away.

4.5  An Overview of Pipelining

263

When your roommate is done, start over with the next dirty load.

The pipelined approach takes much less time, as Figure 4.23 shows. As soon as the
washer is finished with the first load and placed in the dryer, you load the washer
with the second dirty load. When the first load is dry, you place it on the table to start
folding, move the wet load to the dryer, and put the next dirty load into the washer.
Next, you have your roommate put the first load away, you start folding the second
load, the dryer has the third load, and you put the fourth load into the washer. At this
point all steps—called stages in pipelining—are operating concurrently. As long as we
have separate resources for each stage, we can pipeline the tasks.

The pipelining paradox is that the time from placing a single dirty sock in the
washer until it is dried, folded, and put away is not shorter for pipelining; the reason
pipelining is faster for many loads is that everything is working in parallel, so more
loads are finished per hour. Pipelining improves throughput of our laundry system.
Hence, pipelining would not decrease the time to complete one load of laundry,

(cid:31)(cid:31)(cid:31)(cid:31)

(cid:31)

(cid:31)

(cid:31)

(cid:31) (cid:31)

(cid:31) (cid:31)

(cid:31)

(cid:31)

(cid:31)

(cid:31)(cid:31)A(cid:31)

(cid:31)(cid:31)(cid:31)(cid:31)

(cid:31)

(cid:31)

(cid:31)

(cid:31) (cid:31)

(cid:31) (cid:31)

(cid:31)

(cid:31)

(cid:31)

(cid:31)(cid:31)A(cid:31)

Time

Task
order

A

B

C

D

Time

Task
order

A

B

C

D

FIGURE  4.23  The  laundry  analogy  for  pipelining.  Ann,  Brian,  Cathy,  and  Don  each  have  dirty
clothes  to  be  washed,  dried,  folded,  and  put  away.  The  washer,  dryer,  “folder,”  and  “storer”  each  take  30
minutes for their task. Sequential laundry takes 8 hours for four loads of washing, while pipelined laundry
takes just 3.5 hours. We show the pipeline stage of different loads over time by showing copies of the four
resources on this two-dimensional time line, but we really have just one of each resource.

264

Chapter 4  The Processor

but when we have many loads of laundry to do, the improvement in throughput
decreases the total time to complete the work.

If all the stages take about the same amount of time and there is enough work
to do, then the speed-up due to pipelining is equal to the number of stages in the
pipeline, in this case four: washing, drying, folding, and putting away. Therefore,
pipelined laundry is potentially four times faster than nonpipelined: 20 loads would
take about five times as long as one load, while 20 loads of sequential laundry takes
20 times as long as one load. It’s only 2.3 times faster in Figure 4.23, because we
only show four loads. Notice that at the beginning and end of the workload in the
pipelined version in Figure 4.23, the pipeline is not completely full; this start-up and
wind-down affects performance when the number of tasks is not large compared
to the number of stages in the pipeline. If the number of loads is much larger than
four, then the stages will be full most of the time and the increase in throughput
will be very close to four.

The  same  principles  apply  to  processors  where  we  pipeline  instruction

execution. RISC-V instructions classically take five steps:

1.  Fetch instruction from memory.

2.  Read registers and decode the instruction.

3.  Execute the operation or calculate an address.

4.  Access an operand in data memory (if necessary).

5.  Write the result into a register (if necessary).

Hence,  the  RISC-V  pipeline  we  explore  in  this  chapter  has  five  stages.  The
following example shows that pipelining speeds up instruction execution just as it
speeds up the laundry.

EXAMPLE

Single-Cycle versus Pipelined Performance

To make this discussion concrete, let’s create a pipeline. In this example, and
in the rest of this chapter, we limit our attention to seven instructions: load
doubleword  (ld),  store  doubleword  (sd),  add  (add),  subtract  (sub),  AND
(and), OR (or), and branch if equal (beq).
Contrast  the  average  time  between

instructions  of  a  single-cycle
implementation, in which all instructions take one clock cycle, to a pipelined
implementation.  Assume  that  the  operation  times  for  the  major  functional
units in this example are 200 ps for memory access for instructions or data,
200 ps  for  ALU  operation,  and  100 ps  for  register  file  read  or  write.  In  the

4.5  An Overview of Pipelining

265

ANSWER

single-cycle model, every instruction takes exactly one clock cycle, so the clock
cycle must be stretched to accommodate the slowest instruction.

Figure  4.24  shows  the  time  required  for  each  of  the  seven  instructions. The
single-cycle design must allow for the slowest instruction—in Figure 4.24 it
is ld—so the time required for every instruction is 800 ps. Similarly to Figure
4.23, Figure 4.25 compares nonpipelined and pipelined execution of three load
register instructions. Thus, the time between the first and fourth instructions
in the nonpipelined design is 3 × 800 ps or 2400 ps.

All the pipeline stages take a single clock cycle, so the clock cycle must be
long  enough  to  accommodate  the  slowest  operation.  Just  as  the  single-cycle
design  must  take  the  worst-case  clock  cycle  of  800 ps,  even  though  some
instructions can be as fast as 500 ps, the pipelined execution clock cycle must
have the worst-case clock cycle of 200 ps, even though some stages take only
100 ps.  Pipelining  still  offers  a  fourfold  performance  improvement:  the  time
between the first and fourth instructions is 3 × 200 ps or 600 ps.

We  can  turn  the  pipelining  speed-up  discussion  above  into  a  formula.  If  the
stages are perfectly balanced, then the time between instructions on the pipelined
processor—assuming ideal conditions—is equal to

Time between instructions

pipelined

=

Time between instructions

no
Number of pipestages

nnpipelined

Under ideal conditions and with a large number of instructions, the speed-up
from pipelining is approximately equal to the number of pipe stages; a five-stage
pipeline is nearly five times faster.

The  formula  suggests  that  a  five-stage  pipeline  should  offer  nearly  a  fivefold
improvement  over  the  800 ps  nonpipelined  time,  or  a  160 ps  clock  cycle.  The

Instruction class

Load doubleword (ld)
Store doubleword (sd)
R-format (add, sub,
and, or)
)qeb(hcnarB

Instruction
fetch

Register
read

ALU
operation

Data
access

Register
write

Total
time

200 ps
200 ps
200 ps

100 ps
100 ps
100 ps

200 ps
200 ps
200 ps

200 ps
200 ps

100 ps

100 ps

sp002

sp001

sp002

800 ps
700 ps
600 ps

sp005

FIGURE 4.24  Total time for each instruction calculated from the time for each component.
This calculation assumes that the multiplexors, control unit, PC accesses, and sign extension unit have no
delay.

266

Chapter 4  The Processor

Program
execution
order
(in instructions)

Time

ld x1, 100(x4)

ld x2, 200(x4)

ld x3, 400(x4)

Program
execution
order
(in instructions)

Time

ld x1, 100(x4)

ld x2, 200(x4)

ld x3, 400(x4)

200

400

600

800

1000

1200

1400

1600

1800

Instruction
fetch

Reg

ALU

Data
access

Reg

800 ps

Instruction
fetch

Reg

ALU

Data
access

Reg

800 ps

Instruction
fetch

800 ps

200

400

600

800

1000

1200

1400

Instruction
fetch

Reg

ALU

Data
access

Reg

200 ps

Instruction
fetch

Reg

ALU

Data
access

Reg

200 ps

Instruction
fetch

Reg

ALU

Data
access

Reg

200 ps 200 ps 200 ps 200 ps 200 ps

FIGURE  4.25  Single-cycle,  nonpipelined  execution  (top)  versus  pipelined  execution
(bottom). Both use the same hardware components, whose time is listed in Figure 4.24. In this case, we see
a fourfold speed-up on average time between instructions, from 800 ps down to 200 ps. Compare this figure
to Figure 4.23. For the laundry, we assumed all stages were equal. If the dryer were slowest, then the dryer
stage would set the stage time. The pipeline stage times of a computer are also limited by the slowest resource,
either the ALU operation or the memory access. We assume the write to the register file occurs in the first
half of the clock cycle and the read from the register file occurs in the second half. We use this assumption
throughout this chapter.

example shows, however, that the stages may be imperfectly balanced. Moreover,
pipelining  involves  some  overhead,  the  source  of  which  will  be  clearer  shortly.
Thus, the time per instruction in the pipelined processor will exceed the minimum
possible, and speed-up will be less than the number of pipeline stages.

However, even our claim of fourfold improvement for our example is not reflected
in the total execution time for the three instructions: it’s 1400 ps versus 2400 ps. Of
course, this is because the number of instructions is not large. What would happen
if we increased the number of instructions? We could extend the previous figures
to  1,000,003  instructions.  We  would  add  1,000,000  instructions  in  the  pipelined
example; each instruction adds 200 ps to the total execution time. The total execution
time would be 1,000,000 × 200 ps + 1400 ps, or 200,001,400 ps. In the nonpipelined
example, we would add 1,000,000 instructions, each taking 800 ps, so total execution
time  would  be  1,000,000  ×  800 ps  +  2400 ps,  or  800,002,400 ps.  Under  these

4.5  An Overview of Pipelining

267

conditions, the ratio of total execution times for real programs on nonpipelined to
pipelined processors is close to the ratio of times between instructions:

800 002 400
200 001 400

,
,

,
,

 ps
 ps

(cid:31)

800
200

 ps
 ps

(cid:31)

.
4 00

Pipelining  improves  performance  by  increasing  instruction  throughput,  in
contrast to decreasing the execution time of an individual instruction, but instruction
throughput  is  the  important  metric  because  real  programs  execute  billions  of
instructions.

Designing Instruction Sets for Pipelining

Even with this simple explanation of pipelining, we can get insight into the design
of the RISC-V instruction set, which was designed for pipelined execution.

First, all RISC-V instructions are the same length. This restriction makes it much
easier  to  fetch  instructions  in  the  first  pipeline  stage  and  to  decode  them  in  the
second stage. In an instruction set like the x86, where instructions vary from 1 byte
to 15 bytes, pipelining is considerably more challenging. Modern implementations
of the x86 architecture actually translate x86 instructions into simple operations
that look like RISC-V instructions and then pipeline the simple operations rather
than the native x86 instructions! (See Section 4.10.)

Second,  RISC-V  has  just  a  few  instruction  formats,  with  the  source  and

destination register fields being located in the same place in each instruction.

Third,  memory  operands  only  appear  in  loads  or  stores  in  RISC-V.  This
restriction means we can use the execute stage to calculate the memory address and
then access memory in the following stage. If we could operate on the operands in
memory, as in the x86, stages 3 and 4 would expand to an address stage, memory
stage, and then execute stage. We will shortly see the downside of longer pipelines.

Pipeline Hazards

There are situations in pipelining when the next instruction cannot execute in the
following clock cycle. These events are called hazards, and there are three different
types.

Structural Hazard

The first hazard is called a structural hazard. It means that the hardware cannot
support the combination of instructions that we want to execute in the same clock
cycle. A structural hazard in the laundry room would occur if we used a washer-
dryer combination instead of a separate washer and dryer, or if our roommate was
busy doing something else and wouldn’t put clothes away. Our carefully scheduled
pipeline plans would then be foiled.

structural hazard  When
a planned instruction
cannot execute in the
proper clock cycle because
the hardware does not
support the combination
of instructions that are set
to execute.

268

Chapter 4  The Processor

As  we  said  above,  the  RISC-V  instruction  set  was  designed  to  be  pipelined,
making it fairly easy for designers to avoid  structural hazards when designing a
pipeline. Suppose, however, that we had a single memory instead of two memories.
If the pipeline in Figure 4.25 had a fourth instruction, we would see that in the
same  clock  cycle,  the  first  instruction  is  accessing  data  from  memory  while  the
fourth instruction is fetching an instruction from that same memory. Without two
memories, our pipeline could have a structural hazard.

Data Hazards

data hazard  Also
called a pipeline data
hazard. When a planned
instruction cannot
execute in the proper
clock cycle because data
that are needed to execute
the instruction are not yet
available.

Data hazards occur when the pipeline must be stalled because one step must wait
for another to complete. Suppose you found a sock at the folding station for which
no match existed. One possible strategy is to run down to your room and search
through your clothes bureau to see if you can find the match. Obviously, while you
are doing the search, loads that have completed drying are ready to fold and those
that have finished washing are ready to dry.

In  a  computer  pipeline,  data  hazards  arise  from  the  dependence  of  one
instruction on an earlier one that is still in the pipeline (a relationship that does not
really exist when doing laundry). For example, suppose we have an add instruction
followed immediately by a subtract instruction that uses that sum (x19):

add  x19, x0, x1
sub  x2, x19, x3

forwarding  Also called
bypassing. A method of
resolving a data hazard
by retrieving the missing
data element from
internal buffers rather
than waiting for it to
arrive from programmer-
visible registers or
memory.

Without intervention, a data hazard could severely stall the pipeline. The add
instruction doesn’t write its result until the fifth stage, meaning that we would have
to waste three clock cycles in the pipeline.

Although  we  could  try  to  rely  on  compilers  to  remove  all  such  hazards,  the
results would not be satisfactory. These dependences happen just too often and the
delay is far too long to expect the compiler to rescue us from this dilemma.

The primary solution is based on the observation that we don’t need to wait for
the instruction to complete before trying to resolve the data hazard. For the code
sequence above, as soon as the ALU creates the sum for the add, we can supply it as
an input for the subtract. Adding extra hardware to retrieve the missing item early
from the internal resources is called forwarding or bypassing.

EXAMPLE

Forwarding with Two Instructions

For the two instructions above, show what pipeline stages would be connected
by forwarding. Use the drawing in Figure 4.26 to represent the datapath during
the five stages of the pipeline. Align a copy of the datapath for each instruction,
similar to the laundry pipeline in Figure 4.23.

4.5  An Overview of Pipelining

269

Time

200

400

600

800

1000

add x1, x2, x3

IF

ID

EX

MEM

WB

FIGURE  4.26  Graphical  representation  of  the  instruction  pipeline,  similar  in  spirit  to
the  laundry  pipeline  in  Figure  4.23.  Here we use symbols representing the physical resources with
the  abbreviations  for  pipeline  stages  used  throughout  the  chapter.  The  symbols  for  the  five  stages:  IF  for
the instruction fetch stage, with the box representing instruction memory; ID for the instruction decode/
register  file  read  stage,  with  the  drawing  showing  the  register  file  being  read;  EX  for  the  execution  stage,
with the drawing representing the ALU; MEM for the memory access stage, with the box representing data
memory;  and  WB  for  the  write-back  stage,  with  the  drawing  showing  the  register  file  being  written. The
shading indicates the element is used by the instruction. Hence, MEM has a white background because add
does not access the data memory. Shading on the right half of the register file or memory means the element
is read in that stage, and shading of the left half means it is written in that stage. Hence the right half of ID is
shaded in the second stage because the register file is read, and the left half of WB is shaded in the fifth stage
because the register file is written.

Figure  4.27  shows  the  connection  to  forward  the  value  in  x1  after  the
execution stage of the add instruction as input to the execution stage of the
sub instruction.

ANSWER

In this graphical representation of events, forwarding paths are valid only if the
destination stage is later in time than the source stage. For example, there cannot
be a valid forwarding path from the output of the memory access stage in the first
instruction to the input of the execution stage of the following, since that would
mean going backward in time.

Forwarding works very well and is described in detail in Section 4.7. It cannot
prevent all pipeline stalls, however. For example, suppose the first instruction was
a load of x1 instead of an add. As we can imagine from looking at Figure 4.27, the

Program
execution
order
(in instructions)

Time

200

400

600

800

1000

add x1, x2, x3

IF

ID

EX

MEM

WB

sub x4, x1, x5

IF

ID

EX

MEM

WB

FIGURE 4.27  Graphical representation of forwarding. The connection shows the forwarding path
from the output of the EX stage of add to the input of the EX stage for sub, replacing the value from register
x1 read in the second stage of sub.

270

Chapter 4  The Processor

Program
execution
order
(in instructions)

Time

200

400

600

800

1000

1200

1400

ld x1, 0(x2)

IF

ID

EX

MEM

WB

bubble

bubble

bubble

bubble

bubble

sub x4, x1, x5

IF

ID

EX

MEM

WB

FIGURE 4.28  We need a stall even with forwarding when an R-format instruction following
a load tries to use the data. Without the stall, the path from memory access stage output to execution
stage input would be going backward in time, which is impossible. This figure is actually a simplification,
since we cannot know until after the subtract instruction is fetched and decoded whether or not a stall will be
necessary. Section 4.7 shows the details of what really happens in the case of a hazard.

desired data would be available only after the fourth stage of the first instruction
in the dependence, which is too late for the input of the third stage of sub. Hence,
even with forwarding, we would have to stall one stage for a load-use data hazard,
as Figure 4.28 shows. This figure shows an important pipeline concept, officially
called  a  pipeline  stall,  but  often  given  the  nickname  bubble.  We  shall  see  stalls
elsewhere  in  the  pipeline.  Section  4.7  shows  how  we  can  handle  hard  cases  like
these, using either hardware detection and stalls or software that reorders code to
try to avoid load-use pipeline stalls, as this example illustrates.

load-use data hazard
A specific form of data
hazard in which the
data being loaded by a
load instruction have
not yet become available
when they are needed by
another instruction.

pipeline stall  Also called
bubble. A stall initiated
in order to resolve a
hazard.

Reordering Code to Avoid Pipeline Stalls

EXAMPLE

Consider the following code segment in C:

a = b + e;
c = b + f;

Here is the generated RISC-V code for this segment, assuming all variables

are in memory and are addressable as offsets from x31:

x1, 0(x31)  // Load b
x2, 8(x31)  // Load e

ld
ld
add     x3, x1, x2  // b + e
sd
ld
add     x5, x1, x4  // b + f
sd

x3, 24(x31)  // Store a
x4, 16(x31)  // Load f

x5, 32(x31)  // Store c

4.5  An Overview of Pipelining

271

Find the hazards in the preceding code segment and reorder the instructions
to avoid any pipeline stalls.

Both add instructions have a hazard because of their respective dependence
on  the  previous  ld  instruction.  Notice  that  forwarding  eliminates  several
other potential hazards, including the dependence of the first add on the first
ld and any hazards for store instructions. Moving up the third ld instruction
to become the third instruction eliminates both hazards:

ANSWER

ld    x1, 0(x31)
ld    x2, 8(x31)
ld    x4, 16(x31)
add   x3,   x1, x2
sd    x3, 24(x31)
add   x5, x1, x4
sd    x5, 32(x31)

On  a  pipelined  processor  with  forwarding,  the  reordered  sequence  will
complete in two fewer cycles than the original version.

Forwarding yields another insight into the RISC-V architecture, in addition
to  the  three  mentioned  on  page  267.  Each  RISC-V  instruction  writes  at  most
one result and does this in the last stage of the pipeline. Forwarding is harder if
there are multiple results to forward per instruction or if there is a need to write
a result early on in instruction execution.

Elaboration:  The name “forwarding” comes from the idea that the result is passed
forward  from  an  earlier  instruction  to  a  later  instruction.  “Bypassing”  comes  from
passing the result around the register file to the desired unit.

Control Hazards

The third type of hazard is called a control hazard, arising from the need to make a
decision based on the results of one instruction while others are executing.

Suppose our laundry crew was given the happy task of cleaning the uniforms
of a football team. Given how filthy the laundry is, we need to determine whether
the detergent and water temperature setting we select are strong enough to get the
uniforms clean but not so strong that the uniforms wear out sooner. In our laundry
pipeline, we have to wait until the second stage to examine the dry uniform to see
if we need to change the washer setup or not. What to do?

Here is the first of two solutions to control hazards in the laundry room and its

computer equivalent.

Stall: Just operate sequentially until the first batch is dry and then repeat until

you have the right formula.

control hazard  Also
called branch hazard.
When the proper
instruction cannot
execute in the proper
pipeline clock cycle
because the instruction
that was fetched is not the
one that is needed; that
is, the flow of instruction
addresses is not what the
pipeline expected.

This conservative option certainly works, but it is slow.

272

Chapter 4  The Processor

The equivalent decision task in a computer is the conditional branch instruction.
Notice  that  we  must  begin  fetching  the  instruction  following  the  branch  on  the
following  clock  cycle.  Nevertheless,  the  pipeline  cannot  possibly  know  what  the
next instruction should be, since it only just received the branch instruction from
memory! Just as with laundry, one possible solution is to stall immediately after we
fetch a branch, waiting until the pipeline determines the outcome of the branch
and knows what instruction address to fetch from.

Let’s assume that we put in enough extra hardware so that we can test a register,
calculate  the  branch  address,  and  update  the  PC  during  the  second  stage  of  the
pipeline (see Section 4.8 for details). Even with this added hardware, the pipeline
involving conditional branches would look like Figure 4.29. The instruction to be
executed if the branch fails is stalled one extra 200 ps clock cycle before starting.

EXAMPLE

Performance of “Stall on Branch”

Estimate  the  impact  on  the  clock  cycles  per  instruction  (CPI)  of  stalling  on
branches. Assume all other instructions have a CPI of 1.

ANSWER

Figure  3.28  in  Chapter  3  shows  that  conditional  branches  are  17%  of  the
instructions executed in SPECint2006. Since the other instructions run have a
CPI of 1, and conditional branches took one extra clock cycle for the stall, then
we would see a CPI of 1.17 and hence a slowdown of 1.17 versus the ideal case.

Program
execution
order
(in instructions)

Time

200

400

600

800

1000

1200

1400

add x4, x5, x6

Instruction
fetch

Reg

ALU

Data
access

Reg

beq x1, x0, 40

Instruction
fetch

200 ps

Reg

ALU

Data
access

Reg

or x7, x8, x9

400 ps

Instruction
fetch

Reg

ALU

Data
access

Reg

bubble bubble bubble bubble bubble

FIGURE 4.29  Pipeline showing stalling on every conditional branch as solution to control
hazards. This example assumes the conditional branch is taken, and the instruction at the destination of
the branch is the or instruction. There is a one-stage pipeline stall, or bubble, after the branch. In reality, the
process of creating a stall is slightly more complicated, as we will see in Section 4.8. The effect on performance,
however, is the same as would occur if a bubble were inserted.

4.5  An Overview of Pipelining

273

If we cannot resolve the branch in the second stage, as is often the case for longer
pipelines, then we’d see an even larger slowdown if we stall on conditional branches.
The cost of this option is too high for most computers to use and motivates a second
solution to the control hazard using one of our great ideas from Chapter 1:

Predict: If you’re sure you have the right formula to wash uniforms, then just
predict that it will work and wash the second load while waiting for the first load
to dry.

This option does not slow down the pipeline when you are correct. When you
are wrong, however, you need to redo the load that was washed while guessing the
decision.

Computers  do  indeed  use  prediction  to  handle  conditional  branches.  One
simple  approach  is  to  predict  always  that  conditional  branches  will  be  untaken.
When  you’re  right,  the  pipeline  proceeds  at  full  speed.  Only  when  conditional
branches are taken does the pipeline stall. Figure 4.30 shows such an example.

Program
execution
order
(in instructions)

Time

200

400

600

800

1000

1200

1400

add x4, x5, x6

Instruction
fetch

Reg

ALU

Data
access

Reg

beq x1, x0, 40

ld x3, 400(x0)

Instruction
fetch

200 ps

Reg

ALU

Data
access

Reg

200 ps

Instruction
fetch

Reg

ALU

Data
access

Reg

Program
execution
order
(in instructions)

Time

200

400

600

800

1000

1200

1400

add x4, x5, x6

Instruction
fetch

Reg

ALU

Data
access

Reg

beq x1, x0, 40

Instruction
fetch

200 ps

Reg

ALU

Data
access

Reg

bubble bubble bubble bubble bubble

or x7, x8, x9

400 ps

Instruction
fetch

Reg

ALU

Data
access

Reg

FIGURE 4.30  Predicting that branches are not taken as a solution to control hazard. The
top drawing shows the pipeline when the branch is not taken. The bottom drawing shows the pipeline when
the branch is taken. As we noted in Figure 4.29, the insertion  of a bubble  in this fashion simplifies what
actually happens, at least during the first clock cycle immediately following the branch. Section 4.8 will reveal
the details.

274

Chapter 4  The Processor

branch prediction
A method of resolving
a branch hazard that
assumes a given outcome
for the conditional branch
and proceeds from that
assumption rather than
waiting to ascertain the
actual outcome.

A more sophisticated version of branch prediction would have some conditional
branches  predicted  as  taken  and  some  as  untaken.  In  our  analogy,  the  dark  or
home  uniforms  might  take  one  formula  while  the  light  or  road  uniforms  might
take another. In the case of programming, at the bottom of loops are conditional
branches that branch back to the top of the loop. Since they are likely to be taken
and they branch backward, we could always predict taken for conditional branches
that branch to an earlier address.

Such  rigid  approaches  to  branch  prediction  rely  on  stereotypical  behavior
and don’t account for the individuality of a specific branch instruction. Dynamic
hardware  predictors,  in  stark  contrast,  make  their  guesses  depending  on  the
behavior of each conditional branch and may change predictions for a conditional
branch over the life of a program. Following our analogy, in dynamic prediction a
person would look at how dirty the uniform was and guess at the formula, adjusting
the next prediction depending on the success of recent guesses.

One popular approach to dynamic prediction of conditional branches is keeping
a  history  for  each  conditional  branch  as  taken  or  untaken,  and  then  using  the
recent  past  behavior  to  predict  the  future.  As  we  will  see  later,  the  amount  and
type  of  history  kept  have  become  extensive,  with  the  result  being  that  dynamic
branch predictors can correctly predict conditional branches with more than 90%
accuracy  (see  Section  4.8).  When  the  guess  is  wrong,  the  pipeline  control  must
ensure  that  the  instructions  following  the  wrongly  guessed  conditional  branch
have no effect and must restart the pipeline from the proper branch address. In our
laundry analogy, we must stop taking new loads so that we can restart the load that
we incorrectly predicted.

As in the case of all other solutions to control hazards, longer pipelines exacerbate
the problem, in this case by raising the cost of misprediction. Solutions to control
hazards are described in more detail in Section 4.8.

Elaboration:  There is a third approach to the control hazard, called a delayed decision.
In our analogy, whenever you are going to make such a decision about laundry, just place
a load of non-football clothes in the washer while waiting for football uniforms to dry.
As long as you have enough dirty clothes that are not affected by the test, this solution
works fine.

Called  the  delayed  branch  in  computers,  this  is  the  solution  actually  used  by  the
MIPS architecture. The delayed branch always executes the next sequential instruction,
with the branch taking place after that one instruction delay. It is hidden from the MIPS
assembly language programmer because the assembler can automatically arrange the
instructions to get the branch behavior desired by the programmer. MIPS software will
place an instruction immediately after the delayed branch instruction that is not affected
by the branch, and a taken branch changes the address of the instruction that follows
this safe instruction. In our example, the add instruction before the branch in Figure
4.29 does not affect the branch and can be moved after the branch to hide the branch
delay fully. Since delayed branches are useful when the branches are short, it is rare to
see a processor with a delayed branch of more than one cycle. For longer branch delays,
hardware-based branch prediction is usually used.

4.5  An Overview of Pipelining

275

Pipeline Overview Summary

Pipelining  is  a  technique  that  exploits  parallelism  between  the  instructions  in
a  sequential  instruction  stream.  It  has  the  substantial  advantage  that,  unlike
programming a multiprocessor (see Chapter 6), it is fundamentally invisible to the
programmer.

In the next few sections of this chapter, we cover the concept of pipelining using
the  RISC-V  instruction  subset  from  the  single-cycle  implementation  in  Section
4.4 and show a simplified version of its pipeline. We then look at the problems that
pipelining introduces and the performance attainable under typical situations.

If you wish to focus more on the software and the performance implications of
pipelining,  you  now  have  sufficient  background  to  skip  to  Section  4.10.  Section
4.10  introduces  advanced  pipelining  concepts,  such  as  superscalar  and  dynamic
scheduling, and Section 4.11 examines the pipelines of recent microprocessors.

Alternatively, if you are interested in understanding how pipelining is implemented
and the challenges of dealing with hazards, you can proceed to examine the design
of a pipelined datapath and the basic control, explained in Section 4.6. You can then
use this understanding to explore the implementation of forwarding and stalls in
Section 4.7. You can next read Section 4.8 to learn more about solutions to branch
hazards, and finally see how exceptions are handled in Section 4.9.

For each code sequence below, state whether it must stall, can avoid stalls using
only forwarding, or can execute without stalling or forwarding.

Check
Yourself

Sequence 1

Sequence 2

Sequence 3

ld   x10, 0(x10)

add   x11, x10, x10

addi  x11, x10, 1

add  x11, x10, x10

addi  x12, x10, 5

addi  x12, x10, 2

addi  x14, x11, 5

addi  x13, x10, 3

addi  x14, x10, 4

addi  x15, x10, 5

Outside  the  memory  system,  the  effective  operation  of  the  pipeline  is  usually
the most important factor in determining the CPI of the processor and hence its
performance. As we will see in Section 4.10, understanding the performance of a
modern multiple-issue pipelined processor is complex and requires understanding
more than just the issues that arise in a simple pipelined processor. Nonetheless,
structural,  data,  and  control  hazards  remain  important  in  both  simple  pipelines
and more sophisticated ones.

For modern pipelines, structural hazards usually revolve around the floating-
point  unit,  which  may  not  be  fully  pipelined,  while  control  hazards  are  usually
more  of  a  problem  in  integer  programs,  which  tend  to  have  higher  conditional
branch  frequencies  as  well  as  less  predictable  branches.  Data  hazards  can  be

Understanding
Program
Performance

276

Chapter 4  The Processor

The BIG
Picture

latency (pipeline)  The
number of stages in a
pipeline or the number
of stages between two
instructions during
execution.

There is less in this
than meets the eye.
Tallulah
Bankhead, remark
to Alexander
Woollcott, 1922

performance  bottlenecks  in  both  integer  and  floating-point  programs.  Often  it
is easier to deal with data hazards in floating-point programs because the lower
conditional branch frequency and more regular memory access patterns allow the
compiler  to  try  to  schedule  instructions  to  avoid  hazards.  It  is  more  difficult  to
perform  such  optimizations  in  integer  programs  that  have  less  regular  memory
accesses, involving more use of pointers. As we will see in Section 4.10, there are
more ambitious compiler and hardware techniques for reducing data dependences
through scheduling.

Pipelining increases the number of simultaneously executing instructions
and the rate at which instructions are started and completed. Pipelining
does not reduce the time it takes to complete an individual instruction,
also called the latency. For example, the five-stage pipeline still takes five
clock cycles for the instruction to complete. In the terms used in Chapter 1,
pipelining  improves  instruction  throughput  rather  than  individual
instruction execution time or latency.

Instruction  sets  can  either  make  life  harder  or  simpler  for  pipeline
designers,  who  must  already  cope  with  structural,  control,  and  data
hazards.  Branch  prediction  and  forwarding  help  make  a  computer  fast
while still getting the right answers.

  4.6

Pipelined Datapath and Control

Figure  4.31  shows  the  single-cycle  datapath  from  Section  4.4  with  the  pipeline
stages identified. The division of an instruction into five stages means a five-stage
pipeline,  which  in  turn  means  that  up  to  five  instructions  will  be  in  execution
during any single clock cycle. Thus, we must separate the datapath into five pieces,
with each piece named corresponding to a stage of instruction execution:

1.  IF: Instruction fetch

2.  ID: Instruction decode and register file read

3.  EX: Execution or address calculation

4.  MEM: Data memory access

5.  WB: Write back

In Figure 4.31, these five components correspond roughly to the way the data-
path is drawn; instructions and data move generally from left to right through the

4.6  Pipelined Datapath and Control

277

IF: Instruction fetch

ID: Instruction decode/
register file read

EX: Execute/
address calculation

MEM: Memory access

WB: Write back

4

Add

0

1

M
u
x

PC

Address

Instruction

Instruction
memory

ADD Sum

Shift
left 1

ALU

Zero

ALU
result

0

1

M
u
x

Read
data 1

Read
register 1

Read
register 2

Registers

Read
data 2

Write
register

Write
data

32

64

Imm
Gen

Address

Read
data

Data
memory

Write
data

1

0

M
u
x

FIGURE 4.31  The single-cycle datapath from Section 4.4 (similar to Figure 4.17). Each step of the instruction can be mapped
onto the datapath from left to right. The only exceptions are the update of the PC and the write-back step, shown in color, which sends either
the ALU result or the data from memory to the left to be written into the register file. (Normally we use color lines for control, but these are
data lines.)

five stages as they complete execution. Returning to our laundry analogy, clothes
get  cleaner,  drier,  and  more  organized  as  they  move  through  the  line,  and  they
never move backward.

There are, however, two exceptions to this left-to-right flow of instructions:

■	 The write-back stage, which places the result back into the register file in the

middle of the datapath

■	 The selection of the next value of the PC, choosing between the incremented

PC and the branch address from the MEM stage

Data flowing from right to left do not affect the current instruction; these reverse
data movements influence only later instructions in the pipeline. Note that the first

278

Chapter 4  The Processor

right-to-left flow of data can lead to data hazards and the second leads to control
hazards.

One way to show what happens in pipelined execution is to pretend that each
instruction has its own datapath, and then to place these datapaths on a timeline to
show their relationship. Figure 4.32 shows the execution of the instructions in Figure
4.25 by displaying their private datapaths on a common timeline. We use a stylized
version of the datapath in Figure 4.31 to show the relationships in Figure 4.32.

Figure  4.32  seems  to  suggest  that  three  instructions  need  three  datapaths.
Instead, we add registers to hold data so that portions of a single datapath can be
shared during instruction execution.

For  example,  as  Figure  4.32  shows,  the  instruction  memory  is  used  during
only one of the five stages of an instruction, allowing it to be shared by following
instructions  during  the  other  four  stages.  To  retain  the  value  of  an  individual
instruction for its other four stages, the value read from instruction memory must
be saved in a register. Similar arguments apply to every pipeline stage, so we must
place  registers  wherever  there  are  dividing  lines  between  stages  in  Figure  4.31.
Returning to our laundry analogy, we might have a basket between each pair of
stages to hold the clothes for the next step.

Time (in clock cycles)

CC 1

CC 2

CC 3

CC 4

CC 5

CC 6

CC 7

Program
execution
order
(in instructions)

ld x, 100(x4)

IM

Reg

ALU

DM

Reg

ld x2, 200(x4)

IM

Reg

ALU

DM

Reg

ld x3, 400(x4)

IM

Reg

ALU

DM

Reg

FIGURE 4.32
Instructions being executed using the single-cycle datapath in Figure 4.31,
assuming  pipelined  execution.  Similar  to  Figures  4.26  through  4.28,  this  figure  pretends  that  each
instruction has its own datapath, and shades each portion according to use. Unlike those figures, each stage
is labeled by the physical resource used in that stage, corresponding to the portions of the datapath in Figure
4.31. IM represents the instruction memory and the PC in the instruction fetch stage, Reg stands for the
register file and sign extender in the instruction decode/register file read stage (ID), and so on. To maintain
proper time order, this stylized datapath breaks the register file into two logical parts: registers read during
register fetch (ID) and registers written during write back (WB). This dual use is represented by drawing
the unshaded left half of the register file using dashed lines in the ID stage, when it is not being written, and
the unshaded right half in dashed lines in the WB stage, when it is not being read. As before, we assume the
register file is written in the first half of the clock cycle and the register file is read during the second half.

4.6  Pipelined Datapath and Control

279

Figure  4.33  shows  the  pipelined  datapath  with  the  pipeline  registers  high-
lighted. All instructions advance during each clock cycle from one pipeline register
to the next. The registers are named for the two stages separated by that register.
For example, the pipeline register between the IF and ID stages is called IF/ID.

Notice that there is no pipeline register at the end of the write-back stage. All
instructions must update some state in the processor—the register file, memory,
or the PC—so a separate pipeline register is redundant to the state that is updated.
For example, a load instruction will place its result in one of the 32 registers, and
any later instruction that needs that data will simply read the appropriate register.

Of course, every instruction updates the PC, whether by incrementing it or by
setting it to a branch destination address. The PC can be thought of as a pipeline
register: one that feeds the IF stage of the pipeline. Unlike the shaded pipeline
registers in Figure 4.33, however, the PC is part of the visible architectural state;
its contents must be saved when an exception occurs, while the contents of the
pipeline registers can be discarded. In the laundry analogy, you could think of
the PC as corresponding to the basket that holds the load of dirty clothes before
the wash step.

To show how the pipelining works, throughout this chapter we show sequences
of figures to demonstrate operation over time. These extra pages would seem to
require much more time for you to understand. Fear not; the sequences take much

Add

4

0
M
u
x
1

PC

Address

Instruction
memory

IF/ID

ID/EX

EX/MEM

MEM/WB

Add Sum

Shift
left 1

Zero
ALU ALU
result

0
M
u
x
1

n
o
i
t
c
u
r
t
s
n
I

Read
register 1

Read
register 2

Registers

Write
register

Write
data

Read
data 1

Read
data 2

32

64

Imm
Gen

Address

Read
data

Data
memory

Write
data

1
M
u
x
0

FIGURE 4.33  The pipelined version of the datapath in Figure 4.31. The pipeline registers, in color, separate each pipeline stage.
They are labeled by the stages that they separate; for example, the first is labeled IF/ID because it separates the instruction fetch and instruction
decode stages. The registers must be wide enough to store all the data corresponding to the lines that go through them. For example, the IF/ID
register must be 96 bits wide, because it must hold both the 32-bit instruction fetched from memory and the incremented 64-bit PC address.
We will expand these registers over the course of this chapter, but for now the other three pipeline registers contain 256, 193, and 128 bits,
respectively.

280

Chapter 4  The Processor

less time than it might appear, because you can compare them to see what changes
occur in each clock cycle. Section 4.7 describes what happens when there are data
hazards between pipelined instructions; ignore them for now.

Figures 4.34 through 4.37, our first sequence, show the active portions of the
datapath highlighted as a load instruction goes through the five stages of pipelined
execution. We show a load first because it is active in all five stages. As in Figures
4.26 through 4.28, we highlight the right half of registers or memory when they are
being read and highlight the left half when they are being written.

We show the instruction ld with the name of the pipe stage that is active in each

figure. The five stages are the following:

1.  Instruction fetch: The top portion of Figure 4.34 shows the instruction being
read from memory using the address in the PC and then being placed in the
IF/ID pipeline register. The PC address is incremented by 4 and then written
back into the PC to be ready for the next clock cycle. This PC is also saved
in  the  IF/ID  pipeline  register  in  case  it  is  needed  later  for  an  instruction,
such as beq. The computer cannot know which type of instruction is being
fetched, so it must prepare for any instruction, passing potentially needed
information down the pipeline.

2.  Instruction decode and register file read: The bottom portion of Figure 4.34
shows the instruction portion of the IF/ID pipeline register supplying the
immediate field, which is sign-extended to 64 bits, and the register numbers
to read the two registers. All three values are stored in the ID/EX pipeline
register, along with the PC address. We again transfer everything that might
be needed by any instruction during a later clock cycle.

3.  Execute or address calculation: Figure 4.35 shows that the load instruction
reads the contents of a register and the sign-extended immediate from the
ID/EX pipeline register and adds them using the ALU. That sum is placed in
the EX/MEM pipeline register.

4.  Memory access: The top portion of Figure 4.36 shows the load instruction
reading  the  data  memory  using  the  address  from  the  EX/MEM  pipeline
register and loading the data into the MEM/WB pipeline register.

5.  Write-back: The bottom portion of Figure 4.36 shows the final step: reading
the data from the MEM/WB pipeline register and writing it into the register
file in the middle of the figure.

This walk-through of the load instruction shows that any information needed
in a later pipe stage must be passed to that stage via a pipeline register. Walking
through a store instruction shows the similarity of instruction execution, as well
as passing the information for later stages. Here are the five pipe stages of the store
instruction:

4.6  Pipelined Datapath and Control

281

ld

Instruction fetch

Add

4

0
M
u
x

1

PC

Address

Instruction
memory

IF/ID

ID/EX

EX/MEM

MEM/WB

Add Sum

Shift
left 1

Zero
ALU ALU
result

0
M
u
x
1

Address

Read
data

Data
memory

Write
data

n
o
i
t
c
u
r
t
s
n
I

Read
register 1

Read
register 2

Registers

Write
register

Write
data

Read
data 1

Read
data 2

32

64

Imm
Gen

ld

Instruction decode

IF/ID

ID/EX

EX/MEM

MEM/WB

Add

4

0
M
u
x

1

PC

Address

Instruction
memory

Add Sum

Shift
left 1

Zero
ALU ALU
result

0
M
u
x
1

n
o
i
t
c
u
r
t
s
n
I

Read
register 1

Read
register 2

Registers

Write
register

Write
data

Read
data 1

Read
data 2

32

64

Imm
Gen

Address

Read
data

Data
memory

Write
data

1
M
u
x
0

1
M
u
x
0

FIGURE 4.34
IF and ID: First and second pipe stages of an instruction, with the active portions of the datapath in
Figure 4.33 highlighted. The highlighting convention is the same as that used in Figure 4.26. As in Section 4.2, there is no confusion when
reading and writing registers, because the contents change only on the clock edge. Although the load needs only the top register in stage 2, it
doesn’t hurt to do potentially extra work, so it sign-extends the constant and reads both registers into the ID/EX pipeline register. We don’t need
all three operands, but it simplifies control to keep all three.

282

Chapter 4  The Processor

ld

Execution

IF/ID

ID/EX

EX/MEM

MEM/WB

Add

4

0
M
u
x
1

PC

Address

Instruction
memory

n
o
i
t
c
u
r
t
s
n
I

AddSum

Shift
left 1

Zero
ALU ALU
result

0
M
u
x1

Address

Read
data

Data
memory

Write
data

1
M
u
x
0

Read
register 1

Read
register 2

Write
register

Registers

Read
data 1

Read
data 2

Write
data

32

64

Imm
Gen

FIGURE 4.35  EX: The third pipe stage of a load instruction, highlighting the portions of the datapath in Figure 4.33
used in this pipe stage. The register is added to the sign-extended immediate, and the sum is placed in the EX/MEM pipeline register.

1.  Instruction fetch: The instruction is read from memory using the address in
the PC and then is placed in the IF/ID pipeline register. This stage occurs
before the instruction is identified, so the top portion of Figure 4.34 works
for store as well as load.

2.  Instruction decode and register file read: The instruction in the IF/ID pipeline
register supplies the register numbers for reading two registers and extends
the sign of the immediate operand. These three 64-bit values are all stored
in the ID/EX pipeline register. The bottom portion of Figure 4.34 for load
instructions also shows the operations of the second stage for stores. These
first two stages are executed by all instructions, since it is too early to know
the type of the instruction. (While the store instruction uses the rs2 field to
read the second register in this pipe stage, that detail is not shown in this
pipeline diagram, so we can use the same figure for both.)

3.  Execute and address calculation: Figure 4.37 shows the third step; the effective

address is placed in the EX/MEM pipeline register.

4.  Memory access: The top portion of Figure 4.38 shows the data being written
to memory. Note that the register containing the data to be stored was read in
an earlier stage and stored in ID/EX. The only way to make the data available
during the MEM stage is to place the data into the EX/MEM pipeline register
in the EX stage, just as we stored the effective address into EX/MEM.

4.6  Pipelined Datapath and Control

283

ld

Memory

IF/ID

ID/EX

EX/MEM

MEM/WB

Add

4

0
M
u
x

1

PC

Address

Instruction
memory

Add Sum

Shift
left 1

Zero
ALU ALU
result

0
M
u
x
1

n
o
i
t
c
u
r
t
s
n
I

Read
register 1

Read
register 2

Registers

Write
register

Write
data

Read
data 1

Read
data 2

32

64

Imm
Gen

Address

Read
data

Data
memory

Write
data

0
M
u
x
1

ld

Write-back

Add

4

0
M
u
x

1

PC

Address

Instruction
memory

IF/ID

ID/EX

EX/MEM

MEM/WB

Add Sum

Shift
left 1

Zero
ALU ALU
result

0
M
u
x
1

n
o
i
t
c
u
r
t
s
n
I

Read
register 1

Read
register 2

Registers

Write
register

Write
data

Read
data 1

Read
data 2

32

64

Imm
Gen

Address

Read
data

Data
memory

Write
data

1
M
u
x
0

FIGURE 4.36  MEM and WB: The fourth and fifth pipe stages of a load instruction, highlighting the portions of the
datapath in Figure 4.33 used in this pipe stage. Data memory is read using the address in the EX/MEM pipeline registers, and the
data are placed in the MEM/WB pipeline register. Next, data are read from the MEM/WB pipeline register and written into the register file in
the middle of the datapath. Note: there is a bug in this design that is repaired in Figure 4.39.

284

Chapter 4  The Processor

sd

Execution

IF/ID

ID/EX

EX/MEM

MEM/WB

Add

4

0
M
u
x
1

PC

Address

Instruction
memory

AddSum

Shift
left 1

Zero
ALU ALU
result

0
M
u
x
1

n
o
i
t
c
u
r
t
s
n
I

Read
register 1

Read
register 2

Registers

Write
register

Write
data

Read
data 1

Read
data 2

32

64

Imm
Gen

Address

Read
data

Data
memory

Write
data

1
M
u
x
0

FIGURE 4.37  EX: The third pipe stage of a store instruction. Unlike the third stage of the load instruction in Figure 4.35, the
second register value is loaded into the EX/MEM pipeline register to be used in the next stage. Although it wouldn’t hurt to always write this
second register into the EX/MEM pipeline register, we write the second register only on a store instruction to make the pipeline easier to
understand.

5.  Write-back: The bottom portion of Figure 4.38 shows the final step of the
store. For this instruction, nothing happens in the write-back stage. Since
every  instruction  behind  the  store  is  already  in  progress,  we  have  no  way
to  accelerate  those  instructions.  Hence,  an  instruction  passes  through  a
stage  even  if  there  is  nothing  to  do,  because  later  instructions  are  already
progressing at the maximum rate.

The store instruction again illustrates that to pass something from an early pipe
stage to a later pipe stage, the information must be placed in a pipeline register;
otherwise, the information is lost when the next instruction enters that pipeline
stage. For the store instruction, we needed to pass one of the registers read in the
ID stage to the MEM stage, where it is stored in memory. The data were first placed
in the ID/EX pipeline register and then passed to the EX/MEM pipeline register.

Load  and  store  illustrate  a  second  key  point:  each  logical  component  of  the
datapath—such  as  instruction  memory,  register  read  ports,  ALU,  data  memory,
and register write port—can be used only within a single pipeline stage. Otherwise,
we would have a structural hazard (see page 267). Hence, these components, and
their control, can be associated with a single pipeline stage.

Now we can uncover a bug in the design of the load instruction. Did you see
it?  Which  register  is  changed  in  the  final  stage  of  the  load?  More  specifically,

4.6  Pipelined Datapath and Control

285

sd

Memory

IF/ID

ID/EX

EX/MEM

MEM/WB

Add

4

0
M
u
x

1

PC

Address

Instruction
memory

Add Sum

Shift
left 1

Zero
ALU ALU
result

0
M
u
x
1

n
o
i
t
c
u
r
t
s
n
I

Read
register 1

Read
register 2

Registers

Write
register

Write
data

Read
data 1

Read
data 2

32

64

Imm
Gen

Address

Read
data

Data
memory

Write
data

0
M
u
x
1

sd

Write-back

Add

4

0
M
u
x

1

PC

Address

Instruction
memory

IF/ID

ID/EX

EX/MEM

MEM/WB

Add Sum

Shift
left 1

Zero
ALU ALU
result

0
M
u
x
1

n
o
i
t
c
u
r
t
s
n
I

Read
register 1

Read
register 2

Registers

Write
register

Write
data

Read
data 1

Read
data 2

32

64

Imm
Gen

Address

Read
data

Data
memory

Write
data

1
M
u
x
0

FIGURE 4.38  MEM and WB: The fourth and fifth pipe stages of a store instruction. In the fourth stage, the data are written
into data memory for the store. Note that the data come from the EX/MEM pipeline register and that nothing is changed in the MEM/WB
pipeline register. Once the data are written in memory, there is nothing left for the store instruction to do, so nothing happens in stage 5.

286

Chapter 4  The Processor

which instruction supplies the write register number? The instruction in the IF/
ID pipeline register supplies the write register number, yet this instruction occurs
considerably after the load instruction!

Hence,  we  need  to  preserve  the  destination  register  number  in  the  load
instruction. Just as store passed the register value from the ID/EX to the EX/MEM
pipeline  registers  for  use  in  the  MEM  stage,  load  must  pass  the  register  number
from the ID/EX through EX/MEM to the MEM/WB pipeline register for use in the
WB stage. Another way to think about the passing of the register number is that to
share the pipelined datapath, we need to preserve the instruction read during the
IF stage, so each pipeline register contains a portion of the instruction needed for
that stage and later stages.

Figure 4.39 shows the correct version of the datapath, passing the write register
number first to the ID/EX register, then to the EX/MEM register, and finally to the
MEM/WB  register.  The  register  number  is  used  during  the  WB  stage  to  specify
the register to be written. Figure 4.40 is a single drawing of the corrected datapath,
highlighting the hardware used in all five stages of the load register instruction in
Figures 4.34 through 4.36. See Section 4.8 for an explanation of how to make the
branch instruction work as expected.

Graphically Representing Pipelines

Pipelining can be difficult to master, since many instructions are simultaneously
executing in a single datapath in every clock cycle. To aid understanding, there are

Add

4

0
M
u
x

1

PC

Address

Instruction
memory

IF/ID

ID/EX

EX/MEM

MEM/WB

Add Sum

Shift
left 1

Zero
ALU ALU
result

0
M
u
x
1

n
o
i
t
c
u
r
t
s
n
I

Read
register 1

Read
register 2

Registers

Write
register

Write
data

Read
data 1

Read
data 2

32

64

Imm
Gen

Address

Read
data

Data
memory

Write
data

1
M
u
x
0

FIGURE  4.39  The  corrected  pipelined  datapath  to  handle  the  load  instruction  properly.  The write register number now
comes from the MEM/WB pipeline register along with the data. The register number is passed from the ID pipe stage until it reaches the MEM/
WB pipeline register, adding five more bits to the last three pipeline registers. This new path is shown in color.

4.6  Pipelined Datapath and Control

287

two basic styles of pipeline figures: multiple-clock-cycle pipeline diagrams, such as
Figure 4.32 on page 278, and single-clock-cycle pipeline diagrams, such as Figures
4.34 through 4.38. The multiple-clock-cycle diagrams are simpler but do not contain
all the details. For example, consider the following five-instruction sequence:

ld      x10, 40(x1)
sub       x11, x2, x3
add       x12, x3, x4
ld      x13, 48(x1)
add       x14, x5, x6

Figure  4.41  shows  the  multiple-clock-cycle  pipeline  diagram  for  these
instructions. Time advances from left to right across the page in these diagrams,
and instructions advance from the top to the bottom of the page, similar to the
laundry pipeline in Figure 4.23. A representation of the pipeline stages is placed
in  each  portion  along  the  instruction  axis,  occupying  the  proper  clock  cycles.
These stylized datapaths represent the five stages of our pipeline graphically, but
a rectangle naming each pipe stage works just as well. Figure 4.42 shows the more
traditional version of the multiple-clock-cycle pipeline diagram. Note that Figure
4.41  shows  the  physical  resources  used  at  each  stage,  while  Figure  4.42  uses  the
name of each stage.

Single-clock-cycle  pipeline  diagrams  show  the  state  of  the  entire  datapath
during  a  single  clock  cycle,  and  usually  all  five  instructions  in  the  pipeline  are
identified by labels above their respective pipeline stages. We use this type of figure
to  show  the  details  of  what  is  happening  within  the  pipeline  during  each  clock

Add

4

0
M
u
x

1

PC

Address

Instruction
memory

IF/ID

ID/EX

EX/MEM

MEM/WB

Add Sum

Shift
left 1

Zero
ALU ALU
result

0
M
u
x
1

n
o
i
t
c
u
r
t
s
n
I

Read
register 1

Read
register 2

Registers

Write
register

Write
data

Read
data 1

Read
data 2

32

64

Imm
Gen

Address

Read
data

Data
memory

Write
data

1
M
u
x
0

FIGURE 4.40  The portion of the datapath in Figure 4.39 that is used in all five stages of a load instruction.

288

Chapter 4  The Processor

Time (in clock cycles)
CC 1

CC 2

CC 3

CC 4

CC 5

CC 6

CC 7

CC 8

CC 9

Program
execution
order
(in instructions)

ld x10, 40(x1)

IM

Reg

ALU

DM

Reg

sub x11, x2, x3

IM

Reg

ALU

DM

Reg

add x12, x3, x4

IM

Reg

ALU

DM

Reg

ld x13, 48(x1)

IM

Reg

ALU

DM

Reg

add x14, x5, x6

IM

Reg

ALU

DM

Reg

FIGURE 4.41  Multiple-clock-cycle pipeline diagram of five instructions. This style of pipeline representation shows the complete
execution of instructions in a single figure. Instructions are listed in instruction execution order from top to bottom, and clock cycles move
from left to right. Unlike Figure 4.26, here we show the pipeline registers between each stage. Figure 4.42 shows the traditional way to draw
this diagram.

cycle; typically, the drawings appear in groups to show pipeline operation over a
sequence of clock cycles. We use multiple-clock-cycle diagrams to give overviews
 Section 4.13 gives more illustrations of single-clock
of pipelining situations. (
diagrams if you would like to see more details about Figure 4.41.) A single-clock-
cycle diagram represents a vertical slice of one clock cycle through a set of multiple-
clock-cycle diagrams, showing the usage of the datapath by each of the instructions
in the pipeline at the designated clock cycle. For example, Figure 4.43 shows the
single-clock-cycle diagram corresponding to clock cycle 5 of Figures 4.41 and 4.42.
Obviously, the single-clock-cycle diagrams have more detail and take significantly
more  space  to  show  the  same  number  of  clock  cycles.  The  exercises  ask  you  to
create such diagrams for other code sequences.

Check
Yourself

A group of students were debating the efficiency of the five-stage pipeline when
one student pointed out that not all instructions are active in  every stage of  the
pipeline. After deciding to ignore the effects of hazards, they made the following
four statements. Which ones are correct?

4.6  Pipelined Datapath and Control

289

Time (in clock cycles)
CC 1

CC 2

CC 3

CC 4

CC 5

CC 6

CC 7

CC 8

CC 9

Program
execution
order
(in instructions)

ld x10, 40(x1)

sub x11, x2, x3

add x12, x3, x4

ld x13, 48(x1)

add x14, x5, x6

Instruction
fetch

Instruction
decode
Instruction
fetch

Execution

Instruction
decode
Instruction
fetch

Data
access

Execution

Instruction
decode
Instruction
fetch

Write-back

Data
access

Execution

Instruction
decode
Instruction
fetch

Write-back

Data
access

Execution

Instruction
decode

Write-back

Data
access

Execution

Write-back

Data
access

Write-back

FIGURE 4.42  Traditional multiple-clock-cycle pipeline diagram of five instructions in Figure 4.41.

add x14, x5, x6

Instruction fetch

ld x13, 48(x1)

Instruction decode

add x12, x3, x4

sub x11, x2, x3

ld x10, 40(x1)

Execution

Memory

Write-back

Add

4

0
M
u
x
1

PC

Address

Instruction
memory

IF/ID

ID/EX

EX/MEM

MEM/WB

Add Sum

Shift
left 1

Zero
ALU ALU
result

0
M
u
x
1

n
o
i
t
c
u
r
t
s
n
I

Read
data 1

Read
data 2

Read
register 1

Read
register 2

Registers

Write
register

Write
data

32

64

Imm
Gen

Address

Read
data

Data
memory

Write
data

1
M
u
x
0

FIGURE 4.43  The single-clock-cycle diagram corresponding to clock cycle 5 of the pipeline in Figures 4.41 and 4.42.
As you can see, a single-clock-cycle figure is a vertical slice through a multiple-clock-cycle diagram.

1.  Allowing branches and ALU instructions to take fewer stages than the five
required by the load instruction will increase pipeline performance under all
circumstances.

290

Chapter 4  The Processor

2.  Trying to allow some instructions to take fewer cycles does not help, since
the throughput is determined by the clock cycle; the number of pipe stages
per instruction affects latency, not throughput.

3.  You cannot make ALU instructions take fewer cycles because of the write-
back  of  the  result,  but  branches  can  take  fewer  cycles,  so  there  is  some
opportunity for improvement.

4.  Instead of trying to make instructions take fewer cycles, we should explore
making  the  pipeline  longer,  so  that  instructions  take  more  cycles,  but  the
cycles are shorter. This could improve performance.

In the 6600 Computer,
perhaps even more
than in any previous
computer, the control
system is the difference.
James Thornton, Design
of a Computer: The
Control Data 6600, 1970

Pipelined Control

Just as we added control to the single-cycle datapath in Section 4.4, we now add
control  to  the  pipelined  datapath.  We  start  with  a  simple  design  that  views  the
problem through rose-colored glasses.

The first step is to label the control lines on the existing datapath. Figure 4.44
shows those lines. We borrow as much as we can from the control for the simple

IF/ID

ID/EX

EX/MEM

MEM/WB

PCSrc

Add

4

0
M
u
x
1

PC

Address

Instruction
memory

n
o
i
t
c
u
r
t
s
n
I

RegWrite

Read
register 1

Read
register 2

Read
data 1

Registers

Write
register

Read
data 2

Write
data

Instruction
[31–0]

32

Instruction
[30, 14-12]

Instruction
[11-7]

64

Imm
Gen

AddSum

Shift
left 1

Branch

MemtoReg

1
M
u
x
0

MemWrite

Address

Read
data

Data
memory

Write
data

MemRead

Zero
Add ALU
result

ALUSrc

0
M
u
x
1

ALU
control

ALUOp

FIGURE 4.44  The pipelined datapath of Figure 4.39 with the control signals identified. This datapath borrows the control
logic for PC source, register destination number, and ALU control from Section 4.4. Note that we now need funct fields of the instruction in
the EX stage as input to ALU control, so these bits must also be included in the ID/EX pipeline register.

4.6  Pipelined Datapath and Control

291

datapath in Figure 4.17. In particular, we use the same ALU control logic, branch
logic, and control lines. These functions are defined in Figures 4.12, 4.16, and 4.18.
We reproduce the key information in Figures 4.45 through 4.47 on a single page to
make the following discussion easier to absorb.

As was the case for the single-cycle implementation, we assume that the PC is
written on each clock cycle, so there is no separate write signal for the PC. By the
same argument, there are no separate write signals for the pipeline registers (IF/
ID, ID/EX, EX/MEM, and MEM/WB), since the pipeline registers are also written
during each clock cycle.

To specify control for the pipeline, we need only set the control values during
each pipeline stage. Because each control line is associated with a component active
in  only  a  single  pipeline  stage,  we  can  divide  the  control  lines  into  five  groups
according to the pipeline stage.

1.  Instruction  fetch:  The  control  signals  to  read  instruction  memory  and  to
write the PC are always asserted, so there is nothing special to control in this
pipeline stage.

2.  Instruction decode/register file read: The two source registers are always in the
same location in the RISC-V instruction formats, so there is nothing special
to control in this pipeline stage.

3.  Execution/address calculation: The signals to be set are ALUOp and ALUSrc
(see Figures 4.45 and 4.46). The signals select the ALU operation and either
Read data 2 or a sign-extended immediate as inputs to the ALU.

4.  Memory access: The control lines set in this stage are Branch, MemRead,
and MemWrite. The branch if equal, load, and store instructions set these
signals,  respectively.  Recall  that  PCSrc  in  Figure  4.46  selects  the  next
sequential address unless control asserts Branch and the ALU result was 0.

5.  Write-back:  The  two  control  lines  are  MemtoReg,  which  decides  between
sending  the  ALU  result  or  the  memory  value  to  the  register  file,  and
RegWrite, which writes the chosen value.

Since pipelining the datapath leaves the meaning of the control lines unchanged,
we can use the same control values. Figure 4.47 has the same values as in Section
4.4, but now the seven control lines are grouped by pipeline stage.

292

Chapter 4  The Processor

Instruction ALUOp

operation

ld
sd
beq
R-type
R-type
R-type
R-type

00
00
01
10
10
10
10

load doubleword
store doubleword
branch if equal
add
sub
and
or

Funct7
ﬁ eld

XXXXXXX
XXXXXXX
XXXXXXX
0000000
0100000
0000000
0000000

Funct3
ﬁ eld

Desired
ALU action

ALU control
input

XXX
XXX
XXX
000
000
111
110

add
add
subtract
add
subtract
AND
OR

0010
0010
0110
0010
0110
0000
0001

FIGURE 4.45  A copy of Figure 4.12. This figure shows how the ALU control bits are set depending on
the ALUOp control bits and the different opcodes for the R-type instruction.

Signal name

Effect when deasserted

Effect when asserted

etirWgeR

.enoN

ALUSrc

The second ALU operand comes from the second

 le output (Read data 2).

PCSrc

daeRmeM

The PC is replaced by the output of the adder that
computes the value of PC + 4.
.enoN

etirWmeM

.enoN

MemtoReg

The value fed to the register Write data input
comes from the ALU.

eulavehthtiwnettirwsitupniretsigeretirWehtnoretsigerehT
on the Write data input.
The second ALU operand is the sign-extended, 12 bits of the
instruction.
The PC is replaced by the output of the adder that computes
the branch target.
eratupnisserddaehtybdetangisedstnetnocyromemataD
put on the Read data output.
eratupnisserddaehtybdetangisedstnetnocyromemataD
replaced by the value on the Write data input.
The value fed to the register Write data input comes from the
data memory.

FIGURE 4.46  A copy of Figure 4.16. The function of each of six control signals is defined. The ALU control lines (ALUOp) are defined
in the second column of Figure 4.45. When a 1-bit control to a two-way multiplexor is asserted, the multiplexor selects the input corresponding
to 1. Otherwise, if the control is deasserted, the multiplexor selects the 0 input. Note that PCSrc is controlled by an AND gate in Figure 4.44.
If the Branch signal and the ALU Zero signal are both set, then PCSrc is 1; otherwise, it is 0. Control sets the Branch signal only during a beq
instruction; otherwise, PCSrc is set to 0.

Execution/address
calculation stage
control lines

Instruction

Memory access stage
control lines

Write-back stage
control lines

ALUOp

ALUSrc

Branch

Mem-
Read

Mem-
Write

Reg-
Write

Memto-
Reg

R-format
ld
sd
beq

10
00
00
01

0
1
1
0

0
0
0
1

0
1
0
0

0
0
1
0

1
1
0
0

0
1
X
X

FIGURE 4.47  The values of the control lines are the same as in Figure 4.18, but they have
been shuffled into three groups corresponding to the last three pipeline stages.

4.6  Pipelined Datapath and Control

293

Instruction

Control

WB

M

EX

WB

M

WB

IF/ID

ID/EX

EX/MEM

MEM/WB

FIGURE  4.48  The  seven  control  lines  for  the  final  three  stages.  Note that two of the seven
control  lines  are  used  in  the  EX  phase,  with  the  remaining  five  control  lines  passed  on  to  the  EX/MEM
pipeline register extended to hold the control lines; three are used during the MEM stage, and the last two are
passed to MEM/WB for use in the WB stage.

Implementing control means setting the seven control lines to these values in

each stage for each instruction.

Since  the  rest  of  the  control  lines  starts  with  the  EX  stage,  we  can  create  the
control  information  during  instruction  decode  for  the  later  stages.  The  simplest
way  to  pass  these  control  signals  is  to  extend  the  pipeline  registers  to  include
control information. Figure 4.48 above shows that these control signals are then
used in the appropriate pipeline stage as the instruction moves down the pipeline,
just as the destination register number for loads moves down the pipeline in Figure
4.39. Figure 4.49 shows the full datapath with the extended pipeline registers and
 Section 4.13 gives more
with the control lines connected to the proper stage. (
examples  of  RISC-V  code  executing  on  pipelined  hardware  using  single-clock
diagrams, if you would like to see more details.)

294

Chapter 4  The Processor

PCSrc

IF/ID

Add

4

0

1

PC

Address

Instruction
memory

ID/EX

WB

M

EX

Control

EX/MEM

WB

M

MEM/WB

WB

e
t
i
r

W
g
e
R

n
o
i
t
c
u
r
t
s
n
I

Read
register 1

Read
register 2

Read
data 1

Registers

Read
data 2

Write
register

Write
data

Instruction
[31–0]

32

Instruction
[30, 14-12]

Instruction
[11-7]

64

Imm
Gen

Shift
left 1

AddSum

ALUSrc

Zero
ALU ALU
result

0

1

ALU
control

ALUOp

Branch

e
t
i
r

W
m
e
M

Address

Read
data

Data
memory

Write
data

MemRead

g
e
R
o
t
m
e
M

1

0

FIGURE 4.49  The pipelined datapath of Figure 4.44, with the control signals connected to the control portions of the
pipeline registers. The control values for the last three stages are created during the instruction decode stage and then placed in the ID/EX
pipeline register. The control lines for each pipe stage are used, and remaining control lines are then passed to the next pipeline stage.

What do you mean,
why’s it got to be built?
It’s a bypass. You’ve got
to build bypasses.
Douglas Adams, The
Hitchhiker’s Guide to the
Galaxy, 1979

  4.7  Data Hazards: Forwarding versus Stalling

The  examples  in  the  previous  section  show  the  power  of  pipelined  execution
and how the hardware performs the task. It’s now time to take off the rose-colored
glasses  and  look  at  what  happens  with  real  programs.  The  RISC-V  instructions
in  Figures  4.41  through  4.43  were  independent;  none  of  them  used  the  results
calculated by any of the others. Yet, in Section 4.5, we saw that data hazards are
obstacles to pipelined execution.

4.7  Data Hazards: Forwarding versus Stalling

295

Let’s look at a sequence with many dependences, shown in color:

sub   x2, x1, x3
and   x12, x2, x5
or    x13, x6, x2
add   x14, x2, x2
sd

// Register z2 written by sub
//  1st operand(x2) depends on sub
// 2nd operand(x2) depends on sub
// 1st(x2) & 2nd(x2) depend on sub

x15, 100(x2)  // Base (x2) depends on sub

The last four instructions are all dependent on the result in register x2 of the
first instruction. If register x2 had the value 10 before the subtract instruction and
−20  afterwards,  the  programmer  intends  that  −20  will  be  used  in  the  following
instructions that refer to register x2.

How would this sequence perform with our pipeline? Figure 4.50 illustrates the
execution of these instructions using a multiple-clock-cycle pipeline representation.
To demonstrate the execution of this instruction sequence in our current pipeline,
the top of Figure 4.50 shows the value of register  x2, which changes during the
middle of clock cycle 5, when the sub instruction writes its result.

The  last  potential  hazard  can  be  resolved  by  the  design  of  the  register  file
hardware:  What  happens  when  a  register  is  read  and  written  in  the  same  clock
cycle? We assume that the write is in the first half of the clock cycle and the read
is in the second half, so the read delivers what is written. As is the case for many
implementations of register files, we have no data hazard in this case.

Figure 4.50 shows that the values read for register x2 would not be the result of
the sub instruction unless the read occurred during clock cycle 5 or later. Thus, the
instructions that would get the correct value of −20 are add and sd; the and and
or instructions would get the incorrect value 10! Using this style of drawing, such
problems become apparent when a dependence line goes backward in time.

As mentioned in Section 4.5, the desired result is available at the end of the EX
stage of the sub instruction or clock cycle 3. When are the data actually needed by
the and and or instructions? The answer is at the beginning of the EX stage of the
and and or instructions, or clock cycles 4 and 5, respectively. Thus, we can execute
this segment without stalls if we simply forward the data as soon as it is available to
any units that need it before it is ready to read from the register file.

How does forwarding work? For simplicity in the rest of this section, we consider
only  the  challenge  of  forwarding  to  an  operation  in  the  EX  stage,  which  may
be  either  an  ALU  operation  or  an  effective  address  calculation.  This  means
that  when  an  instruction  tries  to  use  a  register  in  its  EX  stage  that  an  earlier
instruction intends to write in its WB stage, we actually need the values as inputs
to the ALU.

A  notation  that  names  the  fields  of  the  pipeline  registers  allows  for  a  more
precise notation of dependences. For example, “ID/EX.RegisterRs1” refers to the
number of one register whose value is found in the pipeline register ID/EX; that
is, the one from the first read port of the register file. The first part of the name,

296

Chapter 4  The Processor

Time (in clock cycles)

Value of
register x2:

CC 1

10

CC 2

10

CC 3

10

CC 4

10

CC 5

10/–20

CC 6

–20

CC 7

–20

CC 8

–20

CC 9

–20

Program
execution
order
(in instructions)

sub x2, x1, x3

IM

Reg

DM

Reg

and x12, x2, x5

IM

Reg

DM

Reg

or x13, x6, x2

IM

Reg

DM

Reg

add x14, x2, x2

IM

Reg

DM

Reg

sd x15, 100(x2)

IM

Reg

DM

Reg

FIGURE  4.50  Pipelined  dependences  in  a  five-instruction  sequence  using  simplified  datapaths  to  show  the
dependences. All the dependent actions are shown in color, and “CC 1” at the top of the figure means clock cycle 1. The first instruction
writes into x2, and all the following instructions read x2. This register is written in clock cycle 5, so the proper value is unavailable before clock
cycle 5. (A read of a register during a clock cycle returns the value written at the end of the first half of the cycle, when such a write occurs.) The
colored lines from the top datapath to the lower ones show the dependences. Those that must go backward in time are pipeline data hazards.

to the left of the period, is the name of the pipeline register; the second part is
the name of the field in that register. Using this notation, the two pairs of hazard
conditions are

1a. EX/MEM.RegisterRd = ID/EX.RegisterRs1

1b. EX/MEM.RegisterRd = ID/EX.RegisterRs2

2a. MEM/WB.RegisterRd = ID/EX.RegisterRs1

2b. MEM/WB.RegisterRd = ID/EX.RegisterRs2

The first hazard in the sequence on page 295 is on register x2, between the result
of sub x2, x1, x3 and the first read operand of and x12, x2, x5. This hazard can

4.7  Data Hazards: Forwarding versus Stalling

297

be detected when the and instruction is in the EX stage and the prior instruction is
in the MEM stage, so this is hazard 1a:

EX/MEM.RegisterRd = ID/EX.RegisterRs1 = x2

Dependence Detection

EXAMPLE

Classify the dependences in this sequence from page 295:

sub  x2, x1, x3
and  x12,  x2, x5
or  x13,  x6, x2
add  x14,  x2, x2
sd  x15,  100(x2)

// Register x2 set by sub
// 1st operand(z2) set by sub
// 2nd operand(x2) set by sub
// 1st(x2) & 2nd(x2) set by sub
// Index(x2) set by sub

As mentioned above, the sub–and is a type 1a hazard. The remaining hazards
are as follows:

ANSWER

■	 The sub–or is a type 2b hazard:

MEM/WB.RegisterRd = ID/EX.RegisterRs2 = x2

■	 The two dependences on sub–add are not hazards because the register

file supplies the proper data during the ID stage of add.

■	 There is no data hazard between sub and sd because sd reads x2 the

clock cycle after sub writes x2.

Because  some  instructions  do  not  write  registers,  this  policy  is  inaccurate;
sometimes  it  would  forward  when  it  shouldn’t.  One  solution  is  simply  to  check
to see if the RegWrite signal will be active: examining the WB control field of the
pipeline register during the EX and MEM stages determines whether RegWrite is
asserted. Recall that RISC-V requires that every use of x0 as an operand must yield
an operand value of 0. If an instruction in the pipeline has x0 as its destination (for
example, addi x0, x1, 2), we want to avoid forwarding its possibly nonzero result
value. Not forwarding results destined for x0 frees the assembly programmer and
the compiler of any requirement to avoid using x0 as a destination. The conditions
above thus work properly as long as we add EX/MEM.RegisterRd ≠ 0 to the first
hazard condition and MEM/WB.RegisterRd ≠ 0 to the second.

Now that we can detect hazards, half of the problem is resolved—but we must

still forward the proper data.

Figure 4.51 shows the dependences between the pipeline registers and the inputs
to the ALU for the same code sequence as in Figure 4.50. The change is that the

298

Chapter 4  The Processor

dependence begins from a pipeline register, rather than waiting for the WB stage
to write the register file. Thus, the required data exist in time for later instructions,
with the pipeline registers holding the data to be forwarded.

If we can take the inputs to the ALU from any pipeline register rather than just
ID/EX, then we can forward the correct data. By adding multiplexors to the input
of the ALU, and with the proper controls, we can run the pipeline at full speed in
the presence of these data hazards.

For now, we will assume the only instructions we need to forward are the four
R-format  instructions:  add,  sub,  and,  and  or.  Figure  4.52  shows  a  close-up  of
the  ALU  and  pipeline  register  before  and  after  adding  forwarding.  Figure  4.53

Time (in clock cycles)
CC 2

CC 1

CC 3

CC 4

CC 5

CC 6

CC 7

CC 8

CC 9

value of register x2:

10

10

10

10         10/–20        –20         –20          –20          –20

Program
execution
order
(in instructions)

sub x2, x1, x3

IM

Reg

DM

Reg

and x12, x2, x5

IM

Reg

DM

Reg

or x13, x6, x2

IM

Reg

DM

Reg

add x14, x2, x2

sd x15, 100(x2)

IM

Reg

DM

Reg

IM

Reg

DM

Reg

FIGURE 4.51  The dependences between the pipeline registers move forward in time, so it is possible to supply the
inputs to the ALU needed by the and instruction and or instruction by forwarding the results found in the pipeline
registers. The values in the pipeline registers show that the desired value is available before it is written into the register file. We assume that
the register file forwards values that are read and written during the same clock cycle, so the add does not stall, but the values come from the
register file instead of a pipeline register. Register file “forwarding”—that is, the read gets the value of the write in that clock cycle—is why clock
cycle 5 shows register x2 having the value 10 at the beginning and −20 at the end of the clock cycle.

4.7  Data Hazards: Forwarding versus Stalling

299

ID/EX

EX/MEM

MEM/WB

Registers

ALU

Data
memory

a. No forwarding

ID/EX

EX/MEM

MEM/WB

Registers

ForwardA

ALU

ForwardB

Rs1
Rs2
Rd

Data
memory

EX/MEM.RegisterRd

Forwarding
unit

MEM/WB.RegisterRd

b. With forwarding

FIGURE 4.52  On the top are the ALU and pipeline registers before adding forwarding. On
the bottom, the multiplexors have been expanded to add the forwarding paths, and we show the forwarding
unit. The new hardware is shown in color. This figure is a stylized drawing, however, leaving out details from
the full datapath such as the sign extension hardware.

300

Chapter 4  The Processor

lortnocxuM

ecruoS

noitanalpxE

ALU result.

 le.

ForwardB = 10
ForwardB = 01

EX/MEM
MEM/WB

The second ALU operand is forwarded from the prior ALU result.
The second ALU operand is forwarded from data memory or an
earlier ALU result.

FIGURE 4.53  The control values for the forwarding multiplexors in Figure 4.52. The signed
immediate that is another input to the ALU is described in the Elaboration at the end of this section.

shows the values of the control lines for the ALU multiplexors that select either the
register file values or one of the forwarded values.

This forwarding control will be in the EX stage, because the ALU forwarding
multiplexors  are  found  in  that  stage.  Thus,  we  must  pass  the  operand  register
numbers from the ID stage via the ID/EX pipeline register to determine whether to
forward values. Before forwarding, the ID/EX register had no need to include space
to hold the rs1 and rs2 fields. Hence, they were added to ID/EX.

Let’s now write both the conditions for detecting hazards, and the control signals

to resolve them:

1.  EX hazard:

if  (EX/MEM.RegWrite
and  (EX/MEM.RegisterRd ≠ 0)
and  (EX/MEM.RegisterRd = ID/EX.RegisterRs1)) ForwardA = 10

if  (EX/MEM.RegWrite
and  (EX/MEM.RegisterRd ≠ 0)
and  (EX/MEM.RegisterRd = ID/EX.RegisterRs2)) ForwardB = 10

This case forwards the result from the previous instruction to either input
of the ALU. If the previous instruction is going to write to the register file,
and  the  write  register  number  matches  the  read  register  number  of  ALU
inputs A or B, provided it is not register 0, then steer the multiplexor to pick
the value instead from the pipeline register EX/MEM.

2.  MEM hazard:

if  (MEM/WB.RegWrite
and (MEM/WB.RegisterRd ≠ 0)
and (MEM/WB.RegisterRd = ID/EX.RegisterRs1)) ForwardA = 01

4.7  Data Hazards: Forwarding versus Stalling

301

if  (MEM/WB.RegWrite
and (MEM/WB.RegisterRd ≠ 0)
and (MEM/WB.RegisterRd = ID/EX.RegisterRs2)) ForwardB = 01

As mentioned above, there is no hazard in the WB stage, because we assume that
the register file supplies the correct result if the instruction in the ID stage reads
the same register written by the instruction in the WB stage. Such a register file
performs another form of forwarding, but it occurs within the register file.

One complication is potential data hazards between the result of the instruction
in the WB stage, the result of the instruction in the MEM stage, and the source
operand of the instruction in the ALU stage. For example, when summing a vector
of numbers in a single register, a sequence of instructions will all read and write to
the same register:

add x1, x1, x2
add x1, x1, x3
add x1, x1, x4
. . .

In this case, the result should be forwarded from the MEM stage because the
result in the MEM stage is the more recent result. Thus, the control for the MEM
hazard would be (with the additions highlighted):

if  (MEM/WB.RegWrite
and  (MEM/WB.RegisterRd ≠ 0)
and  not(EX/MEM.RegWrite and (EX/MEM.RegisterRd ≠ 0)
and (EX/MEM.RegisterRd = ID/EX.RegisterRs1))

and  (MEM/WB.RegisterRd = ID/EX.RegisterRs1)) ForwardA = 01

if  (MEM/WB.RegWrite
and  (MEM/WB.RegisterRd ≠ 0)
and  not(EX/MEM.RegWrite and (EX/MEM.RegisterRd ≠ 0)
and (EX/MEM.RegisterRd = ID/EX.RegisterRs2))

and  (MEM/WB.RegisterRd = ID/EX.RegisterRs2)) ForwardB = 01

Figure 4.54 shows the hardware necessary to support forwarding for operations
that use results during the EX stage. Note that the EX/MEM.RegisterRd field is the
register destination for either an ALU instruction or a load.

If you would like to see more illustrated examples using single-cycle pipeline
 Section 4.13 has figures that show two pieces of RISC-V code with

drawings,
hazards that cause forwarding.

302

Chapter 4  The Processor

IF/ID

n
o
i
t
c
u
r
t
s
n
I

PC

Instruction
memory

Control

ID/EX

WB

M

EX

EX/MEM

WB

M

MEM/WB

WB

Registers

ALU

IF/ID.RegisterRs1
IF/ID.RegisterRs2
IF/ID.RegisterRd

Rs1
Rs2
Rd

Data
memory

EX/MEM.RegisterRd

Forwarding
unit

MEM/WB.RegisterRd

FIGURE 4.54  The datapath modified to resolve hazards via forwarding. Compared with the datapath in Figure 4.49, the additions
are the multiplexors to the inputs to the ALU. This figure is a more stylized drawing, however, leaving out details from the full datapath, such
as the branch hardware and the sign extension hardware.

Elaboration:  Forwarding  can  also  help  with  hazards  when  store  instructions  are
dependent on other instructions. Since they use just one data value during the MEM
stage,  forwarding  is  easy.  However,  consider  loads  immediately  followed  by  stores,
useful  when  performing  memory-to-memory  copies  in  the  RISC-V  architecture.  Since
copies are frequent, we need to add more forwarding hardware to make them run faster.
If we were to redraw Figure 4.51, replacing the sub and and instructions with ld and
sd, we would see that it is possible to avoid a stall, since the data exist in the MEM/WB
register of a load instruction in time for its use in the MEM stage of a store instruction.
We would need to add forwarding into the memory access stage for this option. We leave
this modification as an exercise to the reader.

In addition, the signed-immediate input to the ALU, needed by loads and stores, is
missing from the datapath in Figure 4.54. Since central control decides between register
and immediate, and since the forwarding unit chooses the pipeline register for a register
input to the ALU, the easiest solution is to add a 2:1 multiplexor that chooses between
the  ForwardB  multiplexor  output  and  the  signed  immediate.  Figure  4.55  shows  this
addition.

4.7  Data Hazards: Forwarding versus Stalling

303

ID/EX

EX/MEM

MEM/WB

Registers

ALUSrc

ALU

Data
memory

Forwarding
unit

FIGURE 4.55  A close-up of the datapath in Figure 4.52 shows a 2:1 multiplexor, which has been added to select the
signed immediate as an ALU input.

Data Hazards and Stalls

As we said in Section 4.5, one case where forwarding cannot save the day is when
an  instruction  tries  to  read  a  register  following  a  load  instruction  that  writes
the same register. Figure 4.56 illustrates the problem. The data is still being read
from memory in clock cycle 4 while the ALU is performing the operation for the
following  instruction.  Something  must  stall  the  pipeline  for  the  combination  of
load followed by an instruction that reads its result.

Hence,  in  addition  to  a  forwarding  unit,  we  need  a  hazard  detection  unit.  It
operates during the ID stage so that it can insert the stall between the load and
the instruction dependent on it. Checking for load instructions, the control for the
hazard detection unit is this single condition:

if  (ID/EX.MemRead and

((ID/EX.RegisterRd = IF/ID.RegisterRs1) or
(ID/EX.RegisterRd = IF/ID.RegisterRs2)))
stall the pipeline

If at first you don’t
succeed, redefine
success.
Anonymous

304

Chapter 4  The Processor

Time (in clock cycles)

CC 1

CC 2

CC 3

CC 4

CC 5

CC 6

CC 7

CC 8

CC 9

Program
execution
order
(in instructions)

ld x2, 20(x1)

IM

Reg

DM

Reg

and x4, x2, x5

IM

Reg

DM

Reg

or x8, x2, x6

IM

Reg

DM

Reg

add x9, x4, x2

IM

Reg

DM

Reg

sub x1, x6, x7

IM

Reg

DM

Reg

FIGURE 4.56  A pipelined sequence of instructions. Since the dependence between the load and the following instruction (and)
goes backward in time, this hazard cannot be solved by forwarding. Hence, this combination must result in a stall by the hazard detection unit.

Recall that we are using the RegisterRd to refer the register specified in instruction
bits  11:7  for  both  load  and  R-type  instructions.  The  first  line  tests  to  see  if  the
instruction is a load: the only instruction that reads data memory is a load. The next
two  lines  check  to  see  if  the  destination  register  field  of  the  load  in  the  EX  stage
matches either source register of the instruction in the ID stage. If the condition holds,
the instruction stalls one clock cycle. After this one-cycle stall, the forwarding logic
can handle the dependence and execution proceeds. (If there were no forwarding,
then the instructions in Figure 4.56 would need another stall cycle.)

If the instruction in the ID stage is stalled, then the instruction in the IF stage
must also be stalled; otherwise, we would lose the fetched instruction. Preventing
these two instructions from making progress is accomplished simply by preventing
the  PC  register  and  the  IF/ID  pipeline  register  from  changing.  Provided  these
registers  are  preserved,  the  instruction  in  the  IF  stage  will  continue  to  be  read
using the same PC, and the registers in the ID stage will continue to be read using

4.7  Data Hazards: Forwarding versus Stalling

305

the same instruction fields in the IF/ID pipeline register. Returning to our favorite
analogy,  it’s  as  if  you  restart  the  washer  with  the  same  clothes  and  let  the  dryer
continue tumbling empty. Of course, like the dryer, the back half of the pipeline
starting with the EX stage must be doing something; what it is doing is executing
instructions that have no effect: nops.

How can we insert these nops, which act like bubbles, into the pipeline? In Figure
4.47, we see that deasserting all seven control signals (setting them to 0) in the EX,
MEM, and WB stages will create a “do nothing” or nop instruction. By identifying
the hazard in the ID stage, we can insert a bubble into the pipeline by changing the
EX, MEM, and WB control fields of the ID/EX pipeline register to 0. These benign
control values are percolated forward at each clock cycle with the proper effect: no
registers or memories are written if the control values are all 0.

Figure 4.57 shows what really happens in the hardware: the pipeline execution
slot associated with the and instruction is turned into a nop and all instructions
beginning  with  the  and  instruction  are  delayed  one  cycle.  Like  an  air  bubble  in

nops  An instruction
that does no operation to
change state.

Time (in clock cycles)
CC 1

CC 2

CC 3

CC 4

CC 5

CC 6

CC 7

CC 8

CC 9

CC 10

Program
execution
order
(in instructions)

ld x2, 20(x1)

IM

Reg

DM

Reg

and becomes nop

IM

Reg

DM

Reg

bubble

and x4, x2, x5

IM

Reg

DM

Reg

or x8, x2, x6

IM

Reg

DM

Reg

add x9, x4, x2

IM

Reg

DM

Reg

FIGURE 4.57  The way stalls are really inserted into the pipeline. A bubble is inserted beginning in clock cycle 4, by changing
the and instruction to a nop. Note that the and instruction is really fetched and decoded in clock cycles 2 and 3, but its EX stage is delayed
until clock cycle 5 (versus the unstalled position in clock cycle 4). Likewise, the or instruction is fetched in clock cycle 3, but its ID stage is
delayed until clock cycle 5 (versus the unstalled clock cycle 4 position). After insertion of the bubble, all the dependences go forward in time
and no further hazards occur.

306

Chapter 4  The Processor

a  water  pipe,  a  stall  bubble  delays  everything  behind  it  and  proceeds  down  the
instruction pipe one stage each clock cycle until it exits at the end. In this example,
the hazard forces the and and or instructions to repeat in clock cycle 4 what they
did  in  clock  cycle  3:  and  reads  registers  and  decodes,  and  or  is  refetched  from
instruction memory. Such repeated work is what a stall looks like, but its effect is
to stretch the time of the and and or instructions and delay the fetch of the add
instruction.

Figure 4.58 highlights the pipeline connections for both the hazard detection
unit  and  the  forwarding  unit.  As  before,  the  forwarding  unit  controls  the  ALU
multiplexors to replace the value from a general-purpose register with the value
from the proper pipeline register. The hazard detection unit controls the writing
of the PC and IF/ID registers plus the multiplexor that chooses between the real
control values and all 0s. The hazard detection unit stalls and deasserts the control
fields if the load-use hazard test above is true. If you would like to see more details,
 Section 4.13 gives an example illustrated using single-clock pipeline diagrams

of RISC-V code with hazards that cause stalling.

Hazard
detection
unit

ID/EX.MemRead

Control

0

ID/EX
WB

M

EX

EX/MEM

WB

M

MEM/WB

WB

Registers

ForwardA

ALU

Data
memory

IF/ID.RegisterRs1
IF/ID.RegisterRs2

IF/ID.RegisterRd

ForwardB

Rd

Rs1
Rs2

Forwarding
unit

e
t
i
r

W
D
F

/

I

IF/ID

n
o
i
t
c
u
r
t
s
n
I

e
t
i
r

W
C
P

PC

Instruction
memory

FIGURE 4.58  Pipelined control overview, showing the two multiplexors for forwarding, the hazard detection unit, and
the forwarding unit. Although the ID and EX stages have been simplified—the sign-extended immediate and branch logic are missing—
this drawing gives the essence of the forwarding hardware requirements.

4.8  Control Hazards

307

Although the compiler generally relies upon the hardware to resolve hazards
and thereby ensure correct execution, the compiler must understand the
pipeline  to  achieve  the  best  performance.  Otherwise,  unexpected  stalls
will reduce the performance of the compiled code.

The BIG
Picture

There are a thousand
hacking at the
branches of evil to one
who is striking at the
root.
Henry David Thoreau,
Walden, 1854

Elaboration:  Regarding  the  remark  earlier  about  setting  control  lines  to  0  to  avoid
writing registers or memory: only the signals RegWrite and MemWrite need be 0, while
the other control signals can be don’t cares.

  4.8

Control Hazards

Thus far, we have limited our concern to hazards involving arithmetic operations
and data transfers. However, as we saw in Section 4.5, there are also pipeline hazards
involving conditional branches. Figure 4.59 shows a sequence of instructions and
indicates when the branch would occur in this pipeline. An instruction must be
fetched at every clock cycle to sustain the pipeline, yet in our design the decision
about whether to branch doesn’t occur until the MEM pipeline stage. As mentioned
in Section 4.5, this delay in determining the proper instruction to fetch is called
a  control  hazard  or  branch  hazard,  in  contrast  to  the  data  hazards  we  have  just
examined.

This  section  on  control  hazards  is  shorter  than  the  previous  sections  on  data
hazards. The reasons are that control hazards are relatively simple to understand,
they  occur  less  frequently  than  data  hazards,  and  there  is  nothing  as  effective
against  control  hazards  as  forwarding  is  against  data  hazards.  Hence,  we  use
simpler schemes. We look at two schemes for resolving control hazards and one
optimization to improve these schemes.

Assume Branch Not Taken

As  we  saw  in  Section  4.5,  stalling  until  the  branch  is  complete  is  too  slow.  One
improvement  over  branch  stalling  is  to  predict  that  the  conditional  branch  will
not be taken and thus continue execution down the sequential instruction stream.
If  the  conditional  branch  is  taken,  the  instructions  that  are  being  fetched  and
decoded must be discarded. Execution continues at the branch target. If conditional
branches are untaken half the time, and if it costs little to discard the instructions,
this optimization halves the cost of control hazards.

308

Chapter 4  The Processor

CC 1

CC 2

CC 3

CC 4

CC 5

CC 6

CC 7

CC 8

CC 9

Time (in clock cycles)

Program
execution
order
(in instructions)

40 beq x1, x0, 16

IM

Reg

DM

Reg

44 and x12, x2, x5

IM

Reg

DM

Reg

48 or x13, x6, x2

IM

Reg

DM

Reg

52 add x14, x2, x2

IM

Reg

DM

Reg

72 ld x4, 100(x7)

IM

Reg

DM

Reg

FIGURE  4.59  The  impact  of  the  pipeline  on  the  branch  instruction.  The  numbers  to  the  left  of  the  instruction  (40,  44,  …)
are the addresses of the instructions. Since the branch instruction decides whether to branch in the MEM stage—clock cycle 4 for the beq
instruction above—the three sequential instructions that follow the branch will be fetched and begin execution. Without intervention, those
three following instructions will begin execution before beq branches to ld at location 72. (Figure 4.29 assumed extra hardware to reduce the
control hazard to one clock cycle; this figure uses the nonoptimized datapath.)

flush  To discard
instructions in a pipeline,
usually due to an
unexpected event.

To  discard  instructions,  we  merely  change  the  original  control  values  to  0s,
much as we did to stall for a load-use data hazard. The difference is that we must
also change the three instructions in the IF, ID, and EX stages when the branch
reaches the MEM stage; for load-use stalls, we just change control to 0 in the ID
stage and let them percolate through the pipeline. Discarding instructions, then,
means we must be able to flush instructions in the IF, ID, and EX stages of the
pipeline.

Reducing the Delay of Branches

One way to improve conditional branch performance is to reduce the cost of the
taken branch. Thus far, we have assumed the next PC for a branch is selected in the

4.8  Control Hazards

309

MEM stage, but if we move the conditional branch execution earlier in the pipeline,
then fewer instructions need be flushed. Moving the branch decision up requires
two actions to occur earlier: computing the branch target address and evaluating
the branch decision. The easy part of this change is to move up the branch address
calculation.  We  already  have  the  PC  value  and  the  immediate  field  in  the  IF/ID
pipeline register, so we just move the branch adder from the EX stage to the ID
stage; of course, the address calculation for branch targets will be performed for all
instructions, but only used when needed.

The  harder  part  is  the  branch  decision  itself.  For  branch  if  equal,  we  would
compare two register reads during the ID stage to see if they are equal. Equality can
be tested by XORing individual bit positions of two registers and ORing the XORed
result. Moving the branch test to the ID stage implies additional forwarding and
hazard detection hardware, since a branch dependent on a result still in the pipeline
must still work properly with this optimization. For example, to implement branch
if equal (and its inverse), we will need to forward results to the equality test logic
that operates during ID. There are two complicating factors:

1.  During  ID,  we  must  decode  the  instruction,  decide  whether  a  bypass  to
the  equality  test  unit  is  needed,  and  complete  the  equality  test  so  that  if
the instruction is a branch, we can set the PC to the branch target address.
Forwarding  for  the  operand  of  branches  was  formerly  handled  by  the
ALU forwarding logic, but the introduction of the equality test unit in ID
will require new forwarding logic. Note that the bypassed source operands
of  a  branch  can  come  from  either  the  EX/MEM  or  MEM/WB  pipeline
registers.

2.  Because the value in a branch comparison is needed during ID but may be
produced later in time, it is possible that a data hazard can occur and a stall
will be needed. For example, if an ALU instruction immediately preceding
a branch produces the operand for the test in the conditional branch, a stall
will be required, since the EX stage for the ALU instruction will occur after
the ID cycle of the branch. By extension, if a load is immediately followed by
a conditional branch that depends on the load result, two stall cycles will be
needed, as the result from the load appears at the end of the MEM cycle but
is needed at the beginning of ID for the branch.

Despite  these  difficulties,  moving  the  conditional  branch  execution  to  the  ID
stage is an improvement, because it reduces the penalty of a branch to only one
instruction  if  the  branch  is  taken,  namely,  the  one  currently  being  fetched.  The
exercises explore the details of implementing the forwarding path and detecting
the hazard.

To  flush  instructions  in  the  IF  stage,  we  add  a  control  line,  called  IF.Flush,
that zeros the instruction field of the IF/ID pipeline register. Clearing the register
transforms the fetched instruction into a nop, an instruction that has no action and
changes no state.

310

Chapter 4  The Processor

Pipelined Branch

EXAMPLE

Show  what  happens  when  the  branch  is  taken  in  this  instruction  sequence,
assuming the pipeline is optimized for branches that are not taken, and that we
moved the branch execution to the ID stage:

36  sub  x10, x4, x8
40  beq  x1,  x3, 16  // PC-relative branch to 40+16*2=72
44  and  x12,  x2, x5
48  or
x13,  x2, x6
52  add  x14,  x4, x2
56  sub  x15,  x6, x7
. . .
72  ld

x4, 50(x7)

ANSWER

Figure 4.60 shows what happens when a conditional branch is taken. Unlike
Figure 4.59, there is only one pipeline bubble on a taken branch.

Dynamic Branch Prediction

Assuming a conditional branch is not taken is one simple form of branch prediction.
In  that  case,  we  predict  that  conditional  branches  are  untaken,  flushing  the
pipeline when we are wrong. For the simple five-stage pipeline, such an approach,
possibly  coupled  with  compiler-based  prediction,  is  probably  adequate.  With
deeper  pipelines,  the  branch  penalty  increases  when  measured  in  clock  cycles.
Similarly,  with  multiple  issue  (see  Section  4.10),  the  branch  penalty  increases  in
terms of instructions lost. This combination means that in an aggressive pipeline,
a simple static prediction scheme will probably waste too much performance. As
we mentioned in Section 4.5, with more hardware it is possible to try to predict
branch behavior during program execution.

One approach is to look up the address of the instruction to see if the conditional
branch was taken the last time this instruction was executed, and, if so, to begin
fetching new instructions from the same place as the last time. This technique is
called dynamic branch prediction.

One implementation of that approach is a branch prediction buffer or branch
history table. A branch prediction buffer is a small memory indexed by the lower
portion of the address of the branch instruction. The memory contains a bit that
says whether the branch was recently taken or not.

This  prediction  uses  the  simplest  sort  of  buffer;  we  don’t  know,  in  fact,  if  the
prediction  is  the  right  one—it  may  have  been  put  there  by  another  conditional
branch  that  has  the  same  low-order  address  bits.  However,  this  doesn’t  affect
correctness. Prediction is just a hint that we hope is correct, so fetching begins in
the predicted direction. If the hint turns out to be wrong, the incorrectly predicted

dynamic branch
prediction  Prediction of
branches at runtime using
runtime information.

branch prediction
buffer  Also called
branch history table.
A small memory that
is indexed by the lower
portion of the address of
the branch instruction
and that contains one
or more bits indicating
whether the branch was
recently taken or not.

4.8  Control Hazards

311

and x12, x2, x5

beq x1, x3, 16

sub x10, x4, x8

before<1>

before<2>

IF.Flush

Hazard
detection
unit

Control

32

48

IF/ID

40

+

72

0

Registers

=

Shift
left 1

16

Imm
Gen

44

+

4

PC

72

44

Instruction
memory

Clock 3

ID/EX

WB

M

EX

x1

x3

EX/MEM

WB

M

MEM/WB

WB

x4

ALU

x8

Data
memory

10

Forwarding
unit

ld x4, 50(x7)

Bubble (nop)

beq x1, x3, 16

sub x10, . . .

before<1>

IF.Flush

Control

IF/ID

76

72

+

4

PC

76

72

Instruction
memory

Hazard
detection
unit

+

Shift
left 1

Imm
Gen

Clock 4

ID/EX

WB

M

EX

0

EX/MEM

WB

M

MEM/WB

WB

Registers

=

ALU

Data
memory

10

Forwarding
unit

FIGURE 4.60  The ID stage of clock cycle 3 determines that a branch must be taken, so it selects 72 as the next PC
address and zeros the instruction fetched for the next clock cycle. Clock cycle 4 shows the instruction at location 72 being
fetched and the single bubble or nop instruction in the pipeline because of the taken branch.

312

Chapter 4  The Processor

instructions  are  deleted,  the  prediction  bit  is  inverted  and  stored  back,  and  the
proper sequence is fetched and executed.

This simple 1-bit prediction scheme has a performance shortcoming: even if a
conditional branch is almost always taken, we can predict incorrectly twice, rather
than once, when it is not taken. The following example shows this dilemma.

EXAMPLE

Loops and Prediction

ANSWER

branch target buffer
A structure that caches
the destination PC or
destination instruction
for a branch. It is usually
organized as a cache with
tags, making it more
costly than a simple
prediction buffer.

correlating predictor
A branch predictor that
combines local behavior
of a particular branch
and global information
about the behavior of
some recent number of
executed branches.

Consider a loop branch that branches nine times in a row, and then is not taken
once. What is the prediction accuracy for this branch, assuming the prediction
bit for this branch remains in the prediction buffer?

The steady-state prediction behavior will mispredict on the first and last loop
iterations.  Mispredicting  the  last  iteration  is  inevitable  since  the  prediction
bit  will  indicate  taken,  as  the  branch  has  been  taken  nine  times  in  a  row  at
that point. The misprediction on the first iteration happens because the bit is
flipped on prior execution of the last iteration of the loop, since the branch
was not taken on that exiting iteration. Thus, the prediction accuracy for this
branch that is taken 90% of the time is only 80% (two incorrect predictions and
eight correct ones).

Ideally, the accuracy of the predictor would match the taken branch frequency for
these highly regular branches. To remedy this weakness, 2-bit prediction schemes
are  often  used.  In  a  2-bit  scheme,  a  prediction  must  be  wrong  twice  before  it  is
changed. Figure 4.61 shows the finite-state machine for a 2-bit prediction scheme.
A branch prediction buffer can be implemented as a small, special buffer accessed
with the instruction address during the IF pipe stage. If the instruction is predicted
as taken, fetching begins from the target as soon as the PC is known; as mentioned
on page 308, it can be as early as the ID stage. Otherwise, sequential fetching and
executing continue. If the prediction turns out to be wrong, the prediction bits are
changed as shown in Figure 4.61.

Elaboration:  A  branch  predictor  tells  us  whether  a  conditional  branch  is  taken,
but  still  requires  the  calculation  of  the  branch  target.  In  the  five-stage  pipeline,  this
calculation takes one cycle, meaning that taken branches will have a one-cycle penalty.
One approach is to use a cache to hold the destination program counter or destination
instruction using a branch target buffer.

The 2-bit dynamic prediction scheme uses only information about a particular
branch.  Researchers  noticed  that  using  information  about  both  a  local  branch
and  the  global  behavior  of  recently  executed  branches  together  yields  greater
prediction accuracy for the same number of prediction bits. Such predictors are
called correlating predictors. A typical correlating predictor might have two 2-bit

4.8  Control Hazards

313

Taken

Predict taken

Predict not taken

Not taken

Not taken

Taken

Not taken

Taken

Predict taken

Not taken

Taken

Predict not taken

FIGURE 4.61  The states in a 2-bit prediction scheme. By using 2 bits rather than 1, a branch that
strongly favors taken or not taken—as many branches do—will be mispredicted only once. The 2 bits are used
to encode the four states in the system. The 2-bit scheme is a general instance of a counter-based predictor,
which is incremented when the prediction is accurate and decremented otherwise, and uses the mid-point of
its range as the division between taken and not taken.

predictors  for  each  branch,  with  the  choice  between  predictors  made  based  on
whether the last executed branch was taken or not taken. Thus, the global branch
behavior  can  be  thought  of  as  adding  additional  index  bits  for  the  prediction
lookup.

Another approach to branch prediction is the use of tournament predictors. A
tournament branch predictor uses multiple predictors, tracking, for each branch,
which  predictor  yields  the  best  results.  A  typical  tournament  predictor  might
contain two predictions for each branch index: one based on local information and
one  based  on  global  branch  behavior.  A  selector  would  choose  which  predictor
to use for any given prediction. The selector can operate similarly to a 1- or 2-bit
predictor, favoring whichever of the two predictors has been more accurate. Some
recent microprocessors use such ensemble predictors.

Elaboration:  One way to reduce the number of conditional branches is to add conditional
move instructions. Instead of changing the PC with a conditional branch, the instruction
conditionally  changes  the  destination  register  of  the  move.  For  example,  the  ARMv8
instruction set architecture has a conditional select instruction called CSEL. It specifies a
destination register, two source registers, and a condition. The destination register gets a
value of the first operand if the condition is true and the second operand otherwise. Thus,
CSEL X8, X11, X4, NE copies the contents of register 11 into register 8 if the condition
codes say the result of the operation was not equal zero or a copy of register 4 into register
11  if  it  was  zero.  Hence,  programs  using  the  ARMv8  instruction  set  could  have  fewer
conditional branches than programs written in RISC-V.

tournament branch
predictor  A branch
predictor with multiple
predictions for each
branch and a selection
mechanism that chooses
which predictor to enable
for a given branch.

314

Chapter 4  The Processor

Pipeline Summary

We started in the laundry room, showing principles of pipelining in an everyday
setting.  Using  that  analogy  as  a  guide,  we  explained  instruction  pipelining
step-by-step,  starting  with  the  single-cycle  datapath  and  then  adding  pipeline
registers, forwarding paths, data hazard detection, branch prediction, and flushing
instructions on mispredicted branches or load-use data hazards. Figure 4.62 shows
the final evolved datapath and control. We now are ready for yet another control
hazard: the sticky issue of exceptions.

Check
Yourself

Consider three branch prediction schemes: predict not taken, predict taken, and
dynamic  prediction.  Assume  that  they  all  have  zero  penalty  when  they  predict
correctly  and  two  cycles  when  they  are  wrong.  Assume  that  the  average  predict
accuracy of the dynamic predictor is 90%. Which predictor is the best choice for
the following branches?

IF.Flush

IF/ID

+

4

PC

Instruction
memory

ID/EX

WB

M

EX

0

+

Registers

=

Hazard
detection
unit

Control

Shift
left 1

Imm
Gen

MEM/WB

WB

M

EX/MEM

WB

ALU

Data
memory

Fowarding
unit

FIGURE 4.62  The final datapath and control for this chapter. Note that this is a stylized figure rather than a detailed datapath, so
it’s missing the ALUsrc Mux from Figure 4.55 and the multiplexor controls from Figure 4.49.

4.9  Exceptions

315

1.  A conditional branch that is taken with 5% frequency

2.  A conditional branch that is taken with 95% frequency

3.  A conditional branch that is taken with 70% frequency

  4.9

Exceptions

Control is the most challenging aspect of processor design: it is both the hardest
part to get right and the toughest part to make fast. One of the demanding tasks of
control is implementing exceptions and interrupts—events other than branches
that change the normal flow of instruction execution. They were initially created to
handle unexpected events from within the processor, like an undefined instruction.
The same basic mechanism was extended for I/O devices to communicate with the
processor, as we will see in Chapter 5.

Many  architectures  and  authors  do  not  distinguish  between  interrupts  and
exceptions, often using either name to refer to both types of events. For example,
the Intel x86 uses interrupt. We use the term exception to refer to any unexpected
change  in  control  flow  without  distinguishing  whether  the  cause  is  internal  or
external; we use the term interrupt only when the event is externally caused. Here
are examples showing whether the situation is internally generated by the processor
or externally generated and the name that RISC-V uses:

Type of event

From where?

RISC-V terminology

System reset
I/O device request
Invoke the operating system from user program
Using an undefined instruction
Hardware malfunctions

External
External
Internal
Internal
Either

Exception
Interrupt
Exception
Exception
Either

Many  of  the  requirements  to  support  exceptions  come  from  the  specific
situation  that  causes  an  exception  to  occur.  Accordingly,  we  will  return  to  this
topic in Chapter 5, when we will better understand the motivation for additional
capabilities in the exception mechanism. In this section, we deal with the control
implementation for detecting types of exceptions that arise from the portions of
the instruction set and implementation that we have already discussed.

Detecting  exceptional  conditions  and  taking  the  appropriate  action  is  often
on the critical timing path of a processor, which determines the clock cycle time
and  thus  performance.  Without  proper  attention  to  exceptions  during  design  of
the  control  unit,  attempts  to  add  exceptions  to  an  intricate  implementation  can
significantly  reduce  performance,  as  well  as  complicate  the  task  of  getting  the
design correct.

To make a computer
with automatic
program-interruption
facilities behave
[sequentially] was
not an easy matter,
because the number of
instructions in various
stages of processing
when an interrupt
signal occurs may be
large.
Fred Brooks, Jr.,
Planning a Computer
System: Project Stretch,
1962

exception  Also
called interrupt. An
unscheduled event
that disrupts program
execution; used to detect
undefined instructions.

interrupt  An exception
that comes from outside
of the processor. (Some
architectures use the
term interrupt for all
exceptions.)

316

Chapter 4  The Processor

How Exceptions are Handled in the RISC-V Architecture

The  only  types  of  exceptions  that  our  current  implementation  can  generate  are
execution  of  an  undefined  instruction  or  a  hardware  malfunction.  We’ll  assume
a  hardware  malfunction  occurs  during  the  instruction  add  x11,  x12,  x11  as
the example exception in the next few pages. The basic action that the processor
must perform when an exception occurs is to save the address of the unfortunate
instruction  in  the  supervisor  exception  cause  register  (SEPC)  and  then  transfer
control to the operating system at some specified address.

The operating system can then take the appropriate action, which may involve
providing  some  service  to  the  user  program,  taking  some  predefined  action  in
response to a malfunction, or stopping the execution of the program and reporting
an error. After performing whatever action is required because of the exception,
the  operating  system  can  terminate  the  program  or  may  continue  its  execution,
using  the  SEPC  to  determine  where  to  restart  the  execution  of  the  program.  In
Chapter 5, we will look more closely at the issue of restarting the execution.

For the operating system to handle the exception, it must know the reason for
the  exception,  in  addition  to  the  instruction  that  caused  it.  There  are  two  main
methods used to communicate the reason for an exception. The method used in
the  RISC-V  architecture  is  to  include  a  register  (called  the  Supervisor  Exception
Cause Register or SCAUSE), which holds a field that indicates the reason for the
exception.

A  second  method  is  to  use  vectored  interrupts.  In  a  vectored  interrupt,  the
address to which control is transferred is determined by the cause of the exception,
possibly  added  to  a  base  register  that  points  to  memory  range  for  vectored
interrupts. For example, we might define the following exception vector addresses
to accommodate these exception types:

Exception type

Undefined instruction
System Error (hardware malfunction)

Exception vector address to be added
to a Vector Table Base Register

00 0100 0000two
01 1000 0000two

The operating system knows the reason for the exception by the address at which it
is initiated. When the exception is not vectored, as in RISC-V, a single entry point for all
exceptions can be used, and the operating system decodes the status register to find the
cause. For architectures with vectored exceptions, the addresses might be separated by,
say, 32 bytes or eight instructions, and the operating system must record the reason for
the exception and may perform some limited processing in this sequence.

We can perform the processing required for exceptions by adding a few extra
registers and control signals to our basic implementation and by slightly extending
control. Let’s assume that we are implementing the exception system with the single
interrupt  entry  point  being  the  address  0000  0000  1C09  0000hex.  (Implementing

vectored interrupt  An
interrupt for which
the address to which
control is transferred is
determined by the cause
of the exception.

4.9  Exceptions

317

vectored  exceptions  is  no  more  difficult.)  We  will  need  to  add  two  additional
registers to our current RISC-V implementation:

■	 SEPC: A 64-bit register used to hold the address of the affected instruction.

(Such a register is needed even when exceptions are vectored.)

■	 SCAUSE: A register used to record the cause of the exception. In the RISC-V
architecture, this register is 64 bits, although most bits are currently unused.
Assume  there  is  a  field  that  encodes  the  two  possible  exception  sources
mentioned  above,  with  2  representing  an  undefined  instruction  and  12
representing hardware malfunction.

Exceptions in a Pipelined Implementation

A pipelined implementation treats exceptions as another form of control hazard.
For example, suppose there is a hardware malfunction in an add instruction. Just as
we did for the taken branch in the previous section, we must flush the instructions
that follow the add instruction from the pipeline and begin fetching instructions
from the new address. We will use the same mechanism we used for taken branches,
but this time the exception causes the deasserting of control lines.

When we dealt with branch misprediction, we saw how to flush the instruction
in the IF stage by turning it into a nop. To flush instructions in the ID stage, we
use the multiplexor already in the ID stage that zeros control signals for stalls. A
new control signal, called ID.Flush, is ORed with the stall signal from the hazard
detection unit to flush during ID. To flush the instruction in the EX phase, we use
a new signal called EX.Flush to cause new multiplexors to zero the control lines.
To start fetching instructions from location 0000 0000 1C09 0000hex, which we are
using as the RISC-V exception address, we simply add an additional input to the
PC multiplexor that sends 0000 0000 1C09 0000hex to the PC. Figure 4.63 shows
these changes.

This example points out a problem with exceptions: if we do not stop execution
in the middle of the instruction, the programmer will not be able to see the original
value of register x1 because it will be clobbered as the destination register of the
add instruction. If we assume the exception is detected during the EX stage, we
can use the EX.Flush signal to prevent the instruction in the EX stage from writing
its result in the WB stage. Many exceptions require that we eventually complete
the  instruction  that  caused  the  exception  as  if  it  executed  normally.  The  easiest
way to do this is to flush the instruction and restart it from the beginning after the
exception is handled.

The final step is to save the address of the offending instruction in the supervisor
exception  program  counter  (SEPC).  Figure  4.63  shows  a  stylized  version  of  the
datapath, including the branch hardware and necessary accommodations to handle
exceptions.

318

Chapter 4  The Processor

IF.Flush

EX.Flush

ID.Flush

Hazard
detection
unit

Control

IF/ID

+

0

ID/EX

WB

M

EX

M
u
x

0

SCAUSE

SEPC

0

EX/MEM

WB

M

MEM/WB

WB

+

4

1C090000

PC

Instruction
memory

Registers

=

Shift
left 1

Imm
Gen

ALU

Data
memory

Forwarding
unit

FIGURE 4.63  The datapath with controls to handle exceptions. The key additions include a new input with the value 0000 0000
1C09 0000hex in the multiplexor that supplies the new PC value; an SCAUSE register to record the cause of the exception; and an SEPC register
to save the address of the instruction that caused the exception. The 0000 0000 1C09 0000hex input to the multiplexor is the initial address to
begin fetching instructions in the event of an exception.

EXAMPLE

Exception in a Pipelined Computer

Given this instruction sequence,

40hex  sub
44hex  and
48hex  or
4Chex  add
50hex  sub
54hex  ld
. . .

x11, x2, x4
x12, x2, x5
x13, x2, x6
x1,  x2, x1
x15, x6, x7
x16, 100(x7)

assume the instructions to be invoked on an exception begin like this:

1C090000hex  sd
1C090004hex  sd
. . .

  x26, 1000(x10)
  x27, 1008(x10)

4.9  Exceptions

319

ANSWER

Show  what  happens  in  the  pipeline  if  a  hardware  malfunction  exception

occurs in the add instruction.

Figure 4.64 shows the events, starting with the add instruction in the EX stage.
Assume  the  hardware  malfunction  is  detected  during  that  phase,  and  0000
0000 1C09 0000hex is forced into the PC. Clock cycle 7 shows that the add and
following instructions are flushed, and the first instruction of the exception-
handling code is fetched. Note that the address of the add instruction is saved:
4Chex.

We  mentioned  several  examples  of  exceptions  on  page  315,  and  we  will  see
others in Chapter 5. With five instructions active in any clock cycle, the challenge
is to associate an exception with the appropriate instruction. Moreover, multiple
exceptions  can  occur  simultaneously  in  a  single  clock  cycle.  The  solution  is  to
prioritize  the  exceptions  so  that  it  is  easy  to  determine  which  is  serviced  first.
In  RISC-V  implementations,  the  hardware  sorts  exceptions  so  that  the  earliest
instruction is interrupted.

I/O device requests and hardware malfunctions are not associated with a specific
instruction, so the implementation has some flexibility as to when to interrupt the
pipeline. Hence, the mechanism used for other exceptions works just fine.

The SEPC register captures the address of the interrupted instructions, and the
SCAUSE  register  records  the  highest  priority  exception  in  a  clock  cycle  if  more
than one exception occurs.

Hardware/
Software
Interface

The hardware and the operating system must work in conjunction so that exceptions
behave as you would expect. The hardware contract is normally to stop the offending
instruction  in  midstream,  let  all  prior  instructions  complete,  flush  all  following
instructions, set a register to show the cause of the exception, save the address of
the offending instruction, and then branch to a prearranged address. The operating
system contract is to look at the cause of the exception and act appropriately. For
an undefined instruction or hardware failure, the operating system normally kills
the program and returns an indicator of the reason. For an I/O device request or an
operating system service call, the operating system saves the state of the program,
performs the desired task, and, at some point in the future, restores the program
to continue execution. In the case of I/O device requests, we may often choose to
run another task before resuming the task that requested the I/O, since that task
may often not be able to proceed until the I/O is complete. Exceptions are why the
ability to save and restore the state of any task is critical. One of the most important
and frequent uses of exceptions is handling page faults; Chapter 5 describes these
exceptions and their handling in more detail.

320

Chapter 4  The Processor

ld x16, 100(x7)

sub x15, x6, x7

add x1, x2, x1

or x13, . . .

and x12, . . .

EX.Flush

IF.Flush

ID.Flush

Hazard
detection
unit

ID/EX
0

WB

10

IF/ID
50

58

54

+

4

1C090000

M
u
x

PC

1C09000

54

Instruction
memory

Control

+

0

0

0

000

M

4C

EX

Shift
left 1

Registers

=

zzz

x6

x7

Sign-
extend

0

SCAUSE

SEPC

0

EX/MEM
10
WB

M

MEM/WB

1

WB

x2

x1

Data
memory

13

12

Clock 6

15

x1

Forwarding
unit

sd x26, 1000(x0)

bubble (nop)

IF.Flush

ID.Flush

bubble

EX.Flush

bubble

or x13, . . .

Hazard
detection
unit

Control

1C090000

+

4

IF/ID

54

+

0

Shift
left 1

ID/EX
0

WB

0

0

M

EX

0

0

000

SCAUSE

SEPC

0

00

EX/MEM

00

WB

M

MEM/WB

WB

1C090000

PC

Instruction
memory

1C090004

Imm
Gen

Registers

=

13

ALU

Data
memory

13

Clock 7

Forwarding
unit

FIGURE 4.64  The result of an exception due to hardware malfunction in the add instruction. The exception is detected
during the EX stage of clock 6, saving the address of the add instruction in the SEPC register (4Chex). It causes all the Flush signals to be
set near the end of this clock cycle, deasserting control values (setting them to 0) for the add. Clock cycle 7 shows the instructions converted
to bubbles in the pipeline plus the fetching of the first instruction of the exception routine—sd x26, 1000(x0)—from instruction location
0000 0000 1C09 0000hex. Note that the and and or instructions, which are prior to the add, still complete.

4.10  Parallelism via Instructions

321

Elaboration:  The difficulty of always associating the proper exception with the correct
instruction  in  pipelined  computers  has  led  some  computer  designers  to  relax  this
requirement in noncritical cases. Such processors are said to have imprecise interrupts
or imprecise exceptions. In the example above, PC would normally have 58hex at the start
of the clock cycle after the exception is detected, even though the offending instruction
is at address 4Chex. A processor with imprecise exceptions might put 58hex into SEPC and
leave it up to the operating system to determine which instruction caused the problem.
RISC-V and the vast majority of computers today support precise interrupts or precise
exceptions. One reason is designers of a deeper pipeline processor might be tempted
to record a different value in SEPC, which would create headaches for the OS. To prevent
them,  the  deeper  pipeline  would  likely  be  required  to  record  the  same  PC  that  would
have been recorded in the five-stage pipeline. It is simpler for everyone to just record
the PC of the faulting instruction instead. (Another reason is to support virtual memory,
which we shall see in Chapter 5.)

Elaboration:  We  show
the  exception  entry  address
0000 0000 1C09 0000hex, which is chosen somewhat arbitrarily. Many RISC-V computers
store  the  exception  entry  address  in  a  special  register  named  Supervisor Trap Vector
(STVEC), which the OS can load with a value of its choosing.

that  RISC-V  uses

imprecise
interrupt  Also called
imprecise exception.
Interrupts or exceptions
in pipelined computers
that are not associated
with the exact instruction
that was the cause of the
interrupt or exception.

precise interrupt  Also
called precise exception.
An interrupt or exception
that is always associated
with the correct
instruction in pipelined
computers.

Which exception should be recognized first in this sequence?

1.  xxx x11, x12, x11

  // undefined instruction

2.  sub x11, x12, x11    // hardware error

Check
Yourself

 4.10  Parallelism via Instructions

Be forewarned: this section is a brief overview of fascinating but complex topics.
If you want to learn more details, you should consult our more advanced book,
Computer Architecture: A Quantitative Approach, fifth edition, where the material
covered in these 13 pages is expanded to almost 200 pages (including appendices)!
Pipelining  exploits  the  potential  parallelism  among  instructions.  This
parallelism is called, naturally enough, instruction-level parallelism (ILP). There
are  two  primary  methods  for  increasing  the  potential  amount  of  instruction-
level parallelism. The first is increasing the depth of the pipeline to overlap more
instructions. Using our laundry analogy and assuming that the washer cycle was
longer than the others were, we could divide our washer into three machines that
perform  the  wash,  rinse,  and  spin  steps  of  a  traditional  washer.  We  would  then

322

Chapter 4  The Processor

instruction-level
parallelism  The
parallelism among
instructions.

multiple issue  A
scheme whereby multiple
instructions are launched
in one clock cycle.

static multiple issue  An
approach to implementing
a multiple-issue processor
where many decisions
are made by the compiler
before execution.

dynamic multiple
issue  An approach to
implementing a multiple-
issue processor where
many decisions are made
during execution by the
processor.

issue slots  The positions
from which instructions
could issue in a given
clock cycle; by analogy,
these correspond to
positions at the starting
blocks for a sprint.

move from a four-stage to a six-stage pipeline. To get the full speed-up, we need
to rebalance the remaining steps so they are the same length, in processors or in
laundry. The amount of parallelism being exploited is higher, since there are more
operations  being  overlapped.  Performance  is  potentially  greater  since  the  clock
cycle can be shorter.

Another approach is to replicate the internal components of the computer so
that it can launch multiple instructions in every pipeline stage. The general name
for this technique is multiple issue. A multiple-issue laundry would replace our
household washer and dryer with, say, three washers and three dryers. You would
also  have  to  recruit  more  assistants  to  fold  and  put  away  three  times  as  much
laundry in the same amount of time. The downside is the extra work to keep all the
machines busy and transferring the loads to the next pipeline stage.

Launching multiple instructions per stage allows the instruction execution rate to
exceed the clock rate or, stated alternatively, the CPI to be less than 1. As mentioned
in Chapter 1, it is sometimes useful to flip the metric and use IPC, or instructions per
clock cycle. Hence, a 3-GHz four-way multiple-issue microprocessor can execute a
peak rate of 12 billion instructions per second and have a best-case CPI of 0.33,
or an IPC of 3. Assuming a five-stage pipeline, such a processor would have up to
20 instructions in execution at any given time. Today’s high-end microprocessors
attempt to issue from three to six instructions in every clock cycle. Even moderate
designs will aim at a peak IPC of 2. There are typically, however, many constraints
on what types of instructions may be executed simultaneously, and what happens
when dependences arise.

There  are  two  main  ways  to  implement  a  multiple-issue  processor,  with  the
major difference being the division of work between the compiler and the hardware.
Because the division of work dictates whether decisions are being made statically
(that is, at compile time) or dynamically (that is, during execution), the approaches
are sometimes called static multiple issue and dynamic multiple issue. As we will
see, both approaches have other, more commonly used names, which may be less
precise or more restrictive.

Two primary and distinct responsibilities must be dealt with in a multiple-issue

pipeline:

1.  Packaging instructions into issue slots: how does the processor determine
how  many  instructions  and  which  instructions  can  be  issued  in  a  given
clock cycle? In most static issue processors, this process is at least partially
handled by the compiler; in dynamic issue designs, it is normally dealt with
at runtime by the processor, although the compiler will often have already
tried to help improve the issue rate by placing the instructions in a beneficial
order.

2.  Dealing with data and control hazards: in static issue processors, the compiler
handles some or all the consequences of data and control hazards statically.
In contrast, most dynamic issue processors attempt to alleviate at least some
classes of hazards using hardware techniques operating at execution time.

4.10  Parallelism via Instructions

323

speculation  An
approach whereby the
compiler or processor
guesses the outcome of an
instruction to remove it as
a dependence in executing
other instructions.

Although  we  describe  these  as  distinct  approaches,  in  reality,  one  approach
often  borrows  techniques  from  the  other,  and  neither  approach  can  claim  to  be
perfectly pure.

The Concept of Speculation

One  of  the  most  important  methods  for  finding  and  exploiting  more  ILP  is
speculation.  Based  on  the  great  idea  of  prediction,  speculation  is  an  approach
that  allows  the  compiler  or  the  processor  to  “guess”  about  the  properties  of  an
instruction, to enable execution to begin for other instructions that may depend
on the speculated instruction. For example, we might speculate on the outcome of
a branch, so that instructions after the branch could be executed earlier. Another
example is that we might speculate that a store that precedes a load does not refer to
the same address, which would allow the load to be executed before the store. The
difficulty with speculation is that it may be wrong. So, any speculation mechanism
must include both a method to check if the guess was right and a method to unroll
or  back  out  the  effects  of  the  instructions  that  were  executed  speculatively.  The
implementation of this back-out capability adds complexity.

Speculation may be done in the compiler or by the hardware. For example, the
compiler can use speculation to reorder instructions, moving an instruction across
a branch or a load across a store. The processor hardware can perform the same
transformation at runtime using techniques we discuss later in this section.

The recovery mechanisms used for incorrect speculation are rather different.
In  the  case  of  speculation  in  software,  the  compiler  usually  inserts  additional
instructions  that  check  the  accuracy  of  the  speculation  and  provide  a  fix-up
routine  to  use  when  the  speculation  is  wrong.  In  hardware  speculation,  the
processor usually buffers the speculative results until it knows they are no longer
speculative.  If  the  speculation  is  correct,  the  instructions  are  completed  by
allowing the contents of the buffers to be written to the registers or memory. If
the speculation is incorrect, the hardware flushes the buffers and re-executes the
correct instruction sequence. Misspeculation typically requires the pipeline to be
flushed, or at least stalled, and thus further reduces performance.

Speculation  introduces  one  other  possible  problem:  speculating  on  certain
instructions may introduce exceptions that were formerly not present. For example,
suppose a load instruction is moved in a speculative manner, but the address it uses
is not within bounds when the speculation is incorrect. The result would be that an
exception that should not have occurred would occur. The problem is complicated
by  the  fact  that  if  the  load  instruction  were  not  speculative,  then  the  exception
must occur! In compiler-based speculation, such problems are avoided by adding
special  speculation  support  that  allows  such  exceptions  to  be  ignored  until  it  is
clear  that  they  really  should  occur.  In  hardware-based  speculation,  exceptions
are simply buffered until it is clear that the instruction causing them is no longer
speculative  and  is  ready  to  complete;  at  that  point,  the  exception  is  raised,  and
normal exception handling proceeds.

324

Chapter 4  The Processor

issue packet  The set
of instructions that
issues together in one
clock cycle; the packet
may be determined
statically by the compiler
or dynamically by the
processor.

Very Long Instruction
Word (VLIW)  A
style of instruction set
architecture that launches
many operations that are
defined to be independent
in a single-wide
instruction, typically with
many separate opcode
fields.

Since speculation can improve performance when done properly and decrease
performance  when  done  carelessly,  significant  effort  goes  into  deciding  when  it
is appropriate to speculate. Later in this section, we will examine both static and
dynamic techniques for speculation.

Static Multiple Issue

Static  multiple-issue  processors  all  use  the  compiler  to  assist  with  packaging
instructions and handling hazards. In a static issue processor, you can think of the
set of instructions issued in a given clock cycle, which is called an issue packet, as
one large instruction with multiple operations. This view is more than an analogy.
Since a static multiple-issue processor usually restricts what mix of instructions can
be initiated in a given clock cycle, it is useful to think of the issue packet as a single
instruction allowing several operations in certain predefined fields. This view led to
the original name for this approach: Very Long Instruction Word (VLIW).

Most  static  issue  processors  also  rely  on  the  compiler  to  take  on  some
responsibility for handling data and control hazards. The compiler’s responsibilities
may include static branch prediction and code scheduling to reduce or prevent all
hazards. Let’s look at a simple static issue version of an RISC-V processor, before we
describe the use of these techniques in more aggressive processors.

An Example: Static Multiple Issue with the RISC-V ISA

To  give  a  flavor  of  static  multiple  issue,  we  consider  a  simple  two-issue  RISC-V
processor,  where  one  of  the  instructions  can  be  an  integer  ALU  operation  or
branch  and  the  other  can  be  a  load  or  store.  Such  a  design  is  like  that  used  in
some embedded processors. Issuing two instructions per cycle will require fetching
and decoding 64 bits of instructions. In many static multiple-issue processors, and
essentially all VLIW processors, the layout of simultaneously issuing instructions
is restricted to simplify the decoding and instruction issue. Hence, we will require
that the instructions be paired and aligned on a 64-bit boundary, with the ALU
or  branch  portion  appearing  first.  Furthermore,  if  one  instruction  of  the  pair
cannot be used, we require that it be replaced with a nop. Thus, the instructions
always issue in pairs, possibly with a nop in one slot. Figure 4.65 shows how the
instructions look as they go into the pipeline in pairs.

Static multiple-issue processors vary in how they deal with potential data and
control hazards. In some designs, the compiler takes full responsibility for removing
all hazards, scheduling the code, and inserting no-ops so that the code executes
without any need for hazard detection or hardware-generated stalls. In others, the
hardware detects data hazards and generates stalls between two issue packets, while
requiring  that  the  compiler  avoid  all  dependences  within  an  instruction  packet.
Even so, a hazard generally forces the entire issue packet containing the dependent
instruction to stall. Whether the software must handle all hazards or only try to
reduce the fraction of hazards between separate issue packets, the appearance of

4.10  Parallelism via Instructions

325

Instruction type

ALU or branch instruction
Load or store instruction
ALU or branch instruction

IF
IF

Load or store instruction

noitcurtsnihcnarbroULA
noitcurtsnierotsrodaoL
noitcurtsnihcnarbroULA
noitcurtsnierotsrodaoL

ID
ID
IF

IF

EX
EX
ID

ID

FI
FI

Pipe stages

MEM WB
MEM WB
EX

MEM WB

EX

MEM WB

DI
DI
FI
FI

XE
XE
DI
DI

MEM
MEM
XE
XE

BW
BW
MEM
MEM

BW
BW

FIGURE  4.65  Static  two-issue  pipeline  in  operation.  The  ALU  and  data  transfer  instructions
are issued at the same time. Here we have assumed the same five-stage structure as used for the single-issue
pipeline.  Although  this  is  not  strictly  necessary,  it  does  have  some  advantages.  In  particular,  keeping  the
register  writes  at  the  end  of  the  pipeline  simplifies  the  handling  of  exceptions  and  the  maintenance  of  a
precise exception model, which become more difficult in multiple-issue processors.

having  a  large  single  instruction  with  multiple  operations  is  reinforced.  We  will
assume the second approach for this example.

To  issue  an  ALU  and  a  data  transfer  operation  in  parallel,  the  first  need  for
additional hardware—beyond the usual hazard detection and stall logic—is extra
ports in the register file (see Figure 4.66). In one clock cycle, we may need to read
two registers for the ALU operation and two more for a store, and also one write
port  for  an  ALU  operation  and  one  write  port  for  a  load.  Since  the  ALU  is  tied
up for the ALU operation, we also need a separate adder to calculate the effective
address  for  data  transfers.  Without  these  extra  resources,  our  two-issue  pipeline
would be hindered by structural hazards.

Clearly, this two-issue processor can improve performance by up to a factor of
two!  Doing  so,  however,  requires  that  twice  as  many  instructions  be  overlapped
in  execution,  and  this  additional  overlap  increases  the  relative  performance  loss
from  data  and  control  hazards.  For  example,  in  our  simple  five-stage  pipeline,
loads have a use latency of one clock cycle, which prevents one instruction from
using the result without stalling. In the two-issue, five-stage pipeline the result of
a load instruction cannot be used on the next clock cycle. This means that the next
two  instructions  cannot  use  the  load  result  without  stalling.  Furthermore,  ALU
instructions that had no use latency in the simple five-stage pipeline now have a
one-instruction use latency, since the results cannot be used in the paired load or
store. To effectively exploit the parallelism available in a multiple-issue processor,
more ambitious compiler or hardware scheduling techniques are needed, and static
multiple issue requires that the compiler take on this role.

use latency  Number
of clock cycles between
a load instruction and
an instruction that can
use the result of the
load without stalling the
pipeline.

326

Chapter 4  The Processor

+

4

1C090000

PC

Instruction
memory

+

Registers

Imm
Gen

Imm
Gen

ALU

ALU

Write
data

Data
memory

Address

FIGURE 4.66  A static two-issue datapath. The additions needed for double issue are highlighted: another 32 bits from instruction
memory,  two  more  read  ports  and  one  more  write  port  on  the  register  file,  and  another  ALU.  Assume  the  bottom  ALU  handles  address
calculations for data transfers and the top ALU handles everything else.

EXAMPLE

Simple Multiple-Issue Code Scheduling

How would this loop be scheduled on a static two-issue pipeline for RISC-V?

Loop: ld

x31, 0(x20)

// x31=array element
 add  x31, x31, x21  // add scalar in x21
 sd
 addi  x20, x20, -8
 blt  x22, x20, Loop  // compare to loop limit,

// store result
// decrement pointer

x31, 0(x20)

ANSWER

// branch if x20 > x22

Reorder the instructions to avoid as many pipeline stalls as possible. Assume

branches are predicted, so that control hazards are handled by the hardware.

The first three instructions have data dependences, as do the next two. Figure
4.67 shows the best schedule for these instructions. Notice that just one pair
of instructions has both issue slots used. It takes five clocks per loop iteration;
at four clocks to execute five instructions, we get the disappointing CPI of 0.8
versus the best case of 0.5, or an IPC of 1.25 versus 2.0. Notice that in computing
CPI or IPC, we do not count any nops executed as useful instructions. Doing
so would improve CPI, but not performance!

4.10  Parallelism via Instructions

327

ALU or branch instruction

Data transfer instruction

Clock cycle

Loop:

ld x31, 0(x20)

addi x20,  x20, -8

add  x31,  x31, x21

blt  x22,  x20, Loop

sd x31, 8(x20)

1

2

3

4

FIGURE  4.67  The  scheduled  code  as  it  would  look  on  a  two-issue  RISC-V  pipeline.  The
empty slots are no-ops. Note that since we moved the addi before the sd, we had to adjust sd’s offset by 8.

An important compiler technique to get more performance from loops is loop
unrolling, where multiple copies of the loop body are made. After unrolling, there
is more ILP available by overlapping instructions from different iterations.

loop unrolling  A
technique to get more
performance from loops
that access arrays, in
which multiple copies of
the loop body are made
and instructions from
different iterations are
scheduled together.

Loop Unrolling for Multiple-Issue Pipelines

See how well loop unrolling and scheduling work in the example above. For
simplicity, assume that the loop index is a multiple of four.

To schedule the loop without any delays, it turns out that we need to make four
copies of the loop body. After unrolling and eliminating the unnecessary loop
overhead instructions, the loop will contain four copies each of ld, add, and
sd, plus one addi, and one blt. Figure 4.68 shows the unrolled and scheduled
code.

During the unrolling process, the compiler introduced additional registers
(x28,  x29,  x30).  The  goal  of  this  process,  called  register  renaming,  is  to
eliminate  dependences  that  are  not  true  data  dependences,  but  could  either
lead to potential hazards or prevent the compiler from flexibly scheduling the
code. Consider how the unrolled code would look using only x31. There would
be repeated instances of ld x31, 0(x20), add x31, x31, x21 followed by sd
x31, 8(x20), but these sequences, despite using x31, are actually completely
independent—no data values flow between one set of these instructions and the
next set. This case is what is called an antidependence or name dependence,
which is an ordering forced purely by the reuse of a name, rather than a real
data dependence that is also called a true dependence.

Renaming the registers during the unrolling process allows the compiler to
move these independent instructions subsequently to better schedule the code.
The renaming process eliminates the name dependences, while preserving the
true dependences.

EXAMPLE

ANSWER

register renaming  The
renaming of registers
by the compiler or
hardware to remove
antidependences.

antidependence
Also called name
dependence  An
ordering forced by the
reuse of a name, typically
a register, rather than by
a true dependence that
carries a value between
two instructions.

328

Chapter 4  The Processor

ALU or branch instruction

Data transfer instruction

Clock cycle

Loop:

addi x20, x20, -32

add x28, x28, x21

add x29, x29, x21

add x30, x30, x21

add x31, x31, x21

blt x22, x20, Loop

ld x28, 0(x20)

ld x29, 24(x20)

ld x30, 16(x20)

ld x31, 8(x20)

sd x28, 32(x20)

sd x29, 24(x20)

sd x30, 16(x20)

sd x31, 8(x20)

1

2

3

4

5

6

7

8

FIGURE 4.68  The unrolled and scheduled code of Figure 4.67 as it would look on a static
two-issue RISC-V pipeline. The empty slots are no-ops. Since the first instruction in the loop decrements
x20 by 32, the addresses loaded are the original value of x20, then that address minus 8, minus 16, and
minus 24.

Notice now that 12 of the 14 instructions in the loop execute as pairs. It takes
eight clocks for four loop iterations, which yields an IPC of 14/8 = 1.75. Loop
unrolling and scheduling more than doubled performance—8 versus 20 clock
cycles for 4 iterations—partly from reducing the loop control instructions and
partly from dual issue execution. The cost of this performance improvement is
using four temporary registers rather than one, as well as more than doubling
the code size.

Dynamic Multiple-Issue Processors

Dynamic multiple-issue processors are also known as superscalar processors, or
simply  superscalars.  In  the  simplest  superscalar  processors,  instructions  issue  in
order, and the processor decides whether zero, one, or more instructions can issue
in a given clock cycle. Obviously, achieving good performance on such a processor
still  requires  the  compiler  to  try  to  schedule  instructions  to  move  dependences
apart  and  thereby  improve  the  instruction  issue  rate.  Even  with  such  compiler
scheduling,  there  is  an  important  difference  between  this  simple  superscalar
and  a  VLIW  processor:  the  code,  whether  scheduled  or  not,  is  guaranteed  by
the  hardware  to  execute  correctly.  Furthermore,  compiled  code  will  always  run
correctly independent of the issue rate or pipeline structure of the processor. In
some VLIW designs, this has not been the case, and recompilation was required
when moving across different processor models; in other static issue processors,
code would run correctly across different implementations, but often so poorly as
to make compilation effectively required.

Many  superscalars  extend  the  basic  framework  of  dynamic  issue  decisions  to
include  dynamic  pipeline  scheduling.  Dynamic  pipeline  scheduling  chooses
which instructions to execute in a given clock cycle while trying to avoid hazards

superscalar  An
advanced pipelining
technique that enables the
processor to execute more
than one instruction per
clock cycle by selecting
them during execution.

dynamic pipeline
scheduling  Hardware
support for reordering
the order of instruction
execution to avoid stalls.

4.10  Parallelism via Instructions

329

and stalls. Let’s start with a simple example of avoiding a data hazard. Consider the
following code sequence:

x31, 0(x21)

ld
add  x1,  x31, x2
sub  x23, x23, x3
andi  x5,  x23, 20

Even  though  the  sub  instruction  is  ready  to  execute,  it  must  wait  for  the  ld
and add to complete first, which might take many clock cycles if memory is slow.
(Chapter 5 explains cache misses, the reason that memory accesses are sometimes
very slow.) Dynamic pipeline scheduling allows such hazards to be avoided either
fully or partially.

Dynamic Pipeline Scheduling

Dynamic pipeline scheduling chooses which instructions to execute next, possibly
reordering  them  to  avoid  stalls.  In  such  processors,  the  pipeline  is  divided  into
three  major  units:  an  instruction  fetch  and  issue  unit,  multiple  functional  units
(a dozen or more in high-end designs in 2015), and a commit unit. Figure 4.69
shows  the  model.  The  first  unit  fetches  instructions,  decodes  them,  and  sends
each instruction to a corresponding functional unit for execution. Each functional
unit  has  buffers,  called  reservation  stations,  which  hold  the  operands  and  the
operation. (In the next section, we will discuss an alternative to reservation stations
used by many recent processors.) As soon as the buffer contains all its operands
and the functional unit is ready to execute, the result is calculated. When the result
is completed, it is sent to any reservation stations waiting for this particular result
as  well  as  to  the  commit  unit,  which  buffers  the  result  until  it  is  safe  to  put  the
result into the register file or, for a store, into memory. The buffer in the commit
unit, often called the reorder buffer, is also used to supply operands, in much the
same way as forwarding logic does in a statically scheduled pipeline. Once a result
is committed to the register file, it can be fetched directly from there, just as in a
normal pipeline.

The combination of buffering operands in the reservation stations and results
in the reorder buffer provides a form of register renaming, just like that used by
the compiler in our earlier loop-unrolling example on page 327. To see how this
conceptually works, consider the following steps:

1.  When  an  instruction  issues,  it  is  copied  to  a  reservation  station  for  the
appropriate functional unit. Any operands that are available in the register
file or reorder buffer are also immediately copied into the reservation station.
The instruction is buffered in the reservation station until all the operands
and the functional unit are available. For the issuing instruction, the register
copy  of  the  operand  is  no  longer  required,  and  if  a  write  to  that  register
occurred, the value could be overwritten.

commit unit  The unit in
a dynamic or out-of-order
execution pipeline that
decides when it is safe to
release the result of an
operation to programmer-
visible registers and
memory.

reservation station  A
buffer within a functional
unit that holds the
operands and the
operation.

reorder buffer  The
buffer that holds results in
a dynamically scheduled
processor until it is safe
to store the results to
memory or a register.

330

Chapter 4  The Processor

Instruction fetch
and decode unit

In-order issue

Reservation
station

Reservation
station

. . .

Reservation
station

Reservation
station

Functional
units

Integer

Integer

. . .

Floating
point

Load-
store

Out-of-order execute

Commit
unit

In-order commit

FIGURE 4.69  The three primary units of a dynamically scheduled pipeline. The final step of
updating the state is also called retirement or graduation.

2.  If an operand is not in the register file or reorder buffer, it must be waiting to
be produced by a functional unit. The name of the functional unit that will
produce the result is tracked. When that unit eventually produces the result,
it is copied directly into the waiting reservation station from the functional
unit bypassing the registers.

These  steps  effectively  use  the  reorder  buffer  and  the  reservation  stations  to

implement register renaming.

Conceptually, you can think of a dynamically scheduled pipeline as analyzing
the data flow structure of a program. The processor then executes the instructions
in  some  order  that  preserves  the  data  flow  order  of  the  program.  This  style  of
execution  is  called  an  out-of-order  execution,  since  the  instructions  can  be
executed in a different order than they were fetched.

To make programs behave as if they were running on a simple in-order pipeline,
the  instruction  fetch  and  decode  unit  is  required  to  issue  instructions  in  order,
which allows dependences to be tracked, and the commit unit is required to write
results to registers and memory in program fetch order. This conservative mode is
called in-order commit. Hence, if an exception occurs, the computer can point to
the last instruction executed, and the only registers updated will be those written

out-of-order
execution  A situation in
pipelined execution when
an instruction blocked
from executing does
not cause the following
instructions to wait.

in-order commit  A
commit in which the
results of pipelined
execution are written to
the programmer visible
state in the same order
that instructions are
fetched.

4.10  Parallelism via Instructions

331

by instructions before the instruction causing the exception. Although the front
end (fetch and issue) and the back end (commit) of the pipeline run in order, the
functional  units  are  free  to  initiate  execution  whenever  the  data  they  need  are
available. Today, all dynamically scheduled pipelines use in-order commit.

Dynamic  scheduling

is  often  extended  by

including  hardware-based
speculation,  especially  for  branch  outcomes.  By  predicting  the  direction  of  a
branch,  a  dynamically  scheduled  processor  can  continue  to  fetch  and  execute
instructions  along  the  predicted  path.  Because  the  instructions  are  committed
in  order,  we  know  whether  the  branch  was  correctly  predicted  before  any
instructions from the predicted path are committed. A speculative, dynamically
scheduled pipeline can also support speculation on load addresses, allowing load-
store reordering, and using the commit unit to avoid incorrect speculation. In the
next section, we will look at the use of dynamic scheduling with speculation in
the Intel Core i7 design.

Understanding
Program
Performance

Given that compilers can also schedule code around data dependences, you might
ask why a superscalar processor would use dynamic scheduling. There are three
major  reasons.  First,  not  all  stalls  are  predictable.  In  particular,  cache  misses
(see  Chapter  5)  in  the  memory  hierarchy  cause  unpredictable  stalls.  Dynamic
scheduling  allows  the  processor  to  hide  some  of  those  stalls  by  continuing  to
execute instructions while waiting for the stall to end.

Second, if the processor speculates on branch outcomes using dynamic branch
prediction, it cannot know the exact order of instructions at compile time, since
it  depends  on  the  predicted  and  actual  behavior  of  branches.  Incorporating
dynamic speculation to exploit more instruction-level parallelism (ILP) without
incorporating  dynamic  scheduling  would  significantly  restrict  the  benefits  of
speculation.

Third, as the pipeline latency and issue width change from one implementation
to another, the best way to compile a code sequence also changes. For example, how
to schedule a sequence of dependent instructions is affected by both issue width
and latency. The pipeline structure affects both the number of times a loop must be
unrolled to avoid stalls as well as the process of compiler-based register renaming.
Dynamic scheduling allows the hardware to hide most of these details. Thus, users
and software distributors do not need to worry about having multiple versions of
a program for different implementations of the same instruction set. Similarly, old
legacy code will get much of the benefit of a new implementation without the need
for recompilation.

332

Chapter 4  The Processor

The BIG
Picture

Both  pipelining  and  multiple-issue  execution  increase  peak  instruction
throughput  and  attempt  to  exploit  instruction-level  parallelism  (ILP).
Data and control dependences in programs, however, offer an upper limit
on sustained performance because the processor must sometimes wait for
a  dependence  to  be  resolved.  Software-centric  approaches  to  exploiting
ILP rely on the ability of the compiler to find and reduce the effects of such
dependences, while hardware-centric approaches rely on extensions to the
pipeline and issue mechanisms. Speculation, performed by the compiler
or the hardware, can increase the amount of ILP that can be exploited via
prediction, although care must be taken since speculating incorrectly is
likely to reduce performance.

Hardware/
Software
Interface

Modern,  high-performance  microprocessors  are  capable  of  issuing  several
instructions per clock; unfortunately, sustaining that issue rate is very difficult. For
example, despite the existence of processors with four to six issues per clock, very
few applications can sustain more than two instructions per clock. There are two
primary reasons for this.

First,  within  the  pipeline,  the  major  performance  bottlenecks  arise  from
dependences  that  cannot  be  alleviated,  thus  reducing  the  parallelism  among
instructions and the sustained issue rate. Although little can be done about true
data dependences, often the compiler or hardware does not know precisely whether
a  dependence  exists  or  not,  and  so  must  conservatively  assume  the  dependence
exists.  For  example,  code  that  makes  use  of  pointers,  particularly  in  ways  that
may lead to aliasing, will lead to more implied potential dependences. In contrast,
the greater regularity of array accesses often allows a compiler to deduce that no

4.10  Parallelism via Instructions

333

dependences exist. Similarly, branches that cannot be accurately predicted whether
at runtime or compile time will limit the ability to exploit ILP. Often, additional
ILP is available, but the ability of the compiler or the hardware to find ILP that may
be widely separated (sometimes by the execution of thousands of instructions) is
limited.

Second, losses in the memory hierarchy (the topic of Chapter 5) also limit the
ability  to  keep  the  pipeline  full.  Some  memory  system  stalls  can  be  hidden,  but
limited amounts of ILP also limit the extent to which such stalls can be hidden.

Energy Efficiency and Advanced Pipelining

The  downside  to  the  increasing  exploitation  of  instruction-level  parallelism  via
dynamic  multiple  issue  and  speculation  is  potential  energy  inefficiency.  Each
innovation was able to turn more transistors into performance, but they often did
so very inefficiently. Now that we have collided with the power wall, we are seeing
designs with multiple processors per chip where the processors are not as deeply
pipelined or as aggressively speculative as its predecessors.

The belief is that while the simpler processors are not as fast as their sophisticated
brethren, they deliver better performance per Joule, so that they can deliver more
performance per chip when designs are constrained more by energy than they are
by the number of transistors.

Figure 4.70 shows the number of pipeline stages, the issue width, speculation
level,  clock  rate,  cores  per  chip,  and  power  of  several  past  and  recent  Intel
microprocessors. Note the drop in pipeline stages and power as companies switch
to multicore designs.

Microprocessor

684letnI
muitnePletnI
Intel Pentium Pro
Intel Pentium 4 Willamette
Intel Pentium 4 Prescott
eroCletnI
Intel Core i5 Nehalem
Intel Core i5 Ivy Bridge

Year

9891
3991
1997
2001
2004
6002
2010
2012

Clock Rate

Pipeline
Stages

Issue
Width

Out-of-Order/
Speculation

Cores/
Chip

Power

zHM52
zHM66
200 MHz
2000 MHz
3600 MHz
zHM0392
3300 MHz
3400 MHz

5
5
10
22
31
41
14
14

1
2
3
3
3
4
4
4

oN
oN
Yes
Yes
Yes
seY
Yes
Yes

1
1
1
1
1
2
2–4
8

5
01
29
75
103
57
87
77

W
W
W
W
W
W
W
W

FIGURE 4.70  Record of Intel Microprocessors in terms of pipeline complexity, number of cores, and power. The Pentium
4 pipeline stages do not include the commit stages. If we included them, the Pentium 4 pipelines would be even deeper.

334

Chapter 4  The Processor

Elaboration:  A commit unit controls updates to the register file and memory. Some
dynamically scheduled processors update the register file immediately during execution,
using extra registers to implement the renaming function and preserving the older copy
of a register until the instruction updating the register is no longer speculative. Other
processors buffer the result, which, as mentioned above, is typically in a structure called
a reorder buffer, and the actual update to the register file occurs later as part of the
commit. Stores to memory must be buffered until commit time either in a store buffer
(see Chapter 5) or in the reorder buffer. The commit unit allows the store to write to
memory from the buffer when the buffer has a valid address and valid data, and when
the store is no longer dependent on predicted branches.

Elaboration:  Memory  accesses  benefit  from  nonblocking  caches,  which  continue
servicing cache accesses during a cache miss (see Chapter 5). Out-of-order execution
processors need the cache to allow instructions to execute during a miss.

Check
Yourself

State  whether  the  following  techniques  or  components  are  associated  primarily
with a software- or hardware-based approach to exploiting ILP. In some cases, the
answer may be both.

1.  Branch prediction

2.  Multiple issue

3.  VLIW

4.  Superscalar

5.  Dynamic scheduling

6.  Out-of-order execution

7.  Speculation

8.  Reorder buffer

9.  Register renaming

 4.11

Real Stuff: The ARM Cortex-A53 and Intel
Core i7 Pipelines

Figure 4.71 describes the two microprocessors we examine in this section, whose
targets are the two endpoints of the post-PC era.

The ARM Cortex-A53

The ARM Corxtex-A53 runs at 1.5 GHz with an eight-stage pipeline and executes
the ARMv8 instruction set. It uses dynamic multiple issue, with two instructions
per clock cycle. It is a static in-order pipeline, in that instructions issue, execute,
and commit in order. The pipeline consists of three sections for instruction fetch,
instruction decode, and execute. Figure 4.72 shows the overall pipeline.

4.11  Real Stuff: The ARM Cortex-A53 and Intel Core i7 Pipelines

335

Processor

ARM A53

Intel Core i7 920

tekraM
Thermal design power
etar kcolC

eciveD eliboM lanosreP
100 milliWatts (1 core @ 1 GHz)
zHG 5.1

?tniop gnitaolF
?eussI elpitluM
elcyc kcolc/snoitcurtsni kaeP
segatS enilepiP
eludehcs enilepiP
noitciderp hcnarB
1st level caches/core
2nd level cache/core
)derahs( ehcac level dr3

)elbarug
seY
cimanyD
2
8
redro-nI citatS
dirbyH
16-64 KiB I, 16-64 KiB D
128–2048 KiB (shared)
)tnedneped mroftalp(

duolC ,revreS
130 Watts
zHG 66.2
4
seY
cimanyD
4
41
noitalucepS htiw redro-fo-tuO cimanyD
level-2
32 KiB I, 32 KiB D
256 KiB (per core)
BiM 8–2

FIGURE 4.71  Specification of the ARM Cortex-A53 and the Intel Core i7 920.

F1

F2

F3

F4

Iss

Ex1

Ex2

Wr

Instruction fetch & predict

Integer execute and load-store

AGU
+
TLB

Instruction
Cache

Hybrid
Predictor

Indirect
Predictor

Integer
Register
file

Issue

ALU pipe 0

ALU pipe 1

MAC pipe

Divide pipe

Load pipe

Store pipe

Writeback

Instruction Decode

Floating Point execute

Early
Decode

13-Entry
Instruction
Queue

Main
Decode

Late
Decode

NEON
Register
file

MUL/DIV/SQRT pipe

ALU pipe

D1

D2

D3

F1

F2

F3

F4

F5

FIGURE  4.72  The  Cortex-A53  pipeline.  The  first  three  stages  fetch  instructions  into  a  13-entry  instruction  queue.  The  Address
Generation Unit (AGU) uses a Hybrid Predictor, Indirect Predictor, and a Return Stack to predict branches to try to keep the instruction queue
full.  Instruction  decode  is  three  stages  and  instruction  execution  is  three  stages.  With  two  additional  stages  for  floating  point  and  SIMD
operations.

336

Chapter 4  The Processor

The first three stages fetch two instructions at a time and try to keep a 13-entry
instruction  queue  full.  It  uses  a  6k-bit  hybrid  conditional  branch  predictor,  a
256-entry indirect branch predictor, and an 8-entry return address stack to predict
future  function  returns.  The  prediction  of  indirect  branches  takes  an  additional
pipeline stage. This design choice will incur extra latency if the instruction queue
cannot decouple the decode and execute stages from the fetch stage, primarily in
the case of a branch misprediction or an instruction cache miss. When the branch
prediction  is  wrong,  it  empties  the  pipeline,  resulting  in  an  eight-clock  cycle
misprediction penalty.

The decode stages of the pipeline determine if there are dependences between a
pair of instructions, which would force sequential execution, and in which pipeline
of the execution stages to send the instructions.

The  instruction  execution  section  primarily  occupies  three  pipeline  stages  and
provides one pipeline for load instructions, one pipeline for store instructions, two
pipelines for integer arithmetic operations, and separate pipelines for integer multiply
and divide operations. Either instruction from the pair can be issued to the load or
store pipelines. The execution stages have full forwarding between the pipelines.

Floating-point  and  SIMD  operations  add  a  two  more  pipeline  stages  to  the
instruction execution section and feature one pipeline for multiply/divide/square
root operations and one pipeline for other arithmetic operations.

Figure 4.73 shows the CPI of the Cortex-A53 using the SPEC2006 benchmarks.
While the ideal CPI is 0.5, the best case achieved is 1.0, the median case is 1.3, and

Memory hierarchy stalls
Pipeline stalls
Ideal CPI

8.56

0.97

1.04

1.07

1.17

1.22

1.33

1.39

3.37

1.75

1.76

2.14

10.00

9.00

8.00

7.00

6.00

5.00

4.00

3.00

2.00

1.00

0.00

hmmer

h264ref

libquantum perlbench

sjeng

bzip2

gobmk

xalancbmk

gcc

astar

omnetpp

mcf

FIGURE 4.73  CPI on ARM Cortex-A53 for the SPEC2006 integer benchmarks.

4.11  Real Stuff: The ARM Cortex-A53 and Intel Core i7 Pipelines

337

the worst case is 8.6. For the median case, 60% of the stalls are due to the pipelining
hazards and 40% are stalls due to the memory hierarchy. Pipeline stalls are caused
by branch mispredictions, structural hazards, and data dependencies between pairs
of instructions. Given the static pipeline of the Cortex-A53, it is up to the compiler
to try to avoid structural hazards and data dependences.

Elaboration:  The  Cortex-A53  is  a  configurable  core  that  supports  the  ARMv8
instruction set architecture. It is delivered as an IP (Intellectual Property) core. IP cores
are the dominant form of technology delivery in the embedded, personal mobile device,
and  related  markets;  billions  of  ARM  and  MIPS  processors  have  been  created  from
these IP cores.

Note that IP cores are different than the cores in the Intel i7 multicore computers.
An IP core (which may itself be a multicore) is designed to be incorporated with other
logic (hence it is the “core” of a chip), including application-specific processors (such
as an encoder or decoder for video), I/O interfaces, and memory interfaces, and then
fabricated  to  yield  a  processor  optimized  for  a  particular  application.  Although  the
processor core is almost identical logically, the resultant chips have many differences.
One parameter is the size of the L2 cache, which can vary by a factor of 16.

The Intel Core i7 920

x86  microprocessors  employ  sophisticated  pipelining  approaches,  using  both
dynamic  multiple  issue  and  dynamic  pipeline  scheduling  with  out-of-order
execution and speculation for their pipelines. These processors, however, are still
faced with the challenge of implementing the complex x86 instruction set, described
in  Chapter  2.  Intel  fetches  x86  instructions  and  translates  them  into  internal
RISC-V-like instructions, which Intel calls micro-operations. The micro-operations
are then executed by a sophisticated, dynamically scheduled, speculative pipeline
capable  of  sustaining  an  execution  rate  of  up  to  six  micro-operations  per  clock
cycle. This section focuses on that micro-operation pipeline.

When we consider the design of such processors, the design of the functional
units,  the  cache  and  register  file,  instruction  issue,  and  overall  pipeline  control
become  intermingled,  making  it  difficult  to  separate  the  datapath  from  the
pipeline. Because of this, many engineers and researchers have adopted the term
microarchitecture to refer to the detailed internal architecture of a processor.

The  Intel  Core  i7  uses  a  scheme  for  resolving  antidependences  and  incorrect
speculation  that  uses  a  reorder  buffer  together  with  register  renaming.  Register
renaming explicitly renames the architectural registers in a processor (16 in the
case of the 64-bit version of the x86 architecture) to a larger set of physical registers.
The Core i7 uses register renaming to remove antidependences. Register renaming
requires the processor to maintain a map between the architectural registers and
the physical registers, indicating which physical register is the most current copy
of an architectural register. By keeping track of the renamings that have occurred,
register  renaming  offers  another  approach  to  recovery  in  the  event  of  incorrect
speculation: simply undo the mappings that have occurred since the first incorrectly

microarchitecture  The
organization of the
processor, including the
major functional units,
their interconnection, and
control.

architectural
registers  The instruction
set of visible registers of a
processor; for example, in
RISC-V, these are the 32
integer and 32 floating-
point registers.

338

Chapter 4  The Processor

speculated instruction. This undo will cause the state of the processor to return to
the last correctly executed instruction, keeping the correct mapping between the
architectural and physical registers.

Figure 4.74 shows the overall organization and pipeline of the Core i7. Below are

the eight steps an x86 instruction goes through for execution.

1.  Instruction  fetch—The  processor  uses  a  multilevel  branch  target  buffer  to
achieve  a  balance  between  speed  and  prediction  accuracy.  There  is  also  a
return  address  stack  to  speed  up  function  return.  Mispredictions  cause  a
penalty of about 15 cycles. Using the predicted address, the instruction fetch
unit fetches 16 bytes from the instruction cache.

2.  The 16 bytes are placed in the predecode instruction buffer—The predecode
stage transforms the 16 bytes into individual x86 instructions. This predecode
is nontrivial since the length of an x86 instruction can be from 1 to 15 bytes

128-Entry
inst. TLB
(four-way)

Instruction
fetch
hardware

Micro
-code

32 KB Inst. cache (four-way associative)

16-Byte pre-decode + macro-op
fusion, fetch buffer

18-Entry instruction queue

Complex
macro-op
decoder

Simple
macro-op
decoder

Simple
macro-op
decoder

Simple
macro-op
decoder

28-Entry micro-op loop stream detect buffer

Retirement
register file

Register alias table and allocator

128-Entry reorder buffer

36-Entry reservation station

ALU
shift

SSE
shuffle
ALU

128-bit
FMUL
FDIV

ALU
shift

Load
address

Store
address

Store
data

ALU
shift

SSE
shuffle
ALU

128-bit
FMUL
FDIV

Memory order buffer

Store
& load

SSE
shuffle
ALU

128-bit
FMUL
FDIV

512-Entry unified
L2 TLB (4-way)

64-Entry data TLB
(4-way associative)

32-KB dual-ported data
cache (8-way associative)

256 KB unified L2
cache (eight-way)

8 MB all core shared and inclusive L3
cache (16-way associative)

Uncore arbiter (handles scheduling and
clock/power state differences)

FIGURE  4.74  The  Core  i7  pipeline  with  memory  components.  The  total pipeline depth is 14
stages, with branch mispredictions costing 17 clock cycles. This design can buffer 48 loads and 32 stores. The
six independent units can begin execution of a ready micro-operation each clock cycle.

4.11  Real Stuff: The ARM Cortex-A53 and Intel Core i7 Pipelines

339

and the predecoder must look through a number of bytes before it knows the
instruction length. Individual x86 instructions are placed into the 18-entry
instruction queue.

3.  Micro-op  decode—Individual  x86  instructions  are  translated  into  micro-
operations (micro-ops). Three of the decoders handle x86 instructions that
translate  directly  into  one  micro-op.  For  x86  instructions  that  have  more
complex semantics, there is a microcode engine that is used to produce the
micro-op  sequence;  it  can  produce  up  to  four  micro-ops  every  cycle  and
continues until the necessary micro-op sequence has been generated. The
micro-ops are placed according to the order of the x86 instructions in the
28-entry micro-op buffer.

4.  The  micro-op  buffer  performs  loop  stream  detection—If  there  is  a  small
sequence of instructions (less than 28 instructions or 256 bytes in length)
that comprises a loop, the loop stream detector will find the loop and directly
issue the micro-ops from the buffer, eliminating the need for the instruction
fetch and instruction decode stages to be activated.

5.  Perform the basic instruction issue—Looking up the register location in the
register tables, renaming the registers, allocating a reorder buffer entry, and
fetching any results from the registers or reorder buffer before sending the
micro-ops to the reservation stations.

6.  The i7 uses a 36-entry centralized reservation station shared by six functional
units. Up to six micro-ops may be dispatched to the functional units every
clock cycle.

7.  The individual function units execute micro-ops and then results are sent
back to any waiting reservation station as well as to the register retirement
unit,  where  they  will  update  the  register  state,  once  it  is  known  that  the
instruction  is  no  longer  speculative.  The  entry  corresponding  to  the
instruction in the reorder buffer is marked as complete.

8.  When one or more instructions at the head of the reorder buffer have been
marked as complete, the pending writes in the register retirement unit are
executed, and the instructions are removed from the reorder buffer.

Elaboration:  Hardware in the second and fourth steps can combine or fuse operations
together to reduce the number of operations that must be performed. Macro-op fusion
in the second step takes x86 instruction combinations, such as compare followed by a
branch, and fuses them into a single operation. Microfusion in the fourth step combines
micro-operation pairs such as load/ALU operation and ALU operation/store and issues
them  to  a  single  reservation  station  (where  they  can  still  issue  independently),  thus
increasing the usage of the buffer. In a study of the Intel Core architecture, which also
incorporated microfusion and macrofusion, Bird et al. [2007] discovered that microfusion
had little impact on performance, while macrofusion appears to have a modest positive
impact on integer performance and little impact on floating-point performance.

340

Chapter 4  The Processor

Performance of the Intel Core i7 920

Figure 4.75 shows the CPI of the Intel Core i7 for each of the SPEC2006 benchmarks.
While the ideal CPI is 0.25, the best case achieved is 0.44, the median case is 0.79,
and the worst case is 2.67.

Although it is difficult to differentiate between pipeline stalls and memory stalls
in  a  dynamic  out-of-order  execution  pipeline,  we  can  show  the  effectiveness  of
branch prediction and speculation. Figure 4.76 shows the percentage of branches
mispredicted and the percentage of the work (measured by the numbers of micro-
ops  dispatched  into  the  pipeline)  that  does  not  retire  (that  is,  their  results  are
annulled) relative to all micro-op dispatches. The min, median, and max of branch
mispredictions are 0%, 2%, and 10%. For wasted work, they are 1%, 18%, and 39%.
The wasted work in some cases closely matches the branch misprediction rates,
such as for gobmk and astar. In several instances, such as mcf, the wasted work
seems  relatively  larger  than  the  misprediction  rate. This  divergence  is  likely  due
to the memory behavior. With very high data cache miss rates, mcf will dispatch
many instructions during an incorrect speculation as long as sufficient reservation
stations are available for the stalled memory references. When a branch among the
many speculated instructions is finally mispredicted, the micro-ops corresponding
to all these instructions will be flushed.

Stalls, misspeculation

Ideal CPI

2.67

2.12

3

2.5

2

I

P
1.5C

1

1.23

1.02  1.06

0.74  0.77

0.82

0.59  0.61  0.65

0.5 0.44

0

libquantum

h264ref

perlbench
hmmer

bzip2
xalancbmk

sjeng

gobmk

astar

mcf

omnetpp
gcc

FIGURE 4.75  CPI of Intel Core i7 920 running SPEC2006 integer benchmarks.

4.11  Real Stuff: The ARM Cortex-A53 and Intel Core i7 Pipelines

341

Branch misprediction %

Wasted work %

38%

39%

32%

24%

25%

40%

35%

30%

25%

20%

15%

10%

5%

22%

15%

6%

2%

2%

11%

10%

9%

5%

6%

5%

7%

5%

1%

0%

2%

2%

2%

0%

libquantum

h264ref

hmmer

perlbench

1%

bzip2
xalancbmk

sjeng

gobmk

astar

gcc

omnetpp

mcf

FIGURE  4.76  Percentage  of  branch  mispredictions  and  wasted  work  due  to  unfruitful
speculation of Intel Core i7 920 running SPEC2006 integer benchmarks.

Understanding
Program
Performance

The  Intel  Core  i7  combines  a  14-stage  pipeline  and  aggressive  multiple  issue  to
achieve  high  performance.  By  keeping  the  latencies  for  back-to-back  operations
low, the impact of data dependences is reduced. What are the most serious potential
performance bottlenecks for programs running on this processor? The following
list includes some possible performance problems, the last three of which can apply
in some form to any high-performance pipelined processor.

■	 The use of x86 instructions that do not map to a few simple micro-operations

■	 Branches that are difficult to predict, causing misprediction stalls and restarts

when speculation fails

■	 Long  dependences—typically  caused  by  long-running  instructions  or  the

memory hierarchy—that lead to stalls

■	 Performance delays arising in accessing memory (see Chapter 5) that cause

the processor to stall

342

Chapter 4  The Processor

 4.12  Going Faster: Instruction-Level
Parallelism and Matrix Multiply

Returning  to  the  DGEMM  example  from  Chapter  3,  we  can  see  the  impact  of
instruction-level parallelism by unrolling the loop so that the multiple-issue, out-
of-order execution processor has more instructions to work with. Figure 4.77 shows
the unrolled version of Figure 3.22, which contains the C intrinsics to produce the
AVX instructions.

Like the unrolling example in Figure 4.68 above, we are going to unroll the loop
four times. Rather than manually unrolling the loop in C by making four copies of
each of the intrinsics in Figure 3.22, we can rely on the gcc compiler to do the unrolling
at −O3 optimization. (We use the constant UNROLL in the C code to control the
amount of unrolling in case we want to try other values.) We surround each intrinsic
with a simple for loop with four iterations (lines 9, 15, and 20) and replace the scalar
C0 in Figure 3.22 with a four-element array c[] (lines 8, 10, 16, and 21).

for ( int i = 0; i < n; i+=UNROLL*4 )
for ( int j = 0; j < n; j++ ) {
  __m256d c[4];
  for ( int x = 0; x < UNROLL; x++ )
    c[x] = _mm256_load_pd(C+i+x*4+j*n);

1  //include <x86intrin.h>
2  //define UNROLL (4)
3
4  void dgemm (int n, double* A, double* B, double* C)
5  {
6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
21
22
23

  for( int k = 0; k < n; k++ )
  {
    __m256d b = _mm256_broadcast_sd(B+k+j*n);
    for (int x = 0; x < UNROLL; x++)
    c[x] = _mm256_add_pd(c[x],

  for ( int x = 0; x < UNROLL; x++ )
    _mm256_store_pd(C+i+x*4+j*n, c[x]);
  }

  }

}

_mm256_mul_pd(_mm256_load_pd(A+n*k+x*4+i), b));

FIGURE  4.77  Optimized  C  version  of  DGEMM  using  C  intrinsics  to  generate  the  AVX  subword-parallel  instructions
for the x86 (Figure 3.22) and loop unrolling to create more opportunities for instruction-level parallelism. Figure 4.78
shows the assembly language produced by the compiler for the inner loop, which unrolls the three for-loop bodies to expose instruction-level
parallelism.

4.12  Going Faster: Instruction-Level Parallelism and Matrix Multiply

343

Figure  4.78  shows  the  assembly  language  output  of  the  unrolled  code.  As
expected, in Figure 4.78 there are four versions of each of the AVX instructions
in Figure 3.23, with one exception. We only need one copy of the vbroadcastsd
instruction, since we can use the four copies of the B element in register  %ymm0
repeatedly  throughout  the  loop.  Thus,  the  five  AVX  instructions  in  Figure  3.23
become  17  in  Figure  4.78,  and  the  seven  integer  instructions  appear  in  both,
although the constants and addressing changes to account for the unrolling. Hence,
despite unrolling four times, the number of instructions in the body of the loop
only doubles: from 12 to 24.

1

2

3

4

5

6

7

8

9

10

11

12

13

14

15

16

17

18

19

20

21

22

23

24

vmovapd (%r11),%ymm4

// Load 4 elements of C into %ymm4

mov    %rbx,%rax

xor    %ecx,%ecx

// register %rax = %rbx

// register %ecx = 0

vmovapd 0x20(%r11),%ymm3

// Load 4 elements of C into %ymm3

vmovapd 0x40(%r11),%ymm2

// Load 4 elements of C into %ymm2

vmovapd 0x60(%r11),%ymm1

// Load 4 elements of C into %ymm1

vbroadcastsd (%rcx,%r9,1),%ymm0

// Make 4 copies of B element

add    $0x8,%rcx

// register %rcx = %rcx + 8

vmulpd (%rax),%ymm0,%ymm5

// Parallel mul %ymm1,4 A

vaddpd %ymm5,%ymm4,%ymm4

// Parallel add %ymm5, %y

mm4

vmulpd 0x20(%rax),%ymm0,%ymm5 // Parallel mul %ymm1,4 A

vaddpd %ymm5,%ymm3,%ymm3

// Parallel add %ymm5, %ymm3

vmulpd 0x40(%rax),%ymm0,%ymm5 // Parallel mul %ymm1,4 A

vmulpd 0x60(%rax),%ymm0,%ymm0 // Parallel mul %ymm1,4 A

add    %r8,%rax

cmp    %r10,%rcx

// register %rax = %rax + %r8

// compare %r8 to %rax

vaddpd %ymm5,%ymm2,%ymm2

// Parallel add %ymm5, %ymm2

vaddpd %ymm0,%ymm1,%ymm1

// Parallel add %ymm0, %ymm1

jne    68 <dgemm+0x68>

// branch if %r8 !=   %rax

add    $0x1,%esi

// register % esi = % esi + 1

vmovapd %ymm4,(%r11)

// Store %ymm4 into 4 C elements

vmovapd %ymm3,0x20(%r11)

// Store %ymm3 into 4 C elements

vmovapd %ymm2,0x40(%r11)

// Store %ymm2 into 4 C elements

vmovapd %ymm1,0x60(%r11)

// Store %ymm1 into 4 C elements

FIGURE 4.78  The x86 assembly language for the body of the nested loops generated by compiling the unrolled C code
in Figure 4.77.

344

Chapter 4  The Processor

14.6

S
P
O
L
F
G

16.0

12.0

8.0

4.0

–

6.4

1.7

unoptimized

AVX

AVX+unroll

FIGURE  4.79  Performance  of  three  versions  of  DGEMM  for  32  ×  32  matrices.  Subword
parallelism and instruction-level parallelism have led to speedup of almost a factor of 9 over the unoptimized
code in Figure 3.21.

Figure  4.79  shows  the  performance  increase  DGEMM  for  32  ×  32  matrices
in  going  from  unoptimized  to  AVX  and  then  to  AVX  with  unrolling.  Unrolling
more  than  doubles  performance,  going  from  6.4  GFLOPS  to  14.6  GFLOPS.
Optimizations for subword parallelism and instruction-level parallelism result
in an overall speedup of 8.59 versus the unoptimized DGEMM in Figure 3.21.

Elaboration:  As mentioned in the Elaboration in Section 3.8, these results are with
Turbo mode turned off. If we turn it on, like in Chapter 3, we improve all the results by the
temporary increase in the clock rate of 3.3/2.6 = 1.27 to 2.1 GFLOPS for unoptimized
DGEMM, 8.1 GFLOPS with AVX, and 18.6 GFLOPS with unrolling and AVX. As mentioned
in Section 3.8, Turbo mode works particularly well in this case because it is using only
a single core of an eight-core chip.

Elaboration:  There are no pipeline stalls despite the reuse of register %ymm5 in lines
9 to 17 of Figure 4.78 because the Intel Core i7 pipeline renames the registers.

Are the following statements true or false?

1.  The  Intel  Core  i7  uses  a  multiple-issue  pipeline  to  directly  execute  x86

instructions.

2.  Both the Cortex-A53 and the Core i7 use dynamic multiple issue.

3.  The Core i7 microarchitecture has many more registers than x86 requires.

4.  The Intel Core i7 uses less than half the pipeline stages of the earlier Intel

Pentium 4 Prescott (see Figure 4.70).

Check
Yourself

4.14  Fallacies and Pitfalls

345

4.13

   Advanced Topic: An Introduction to Digital
Design Using a Hardware Design Language
to Describe and Model a Pipeline and
More Pipelining Illustrations

Modern digital design is done using hardware description languages and modern
computer-aided synthesis tools that can create detailed hardware designs from the
descriptions using both libraries and logic synthesis. Entire books are written on
such languages and their use in digital design. This section, which appears online,
gives  a  brief  introduction  and  shows  how  a  hardware  design  language,  Verilog
in this case, can be used to describe the processor control both behaviorally and
in a form suitable for hardware synthesis. It then provides a series of behavioral
models in Verilog of the five-stage pipeline. The initial model ignores hazards, and
additions  to  the  model  highlight  the  changes  for  forwarding,  data  hazards,  and
branch hazards.

We  then  provide  about  a  dozen  illustrations  using  the  single-cycle  graphical
pipeline representation for readers who want to see more detail on how pipelines
work for a few sequences of RISC-V instructions.

 4.14  Fallacies and Pitfalls

Fallacy:  Pipelining is easy.

Our books testify to the subtlety of correct pipeline execution. Our advanced
book had a pipeline bug in its first edition, despite its being reviewed by more than
100 people and being class-tested at 18 universities. The bug was uncovered only
when someone tried to build the computer in that book. The fact that the Verilog
to describe a pipeline like that in the Intel Core i7 will be hundreds of thousands of
lines is an indication of the complexity. Beware!

Fallacy:  Pipelining ideas can be implemented independent of technology.

When the number of transistors on-chip and the speed of transistors made a
five-stage pipeline the best solution, then the delayed branch (see the Elaboration
on  page  274)  was  a  simple  solution  to  control  hazards.  With  longer  pipelines,
superscalar  execution,  and  dynamic  branch  prediction,  it  is  now  redundant.  In
the  early  1990s,  dynamic  pipeline  scheduling  took  too  many  resources  and  was
not required for high performance, but as transistor budgets continued to double
due  to  Moore’s Law  and  logic  became  much  faster  than  memory,  then  multiple
functional units and dynamic pipelining made more sense. Today, concerns about
power are leading to less aggressive and more efficient designs.

Pitfall:  Failure to consider instruction set design can adversely impact pipelining.

 4.13  Advanced Topic: An Introduction to Digital Design Using a Hardware Design Language

345.e1

4.13

Advanced Topic: An Introduction to
Digital Design Using a Hardware Design
Language to Describe and Model a
Pipeline and More Pipelining Illustrations

This online section covers hardware description languages and then gives a dozen
examples of pipeline diagrams, starting on page 366.e18.

As mentioned in Appendix A, Verilog can describe processors for simulation
or  with  the  intention  that  the  Verilog  specification  be  synthesized.  To  achieve
acceptable  synthesis  results  in  size  and  speed,  and  a  behavioral  specification
intended for synthesis must carefully delineate the highly combinational portions
of  the  design,  such  as  a  datapath,  from  the  control.  The  datapath  can  then  be
synthesized using available libraries. A Verilog specification intended for synthesis
is usually longer and more complex.

We  start  with  a  behavioral  model  of  the  five-stage  pipeline.  To  illustrate  the
dichotomy between behavioral and synthesizable designs, we then give two Verilog
descriptions of a multiple-cycle-per-instruction RISC-V processor: one intended
solely for simulations and one suitable for synthesis.

Using Verilog for Behavioral Specification with Simulation
for the Five-Stage Pipeline

Figure e4.13.1 shows a Verilog behavioral description of the pipeline that handles
ALU instructions as well as loads and stores. It does not accommodate branches
(even incorrectly!), which we postpone including until later in the chapter.

Because Verilog lacks the ability to define registers with named fields such as
structures in C, we use several independent registers for each pipeline register. We
name these registers with a prefix using the same convention; hence, IFIDIR is the
IR portion of the IFID pipeline register.

This version is a behavioral description not intended for synthesis. Instructions
take  the  same  number  of  clock  cycles  as  our  hardware  design,  but  the  control
is  done  in  a  simpler  fashion  by  repeatedly  decoding  fields  of  the  instruction  in
each pipe stage. Because of this difference, the instruction register (IR) is needed
throughout the pipeline, and the entire IR is passed from pipe stage to pipe stage.
As  you  read  the  Verilog  descriptions  in  this  chapter,  remember  that  the  actions
in the always block all occur in parallel on every clock cycle. Since there are no
blocking assignments, the order of the events within the always block is arbitrary.

345.e2

4.13  Advanced Topic: An Introduction to Digital Design Using a Hardware Design Language

module RISCVCPU (clock);
// Instruction opcodes
parameter LD = 7'b000_0011, SD = 7'b010_0011, BEQ = 7'b110_0011, NOP =

32'h0000_0013, ALUop = 7'b001_0011;

input clock;

reg [63:0] PC, Regs[0:31], IDEXA, IDEXB, EXMEMB, EXMEMALUOut,

MEMWBValue;

reg [31:0] IMemory[0:1023], DMemory[0:1023], // separate memories

IFIDIR, IDEXIR, EXMEMIR, MEMWBIR; // pipeline registers

wire [4:0] IFIDrs1, IFIDrs2, MEMWBrd; // Access register fields
wire [6:0] IDEXop, EXMEMop, MEMWBop; // Access opcodes
wire [63:0] Ain, Bin; // the ALU inputs

// These assignments define fields from the pipeline registers
assign IFIDrs1  = IFIDIR[19:15];  // rs1 field
assign IFIDrs2  = IFIDIR[24:20];  // rs2 field
assign IDEXop   = IDEXIR[6:0];    // the opcode
assign EXMEMop  = EXMEMIR[6:0];   // the opcode
assign MEMWBop  = MEMWBIR[6:0];   // the opcode
assign MEMWBrd  = MEMWBIR[11:7];  // rd field
// Inputs to the ALU come directly from the ID/EX pipeline registers
assign Ain = IDEXA;
assign Bin = IDEXB;

integer i; // used to initialize registers
initial
begin

PC = 0;
IFIDIR = NOP; IDEXIR = NOP; EXMEMIR = NOP; MEMWBIR = NOP; // put NOPs

in pipeline registers

for (i=0;i<=31;i=i+1) Regs[i] = i; // initialize registers--just so

they aren't cares

end

// Remember that ALL these actions happen every pipe stage and with the

use of <= they happen in parallel!

always @(posedge clock)
begin

// first instruction in the pipeline is being fetched
// Fetch & increment PC
IFIDIR <= IMemory[PC >> 2];
PC <= PC + 4;

// second instruction in pipeline is fetching registers
IDEXA <= Regs[IFIDrs1]; IDEXB <= Regs[IFIDrs2]; // get two registers
IDEXIR <= IFIDIR; // pass along IR--can happen anywhere, since this

affects next stage only!

// third instruction is doing address calculation or ALU operation
if (IDEXop == LD)

EXMEMALUOut <= IDEXA + {{53{IDEXIR[31]}}, IDEXIR[30:20]};

else if (IDEXop == SD)

EXMEMALUOut <= IDEXA + {{53{IDEXIR[31]}}, IDEXIR [30:25],

IDEXIR[11:7]};

else if (IDEXop == ALUop)

case (IDEXIR[31:25]) // case for the various R-type instructions

0: EXMEMALUOut <= Ain + Bin;  // add operation

FIGURE e4.13.1  A Verilog behavioral model for the RISC-V five-stage pipeline, ignoring
branch and data hazards. As in the design earlier in Chapter 4, we use separate instruction and data
memories, which would be implemented using separate caches as we describe in Chapter 5.

 4.13  Advanced Topic: An Introduction to Digital Design Using a Hardware Design Language

345.e3

default: ; // other R-type operations: subtract, SLT, etc.

endcase

EXMEMIR <= IDEXIR; EXMEMB <= IDEXB; // pass along the IR & B register

// Mem stage of pipeline
if (EXMEMop == ALUop) MEMWBValue <= EXMEMALUOut; // pass along ALU

result

else if (EXMEMop == LD) MEMWBValue <= DMemory[EXMEMALUOut >> 2];
else if (EXMEMop == SD) DMemory[EXMEMALUOut >> 2] <= EXMEMB; //store
MEMWBIR <= EXMEMIR; // pass along IR

// WB stage
if (((MEMWBop == LD) || (MEMWBop == ALUop)) && (MEMWBrd != 0)) //

update registers if load/ALU operation and destination not 0

Regs[MEMWBrd] <= MEMWBValue;

end

endmodule

FIGURE e4.13.1  A Verilog behavioral model for the RISC-V five-stage pipeline, ignoring
branch and data hazards. (Continued)

Implementing Forwarding in Verilog

To extend the Verilog model further, Figure e4.13.2 shows the addition of forwarding
logic for the case when the source and destination are ALU instructions. Neither
load stalls nor branches are handled; we will add these shortly. The changes from
the earlier Verilog description are highlighted.

Someone  has  proposed  moving  the  write  for  a  result  from  an  ALU  instruction
from the WB to the MEM stage, pointing out that this would reduce the maximum
length of forwards from an ALU instruction by one cycle. Which of the following
is accurate reasons not to consider such a change?

Check
Yourself

1.  It would not actually change the forwarding logic, so it has no advantage.

2.  It is impossible to implement this change under any circumstance since the
write for the ALU result must stay in the same pipe stage as the write for a
load result.

3.  Moving the write for ALU instructions would create the possibility of writes
occurring from two different instructions during the same clock cycle. Either
an  extra  write  port  would  be  required  on  the  register  file  or  a  structural
hazard would be created.

4.  The  result  of  an  ALU  instruction  is  not  available  in  time  to  do  the  write

during MEM.

The Behavioral Verilog with Stall Detection

If we ignore branches, stalls for data hazards in the RISC-V pipeline are confined
to one simple case: loads whose results are currently in the WB clock stage. Thus,
extending  the  Verilog  to  handle  a  load  with  a  destination  that  is  either  an  ALU
instruction or an effective address calculation is reasonably straightforward, and
Figure e4.13.3 shows the few additions needed.

345.e4

4.13  Advanced Topic: An Introduction to Digital Design Using a Hardware Design Language

module RISCVCPU (clock);
// Instruction opcodes
parameter LD = 7'b000_0011, SD = 7'b010_0011, BEQ = 7'b110_0011, NOP =

32'h0000_0013, ALUop = 7'b001_0011;

input clock;

reg [63:0] PC, Regs[0:31], IDEXA, IDEXB, EXMEMB, EXMEMALUOut,

MEMWBValue;

reg [31:0] IMemory[0:1023], DMemory[0:1023], // separate memories

IFIDIR, IDEXIR, EXMEMIR, MEMWBIR; // pipeline registers

wire [4:0] IFIDrs1, IFIDrs2, IDEXrs1, IDEXrs2, EXMEMrd, MEMWBrd; //

Access register fields

wire [6:0] IDEXop, EXMEMop, MEMWBop; // Access opcodes
wire [63:0] Ain, Bin; // the ALU inputs
// declare the bypass signals
wire bypassAfromMEM, bypassAfromALUinWB,
bypassBfromMEM, bypassBfromALUinWB,
bypassAfromLDinWB, bypassBfromLDinWB;

assign IFIDrs1  = IFIDIR[19:15];
assign IFIDrs2  = IFIDIR[24:20];
assign IDEXop   = IDEXIR[6:0];
assign IDEXrs1  = IDEXIR[19:15];
assign IDEXrs2  = IDEXIR[24:20];
assign EXMEMop  = EXMEMIR[6:0];
assign EXMEMrd  = EXMEMIR[11:7];
assign MEMWBop  = MEMWBIR[6:0];
assign MEMWBrd  = MEMWBIR[11:7];

// The bypass to input A from the MEM stage for an ALU operation
assign bypassAfromMEM = (IDEXrs1 == EXMEMrd) && (IDEXrs1 != 0) &&

(EXMEMop == ALUop);

// The bypass to input B from the MEM stage for an ALU operation
assign bypassBfromMEM = (IDEXrs2 == EXMEMrd) && (IDEXrs2 != 0) &&

(EXMEMop == ALUop);

// The bypass to input A from the WB stage for an ALU operation
assign bypassAfromALUinWB = (IDEXrs1 == MEMWBrd) && (IDEXrs1 != 0) &&

(MEMWBop == ALUop);

// The bypass to input B from the WB stage for an ALU operation
assign bypassBfromALUinWB = (IDEXrs2 == MEMWBrd) && (IDEXrs2 != 0) &&

(MEMWBop == ALUop);

// The bypass to input A from the WB stage for an LD operation
assign bypassAfromLDinWB = (IDEXrs1 == MEMWBrd) && (IDEXrs1 != 0) &&

(MEMWBop == LD);

// The bypass to input B from the WB stage for an LD operation
assign bypassBfromLDinWB = (IDEXrs2 == MEMWBrd) && (IDEXrs2 != 0) &&

(MEMWBop == LD);

// The A input to the ALU is bypassed from MEM if there is a bypass

there,

// Otherwise from WB if there is a bypass there, and otherwise comes

from the IDEX register

assign Ain = bypassAfromMEM ? EXMEMALUOut :

(bypassAfromALUinWB || bypassAfromLDinWB) ? MEMWBValue :

IDEXA;

// The B input to the ALU is bypassed from MEM if there is a bypass

there,

// Otherwise from WB if there is a bypass there, and otherwise comes

from the IDEX register

FIGURE  e4.13.2  A  behavioral  definition  of  the  five-stage  RISC-V  pipeline  with  bypassing
to ALU operations and address calculations. The code added to Figure e4.13.1 to handle bypassing is
highlighted. Because these bypasses only require changing where the ALU inputs come from, the only changes
required are in the combinational logic responsible for selecting the ALU inputs. (continues on next page)

 4.13  Advanced Topic: An Introduction to Digital Design Using a Hardware Design Language

345.e5

assign Bin = bypassBfromMEM ? EXMEMALUOut :

(bypassBfromALUinWB || bypassBfromLDinWB) ? MEMWBValue:

IDEXB;

integer i; // used to initialize registers
initial
begin

PC = 0;
IFIDIR = NOP; IDEXIR = NOP; EXMEMIR = NOP; MEMWBIR = NOP; // put NOPs

in pipeline registers

for (i=0;i<=31;i=i+1) Regs[i] = i; // initialize registers--just so

they aren't cares

end

// Remember that ALL these actions happen every pipe stage and with the

use of <= they happen in parallel!

always @(posedge clock)
begin

// first instruction in the pipeline is being fetched
// Fetch & increment PC
IFIDIR <= IMemory[PC >> 2];
PC <= PC + 4;

// second instruction in pipeline is fetching registers
IDEXA <= Regs[IFIDrs1]; IDEXB <= Regs[IFIDrs2]; // get two registers
IDEXIR <= IFIDIR; // pass along IR--can happen anywhere, since this

affects next stage only!

// third instruction is doing address calculation or ALU operation
if (IDEXop == LD)

EXMEMALUOut <= IDEXA + {{53{IDEXIR[31]}}, IDEXIR[30:20]};

else if (IDEXop == SD)

EXMEMALUOut <= IDEXA + {{53{IDEXIR[31]}}, IDEXIR[30:25],

IDEXIR[11:7]};

else if (IDEXop == ALUop)

case (IDEXIR[31:25]) // case for the various R-type instructions

0: EXMEMALUOut <= Ain + Bin;  // add operation
default: ; // other R-type operations: subtract, SLT, etc.

endcase

EXMEMIR <= IDEXIR; EXMEMB <= IDEXB; // pass along the IR & B register

// Mem stage of pipeline
if (EXMEMop == ALUop) MEMWBValue <= EXMEMALUOut; // pass along ALU

result

else if (EXMEMop == LD) MEMWBValue <= DMemory[EXMEMALUOut >> 2];
else if (EXMEMop == SD) DMemory[EXMEMALUOut >> 2] <= EXMEMB; //store
MEMWBIR <= EXMEMIR; // pass along IR

// WB stage
if (((MEMWBop == LD) || (MEMWBop == ALUop)) && (MEMWBrd != 0)) //

update registers if load/ALU operation and destination not 0

Regs[MEMWBrd] <= MEMWBValue;

end

endmodule

FIGURE e4.13.2  A behavioral definition of the five-stage RISC-V pipeline with bypassing
to ALU operations and address calculations. (Continued)

module RISCVCPU (clock);
// Instruction opcodes
parameter LD = 7'b000_0011, SD = 7'b010_0011, BEQ = 7'b110_0011, NOP =

32'h0000_0013, ALUop = 7'b001_0011;

input clock;

reg [63:0] PC, Regs[0:31], IDEXA, IDEXB, EXMEMB, EXMEMALUOut,

MEMWBValue;

reg [31:0] IMemory[0:1023], DMemory[0:1023], // separate memories

IFIDIR, IDEXIR, EXMEMIR, MEMWBIR; // pipeline registers

wire [4:0] IFIDrs1, IFIDrs2, IDEXrs1, IDEXrs2, EXMEMrd, MEMWBrd; //

Access register fields

wire [6:0] IDEXop, EXMEMop, M EMWBop; // Access opcodes
wire [63:0] Ain, Bin; // the ALU inputs
// declare the bypass signals
wire bypassAfromMEM, bypassAfromALUinWB,
bypassBfromMEM, bypassBfromALUinWB,
bypassAfromLDinWB, bypassBfromLDinWB;

wire stall; // stall signal

assign IFIDrs1  = IFIDIR[19:15];
assign IFIDrs2  = IFIDIR[24:20];
assign IDEXop   = IDEXIR[6:0];
assign IDEXrs1  = IDEXIR[19:15];
assign IDEXrs2  = IDEXIR[24:20];
assign EXMEMop  = EXMEMIR[6:0];
assign EXMEMrd  = EXMEMIR[11:7];
assign MEMWBop  = MEMWBIR[6:0];
assign MEMWBrd  = MEMWBIR[11:7];

// The bypass to input A from the MEM stage for an ALU operation
assign bypassAfromMEM = (IDEXrs1 == EXMEMrd) && (IDEXrs1 != 0) &&

(EXMEMop == ALUop);

// The bypass to input B from the MEM stage for an ALU operation
assign bypassBfromMEM = (IDEXrs2 == EXMEMrd) && (IDEXrs2 != 0) &&

(EXMEMop == ALUop);

// The bypass to input A from the WB stage for an ALU operation
assign bypassAfromALUinWB = (IDEXrs1 == MEMWBrd) && (IDEXrs1 != 0) &&

(MEMWBop == ALUop);

// The bypass to input B from the WB stage for an ALU operation
assign bypassBfromALUinWB = (IDEXrs2 == MEMWBrd) && (IDEXrs2 != 0) &&

(MEMWBop == ALUop);

// The bypass to input A from the WB stage for an LD operation
assign bypass AfromLDinWB = (IDEXrs1 == MEMWBrd) && (IDEXrs1 != 0) &&

(MEMWBop == LD);

// The bypass to input B from the WB stage for an LD operation
assign bypassBfromLDinWB = (IDEXrs2 == MEMWBrd) && (IDEXrs2 != 0) &&

(MEMWBop == LD);

// The A input to the ALU is bypassed from MEM if there is a bypass

there,

// Otherwise from WB if there is a bypass there, and otherwise comes

from the IDEX register

assign Ain = bypassAfromMEM ? EXMEMALUOut :

(bypassAfromALUinWB || bypassAfromLDinWB) ? MEMWBValue :

IDEXA;

// The B input to the ALU is bypassed from MEM if there is a bypass

there,

// Otherwise from WB if there is a bypass there, and otherwise comes

from the IDEX register

assign Bin = bypassBfromMEM ? EXMEMALUOut :

(bypassBfromAL UinWB || bypassBfromLDinWB) ? MEMWBValue:

IDEXB;

FIGURE e4.13.3  A behavioral definition of the five-stage RISC-V pipeline with stalls for
loads  when  the  destination  is  an  ALU  instruction  or  effective  address  calculation.  The
changes from Figure e4.13.2 are highlighted. (continues on next page)

// The signal for detecting a stall based on the use of a result from

LW

assign stall = (MEMWBop == LD) && ( // source instruction is a load
(((IDEXop == LD) || (IDEXop == SD)) && (IDEXrs1 ==

MEMWBrd)) || // stall for address calc

((IDEXop == ALUop) && ((IDEXrs1 == MEMWBrd) ||

(IDEXrs2 == MEMWBrd)))); // ALU use

integer i; // used to initialize registers
initial
begin

PC = 0;
IFIDIR = NOP; IDEXIR = NOP; EXMEMIR = NOP; MEMWBIR = NOP; // put NOPs

in pipeline registers

for (i=0;i<=31;i=i+1) Regs[i] = i; // initialize registers--just so

they aren't cares

end

// Remember that ALL these actions happen every pipe stage and with the

use of <= they happen in parallel!

always @(posedge clock)
begin

if (~stall)
begin // the first three pipeline stages stall if there is a load

hazard

// first instruction in the pipeline is being fetched
// Fetch & increment PC
IFIDIR <= IMemory[PC >> 2];
PC <= PC + 4;

// second instruction in pipeline is fetching registers
IDEXA <= Regs[IFIDrs1]; IDEXB <= Regs[IFIDrs2]; // get two

registers

IDEXIR <= IFIDIR; // pass along IR--can happen anywhere, since this

affects next stage only!

// third instruction is doing address calculation or ALU operation
if (IDEXop == LD)

EXMEMALUOut <= IDEXA + {{53{IDEXIR[31]}}, IDEXIR[30:20]};

else if (IDEXop == SD)

EXMEMALUOut <= IDEXA + {{53{IDEXIR[31]}}, IDEXIR[30:25],

IDEXIR[11:7]};

else if (IDEXop == ALUop)

case (IDEXIR[31:25]) // case for the various R-type instructions

0: EXMEMALUOut <= Ain + Bin;  // add operation
default: ; // other R-type operations: subtract, SLT, etc.

endcase

EXMEMIR <= IDEXIR; EXMEMB <= IDEXB; // pass along the IR & B

register

end
else EXMEMIR <= NOP; // Freeze first three stages of pipeline; inject

a nop into the EX output

// Mem stage of pipeline

if (EXMEMop == ALUop) MEMWBValue <= EXMEMALUOut; // pass along ALU

result

else if (EXMEMop == LD) MEMWBValue <= DMemory[EXMEMALUOut >> 2];
else if (EXMEMop == SD) DMemory[EXMEMALUOut >> 2] <= EXMEMB; //store
MEMWBIR <= EXMEMIR; // pass along IR

// WB stage
if (((MEMWBop == LD) || (MEMWBop == ALUop)) && (MEMWBrd != 0)) //

update registers if load/ALU operation and destination not 0

Regs[MEMWBrd] <= MEMWBValue;

end

endmodule

FIGURE  e4.13.3  A  behavioral  definition  of  the  five-stage  RISC-V  pipeline  with  stalls
for  loads  when  the  destination  is  an  ALU  instruction  or  effective  address  calculation.
(Continued)

345.e8

4.13  Advanced Topic: An Introduction to Digital Design Using a Hardware Design Language

Check
Yourself

Someone  has  asked  about  the  possibility  of  data  hazards  occurring  through
memory, contrary to through a register. Which of the following statements about
such hazards is true?

1.  Since memory accesses only occur in the MEM stage, all memory operations
are done in the same order as instruction execution, making such hazards
impossible in this pipeline.

2.  Such hazards are possible in this pipeline; we just have not discussed them yet.
3.  No  pipeline  can  ever  have  a  hazard  involving  memory,  since  it  is  the

programmer’s job to keep the order of memory references accurate.

4.  Memory hazards may be possible in some pipelines, but they cannot occur

in this particular pipeline.

5.  Although  the  pipeline  control  would  be  obligated  to  maintain  ordering
among  memory  references  to  avoid  hazards,  it  is  impossible  to  design  a
pipeline where the references could be out of order.

Implementing the Branch Hazard Logic in Verilog

We can extend our Verilog behavioral model to implement the control for branches.
We  add  the  code  to  model  branch  equal  using  a  “predict  not  taken”  strategy.
The Verilog code is shown in Figure e4.13.4. It implements the branch hazard by
detecting a taken branch in ID and using that signal to squash the instruction in IF
(by setting the IR to 0x00000013, which is an effective NOP in RISC-V); in addition,
the PC is assigned to the branch target. Note that to prevent an unexpected latch, it
is important that the PC is clearly assigned on every path through the always block;
hence, we assign the PC in a single if statement. Lastly, note that although Figure
e4.13.4 incorporates the basic logic for branches and control hazards, supporting
branches requires additional bypassing and data hazard detection, which we have
not included.

Using Verilog for Behavioral Specification with Synthesis

To  demonstrate  the  contrasting  types  of  Verilog,  we  show  two  descriptions  of  a
different, nonpipelined implementation style of RISC-V that uses multiple clock
cycles  per  instruction.  (Since  some  instructors  make  a  synthesizable  description
of the RISC-V pipeline project for a class, we chose not to include it here. It would
also be long.)

Figure e4.13.5 gives a behavioral specification of a multicycle implementation
of the RISC-V processor. Because of the use of behavioral operations, it would be
difficult  to  synthesize  a  separate  datapath  and  control  unit  with  any  reasonable
efficiency. This version demonstrates another approach to the control by using a
Mealy  finite-state  machine  (see  discussion  in  Section  A.10  of  Appendix  A). The
use of a Mealy machine, which allows the output to depend both on inputs and the
current state, allows us to decrease the total number of states.

module RISCVCPU (clock);
// Instruction opcodes
parameter LD = 7'b000_0011, SD = 7'b010_0011, BEQ = 7'b110_0011, NOP =

32'h0000_0013, ALUop = 7'b001_0011;

input clock;

reg [63:0] PC, Regs[0:31], IDEXA, IDEXB, EXMEMB, EXMEMALUOut,

MEMWBValue;

reg [31:0] IMemory[0:1023], DMemory[0:1023], // separate memories

IFIDIR, IDEXIR, EXMEMIR, MEMWBIR; // pipeline registers

wire [4:0] IFIDrs1, IFIDrs2, IDEXrs1, IDEXrs2, EXMEMrd, MEMWBrd; //

Access register fields

wire [6:0] IFIDop, IDEXop, EXMEMop, MEMWBop; // Access opcodes
wire [63:0] Ain, Bin; // the ALU inputs
// declare the bypass signals
wire bypassAfromMEM, bypassAfromALUinWB,
bypassBfromMEM, bypassBfromALUinWB,
bypassAfromLDinWB, bypassBfromLDinWB;

wire stall; // stall signal
wire takebranch;

assign IFIDop   = IFIDIR[6:0];
assign IFIDrs1  = IFIDIR[19:15];
assign IFIDrs2  = IFIDIR[24:20];
assign IDEXop   = IDEXIR[6:0];
assign IDEXrs1  = IDEXIR[19:15];
assign IDEXrs2  = IDEXIR[24:20];
assign EXMEMop  = EXMEMIR[6:0];
assign EXMEMrd  = EXMEMIR[11:7];
assign MEMWBop  = MEMWBIR[6:0];
assign MEMWBrd  = MEMWBIR[11:7];

// The bypass to input A from the MEM stage for an ALU operation
assign bypassAfromMEM = (IDEXrs1 == EXMEMrd) && (IDEXrs1 != 0) &&

(EXMEMop == ALUop);

// The bypass to input B from the MEM stage for an ALU operation
assign bypassBfromMEM = (IDEXrs2 == EXMEMrd) && (IDEXrs2 != 0) &&

(EXMEMop == ALUop);

// The bypass to input A from the WB stage for an ALU operation
assign bypas sAfromALUinWB = (IDEXrs1 == MEMWBrd) && (IDEXrs1 != 0) &&

(MEMWBop == ALUop);

// The bypass to input B from the WB stage for an ALU operation
assign bypassBfromALUinWB = (IDEXrs2 == MEMWBrd) && (IDEXrs2 != 0) &&

(MEMWBop == ALUop);

// The bypass to input A from the WB stage for an LD operation
assign bypassAfromLDinWB = (IDEXrs1 == MEMWBrd) && (IDEXrs1 != 0) &&

(MEMWBop == LD);

// The bypass to input B from the WB stage for an LD operation
assign bypassBfromLDinWB = (IDEXrs2 == MEMWBrd) && (IDEX rs2 != 0) &&

(MEMWBop == LD);

// The A input to the ALU is bypassed from MEM if there is a bypass

there,

// Otherwise from WB if there is a bypass there, and otherwise comes

from the IDEX register

assign Ain = bypassAfromMEM ? EXMEMALUOut :

(bypassAfromALUinWB || bypassAfromLDinWB) ? MEMWBValue :

IDEXA;

// The B input to the ALU is bypassed from MEM if there is a bypass

there,

// Otherwise from WB if there is a bypass there, and otherwise comes

from the IDEX register

assign Bin = bypassBfromMEM ? EXMEMALUOut :

(bypassBfromALUinWB || bypassBfromLDinWB) ? MEMWBValue:

FIGURE e4.13.4  A behavioral definition of the five-stage RISC-V pipeline with stalls for
loads  when  the  destination  is  an  ALU  instruction  or  effective  address  calculation.  The
changes from Figure e4.13.2 are highlighted. (continues on next page)

IDEXB;

// The signal for detecting a stall based on the use of a result from

LW

assign stall = (MEMWBop == LD) && ( // source instruction is a load

(((IDEXop == LD) || (IDEXop == SD)) && (IDEXrs1 ==

MEMWBrd)) || // stall for address calc

(IDEXrs2 == MEMWBrd)))); // ALU use

// Signal for a taken branch: instruction is BEQ and registers are

((IDEXop == ALUop) && ((IDEXrs1 == MEMWBrd) ||

equal

assign takebranch = (IFIDop == BEQ) && (Regs[IFIDrs1] ==

Regs[IFIDrs2]);

integer i; // used to initialize registers
initial
begin

PC = 0;
IFIDIR = NOP; IDEXIR = NOP; EXMEMIR = NOP; MEMWBIR = NOP; // put NOPs

in pipeline registers

for (i=0;i<=31;i=i+1) Regs[i] = i; // initialize registers--just so

they aren't cares

end

// Remember that ALL these actions happen every pipe stage and with the

use of <= they happen in parallel!

always @(posedge clock)
begin

if (~stall)
begin // the first three pipeline stages stall if there is a load

hazard

if (~takebranch)
begin // first instruction in the pipeline is being fetched

normally

IFIDIR <= IMemory[PC >> 2];
PC <= PC + 4;

end
else
begin // a taken branch is in ID; instruction in IF is wrong;

insert a NOP and reset the PC
IFIDIR <= NOP;
PC <= PC + {{52{IFIDIR[31]}}, IFIDIR[7], IFIDIR[30:25],

IFIDIR[11:8], 1'b0};

end

// second instruction in pipeline is fetching registers
IDEXA <= Regs[IFIDrs1]; IDEXB <= Regs[IFIDrs2]; // get two

registers

IDEXIR <= IFIDIR; // pass along IR--can happen anywhere, since this

affects next stage only!

// third instruction is doing addre ss calculation or ALU operation
if (IDEXop == LD)

EXMEMALUOut <= IDEXA + {{53{IDEXIR[31]}}, IDEXIR[30:20]};

else if (IDEXop == SD)

EXMEMALUOut <= IDEXA + {{53{IDEXIR[31]}}, IDEXIR[30:25],

IDEXIR[11:7]};

else if (IDEXop == ALUop)

case (IDEXIR[31:25]) // case for the various R-type instructions

0: EXMEMALUOut <= Ain + Bin;  // add operation

FIGURE  e4.13.4  A  behavioral  definition  of  the  five-stage  RISC-V  pipeline  with  stalls
for  loads  when  the  destination  is  an  ALU  instruction  or  effective  address  calculation.
(Continued)

 4.13  Advanced Topic: An Introduction to Digital Design Using a Hardware Design Language

345.e11

default: ; // other R-type operations: subtract, SLT, etc.

endcase

EXMEMIR <= IDEXIR; EXMEMB <= IDEXB; // pass along the IR & B

register

end
else EXMEMIR <= NOP; // Freeze first three stages of pipeline; inject

a nop into the EX output

// Mem stage of pipeline
if (EXMEMop == ALUop) MEMWBValue <= EXMEMALUOut; // pass along ALU

result

else if (EXMEMop == LD) MEMWBValue <= DMemory[EXMEMALUOut >> 2];
else if (EXMEMop == SD) DMemory[EXMEMALUOut >> 2] <= EXMEMB; //store
MEMWBIR <= EXMEMIR; // pass along IR

// WB stage
if (((MEMWBop == LD) || (MEMWBop == ALUop)) && (MEM WBrd != 0)) //

update registers if load/ALU operation and destination not 0

Regs[MEMWBrd] <= MEMWBValue;

end

endmodule

FIGURE  e4.13.4  A  behavioral  definition  of  the  five-stage  RISC-V  pipeline  with  stalls
for  loads  when  the  destination  is  an  ALU  instruction  or  effective  address  calculation.
(Continued)

Since  a  version  of  the  RISC-V  design  intended  for  synthesis  is  considerably
more complex, we have relied on a number of Verilog modules that were specified
in Appendix A, including the following:

■	 The  4-to-1  multiplexor  shown  in  Figure  A.4.2,  and  the  2-to-1  multiplexor

that can be trivially derived based on the 4-to-1 multiplexor.

■	 The RISC-V ALU shown in Figure A.5.15.

■	 The RISC-V ALU control defined in Figure A.5.16.

■	 The RISC-V register file defined in Figure A.8.11.

Now,  let’s  look  at  a  Verilog  version  of  the  RISC-V  processor  intended  for
synthesis.  Figure  e4.13.6  shows  the  structural  version  of  the  RISC-V  datapath.
Figure e4.13.7 uses the datapath module to specify the RISC-V CPU. This version
also demonstrates another approach to implementing the control unit, as well as
some  optimizations  that  rely  on  relationships  between  various  control  signals.
Observe that the state machine specification only provides the sequencing actions.
The setting of the control lines is done with a series of assign statements that
depend on the state as well as the opcode field of the instruction register. If one
were to fold the setting of the control into the state specification, this would look
like a Mealy-style finite-state control unit. Because the setting of the control lines
is  specified  using  assign  statements  outside  of  the  always  block,  most  logic
synthesis systems will generate a small implementation of a finite-state machine

345.e12

4.13  Advanced Topic: An Introduction to Digital Design Using a Hardware Design Language

module RISCVCPU (clock);

parameter LD = 7'b000_0011, SD = 7'b010_0011, BEQ = 7'b110_0011, ALUop

= 7'b001_0011;

input clock; //the clock is an external input

// The architecturally visible registers and scratch registers for

implementation

reg [63:0] PC, Regs[0:31], ALUOut, MDR, A, B;
reg [31:0] Memory [0:1023], IR;
reg [2:0] state; // processor state
wire [6:0] opcode; // use to get opcode easily
wire [63:0] ImmGen; // used to generate immediate

assign opcode = IR[6:0]; // opcode is lower 7 bits
assign ImmGen = (opcode == LD) ? {{53{IR[31]}}, IR[30:20]} :

assign PCOffset = {{52{IR[31]}}, IR[7], IR[30:25], IR[11:8], 1'b0};

/* (opcode == SD) */{{53{IR[31]}}, IR[30:25], IR[11:7]};

// set the PC to 0 and start the control in state 1
initial begin PC = 0; state = 1; end

// The state machine--triggered on a rising clock
always @(posedge clock)
begin

Regs[0] <= 0; // shortcut way to make sure R0 is always 0
case (state) //action depends on the state

1: begin // first step: fetch the instruction, increment PC, go to

next state

IR <= Memory[PC >> 2];
PC <= PC + 4;
state <= 2; // next state

end
2: begin // second step: Instruction decode, register fetch, also

compute branch address

A <= Regs[IR[19:15]];
B <= Regs[IR[24:20]];
ALUOut <= PC + PCOffset; // compute PC-relative branch target
state <= 3;

end
3: begin // third step: Load-store execution, ALU execution, Branch

completion

if ((opcode == LD) || (opcode == SD))
begin

ALUOut <= A + ImmGen; // compute effective address
state <= 4;

end
else if (opcode == ALUop)
begin

case (IR[31:25]) // case for the various R-type instructions

0: ALUOut <= A + B; // add operation
default: ; // other R-type operations: subtract, SLT, etc.

endcase
state <= 4;

end
else if (opcode == BEQ)
begin

if (A == B) begin

PC <= ALUOut; // branch taken--update PC

end

FIGURE  e4.13.5  A  behavioral  specification  of  the  multicycle  RISC-V  design.  This has the
same cycle behavior as the multicycle design, but is purely for simulation and specification. It cannot be used
for synthesis. (continues on next page)

 4.13  Advanced Topic: An Introduction to Digital Design Using a Hardware Design Language

345.e13

state <= 1;

end
else ; // other opcodes or exception for undefined instruction

would go here

end
4: begin

if (opcode == ALUop)
begin // ALU Operation

Regs[IR[11:7]] <= ALUOut; // write the result
state <= 1;

end // R-type finishes
else if (opcode == LD)
begin // load instruction

MDR <= Memory[ALUOut >> 2]; // read the memory
state <= 5; // next state

end
else if (opcode == SD)
begin // store instruction

Memory[ALUOut >> 2] <= B; // write the memory
state <= 1; // return to state 1

end
else ; // other instructions go here

end
5: begin // LD is the only instruction still in execution
Regs[IR[11:7]] <= MDR; // write the MDR to the register
state <= 1;

end // complete an LD instruction

endcase

end

endmodule

FIGURE e4.13.5  A behavioral specification of the multicycle RISC-V design. (Continued)

that  determines  the  setting  of  the  state  register  and  then  uses  external  logic  to
derive the control inputs to the datapath.

In writing this version of the control, we have also taken advantage of a number
of  insights  about  the  relationship  between  various  control  signals  as  well  as
situations  where  we  don’t  care  about  the  control  signal  value;  some  examples  of
these are given in the following elaboration.

More Illustrations of Instruction Execution on the
Hardware

To reduce the cost of this book, starting with the third edition, we moved sections
and  figures  that  were  used  by  a  minority  of  instructors  online.  This  subsection
recaptures those figures for readers who would like more supplemental material
to understand pipelining better. These are all single-clock-cycle pipeline diagrams,
which take many figures to illustrate the execution of a sequence of instructions.

The  three  examples  are  respectively  for  code  with  no  hazards,  an  example  of
forwarding on the pipelined implementation, and an example of bypassing on the
pipelined implementation.

module Datapath (ALUOp, MemtoReg, MemRead, MemWrite, IorD, RegWrite,
IRWrite,

PCWrite, PCWriteCond, ALUSrcA, ALUSrcB, PCSource,

opcode, clock); // the control inputs + clock

parameter LD = 7'b000_0011, SD = 7'b010_0011;
input [1:0] ALUOp, ALUSrcB; // 2-bit control signals
input MemtoReg, MemRead, MemWrite, IorD, RegWrite, IRWrite, PCWrite,

PCWriteCond,

ALUSrcA, PCSource, clock; // 1-bit control signals

output [6:0] opcode; // opcode is needed as an output by control
reg [63:0] PC, MDR, ALUOut; // CPU state + some temporaries
reg [31:0] Memory[0:1023], IR; // CPU state + some temporaries
wire [63:0] A, B, SignExtendOffset, PCOffset, ALUResultOut, PCValue,

JumpAddr, Writedata, ALUAin,

ALUBin, MemOut; // these are signals derived from registers

wire [3:0] ALUCtl; // the ALU control lines
wire Zero; // the Zero out signal from the ALU

initial PC = 0; //start the PC at 0
//Combinational signals used in the datapath
// Read using word address with either ALUOut or PC as the address

source

assign MemOut = MemRead ? Memory[(IorD ? ALUOut : PC) >> 2] : 0;
assign opcode = IR[6:0]; // opcode shortcut
// Get the write register data either from the ALUOut or from the MDR
assign Writedata = MemtoReg ? MDR : ALUOut;
// Generate immediate
assign ImmGen = (opcode == LD) ? {{53{IR[31]}}, IR[30:20]} :

/* (opcode == SD) */{{53{IR[31]}}, IR[30:25], IR[11:7]};

// Generate pc offset for branches
assign PCOffset = {{52{IR[31]}}, IR[7], IR[30:25], IR[11:8], 1'b0};
// The A input to the ALU is either the rs register or the PC
assign ALUAin = ALUSrcA ? A : PC; // ALU input is PC or A

// Creates an instance of the ALU control unit (see the module defined

in Figure B.5.16

// Input ALUOp is control-unit set and used to describe the

instruction class as in Chapter 4

// Input IR[31:25] is the function code field for an ALU instruction
// Output ALUCtl are the actual ALU control bits as in Chapter 4
ALUControl alucontroller (ALUOp, IR[31:25], ALUCtl); // ALU control

unit

// Creates a 2-to-1 multiplexor used to select the source of the next

PC

// Inputs are ALUResultOut (the incremented PC), ALUOut (the branch

address)

// PCSource is the selector input and PCValue is the multiplexor

output

Mult2to1 PCdatasrc (ALUResultOut, ALUOut, PCSource, PCValue);

// Creates a 4-to-1 multiplexor used to select the B input of the ALU

// Inputs are register B, constant 4, generated immediate, PC offset

// ALUSrcB is the select or input

// ALUBin is the multiplexor output
Mult4to1 ALUBinput (B, 64'd4, ImmGen, PCOffset, ALUSrcB, ALUBin);

// Creates a RISC-V ALU

// Inputs are ALUCtl (the ALU control), ALU value inputs (ALUAin,

ALUBin)

// Outputs are ALUResultOut (the 64-bit output) and Zero (zero

detection output)

RISCVALU ALU (ALUCtl, ALUAin, ALUBin, ALUResultOut, Zero); // the ALU

FIGURE e4.13.6  A Verilog version of the multicycle RISC-V datapath that is appropriate
for synthesis. This datapath relies on several units from Appendix A. Initial statements do not synthesize,
and a version used for synthesis would have to incorporate a reset signal that had this effect. Also note that
resetting R0  to  0  on  every  clock  is  not  the  best  way  to  ensure  that R0  stays  at  0;  instead,  modifying  the
register file module to produce 0 whenever R0 is read and to ignore writes to R0 would be a more efficient
solution. (continues on next page)

 4.13  Advanced Topic: An Introduction to Digital Design Using a Hardware Design Language

345.e15

// Creates a RISC-V register file

// Inputs are the rs1 and rs2 fields of the IR used to specify which

registers to read,

// Writereg (the write register number), Writedata (the data to be

written),

// RegWrite (indicates a write), the clock
// Outputs are A and B, the registers read
registerfile regs (IR[19:15], IR[24:20], IR[11:7], Writedata,

RegWrite, A, B, clock); // Register file

// The clock-triggered actions of the datapath
always @(posedge clock)
begin

if (MemWrite) Memory[ALUOut >> 2] <= B; // Write memory--must be a

store

ALUOut <= ALUResultOut; // Save the ALU result for use on a later

clock cycle

if (IRWrite) IR <= MemOut; // Write the IR if an instruction fetch
MDR <= MemOut; // Always save the memory read value
// The PC is written both conditionally (controlled by PCWrite) and

unconditionally

end

endmodule

FIGURE e4.13.6  A Verilog version of the multicycle RISC-V datapath that is appropriate
for synthesis. (Continued)

No Hazard Illustrations

On page 285, we gave the example code sequence

ld
sub
add
ld
add

x10, 40(x1)
x11, x2, x3
x12, x3, x4
x13, 48(x1)
x14, x5, x6

Figures e4.42 and e4.43 showed the multiple-clock-cycle pipeline diagrams for this
two-instruction sequence executing across six clock cycles. Figures e4.13.8 through
e4.13.10 show the corresponding single-clock-cycle pipeline diagrams for these two
instructions. Note that the order of the instructions differs between these two types of
diagrams: the newest instruction is at the bottom and to the right of the multiple-clock-
cycle pipeline diagram, and it is on the left in the single-clock-cycle pipeline diagram.

More Examples

To  understand  how  pipeline  control  works,  let’s  consider  these  five  instructions
going through the pipeline:

ld
sub
and
or
add

x10, 40(x1)
x11, x2, x3
x12, x4, x5
x13, x6, x7
x14, x8, x9

345.e16

4.13  Advanced Topic: An Introduction to Digital Design Using a Hardware Design Language

module RISCVCPU (clock);

parameter LD = 7'b000_0011, SD = 7'b010_0011, BEQ = 7'b110_0011, ALUop

= 7'b001_0011;
input clock;

reg [2:0] state;
wire [1:0] ALUOp, ALUSrcB;
wire [6:0] opcode;
wire MemtoReg, MemRead, MemWrite, IorD, RegWrite, IRWrite,

PCWrite, PCWriteCond, ALUSrcA, PCSource, MemoryOp;

// Create an instance of the RISC-V datapath, the inputs are the

control signals; opcode is only output

Datapath RISCVDP (ALUOp, MemtoReg, MemRead, MemWrite, IorD, RegWrite,

IRWrite,

opcode, clock);

PCWrite, PCWriteCond, ALUSrcA, ALUSrcB, PCSource,

initial begin state = 1; end // start the state machine in state 1
// These are the definitions of the control signals
assign MemoryOp = (opcode == LD) || (opcode == SD); // a memory

operation

assign ALUOp = ((state == 1) || (state == 2) || ((state == 3) &&

MemoryOp)) ? 2'b00 : // add

((state == 3) && (opcode == BEQ)) ? 2'b01 : 2'b10; //

subtract or use function code

assign MemtoReg = ((state == 4) && (opcode == ALUop)) ? 0 : 1;
assign MemRead = (state == 1) || ((state == 4) && (opcode == LD));
assign MemWrite = (state == 4) && (opcode == SD);
assign IorD = (state == 1) ? 0 : 1;
assign RegWrite = (state == 5) || ((state == 4) && (opcode == ALUop));
assign IRWrite = (state == 1);
assign PCWrite = (state == 1);
assign PCWriteCond = (state == 3) && (opcode == BEQ);
assign ALUSrcA = ((state == 1) || (state == 2)) ? 0 : 1;
assign ALUSrcB = ((state == 1) || ((state == 3) && (opcode == BEQ))) ?

2'b01 :

(state == 2) ? 2'b11 :
((state == 3) && MemoryOp) ? 2'b10 : 2'b00; // memory

operation or other

assign PCSource = (state == 1) ? 0 : 1;

// Here is the state machine, which only has to sequence states
always @(posedge clock)
begin // all state updates on a positive clock edge

case (state)

1: state <= 2; // unconditional next state
2: state <= 3; // unconditional next state
3: state <= (opcode == BEQ) ? 1 : 4; // branch go back else next

state

4: state <= (opcode == LD) ? 5 : 1; // R-type and SD finish
5: state <= 1; // go back

endcase

end

endmodule

FIGURE e4.13.7  The RISC-V CPU using the datapath from Figure e4.13.6.

 4.13  Advanced Topic: An Introduction to Digital Design Using a Hardware Design Language

345.e17

ld x10, 40(x1)

Instruction fetch

0
M
u
x
1

Add

4

PC

Address

Instruction
memory

n
o

i
t
c
u
r
t
s
n

I

0
M
u
x
1

Add

4

PC

Address

Instruction
memory

n
o
i
t
c
u
r
t
s
n
I

Clock 2

IF/ID

ID/EX

EX/MEM

MEM/WB

Add  Sum

Shift
left 1

ALU

Zero
ALU
result

0
M
u
x
1

Read
register 1

Read
register 2
Write
register

Read
data 1

Read
data 2

Write
data

32

Registers

64

Imm
Gen

Address

Read
data

Data
memory

Write
data

Clock 1

sub x11, x2, x3

ld x10, 40(x1)

Instruction fetch

Instruction decode

IF/ID

ID/EX

EX/MEM

MEM/WB

Add  Sum

Shift
left 1

ALU

Zero
ALU
result

0
M
u
x
1

Read
register 1

Read
register 2

Write
register

Write
data

Read
data 1

Read
data 2

Registers

32

64

Imm
Gen

Address

Read
data

Data
memory

Write
data

1
M
u
x
0

1
M
u
x
0

FIGURE e4.13.8  Single-cycle pipeline diagrams for clock cycles 1 (top diagram) and 2 (bottom diagram). This style of
pipeline representation is a snapshot of every instruction executing during one clock cycle. Our example has but two instructions, so at most
two stages are identified in each clock cycle; normally, all five stages are occupied. The highlighted portions of the datapath are active in that
clock cycle. The load is fetched in clock cycle 1 and decoded in clock cycle 2, with the subtract fetched in the second clock cycle. To make the
figures easier to understand, the other pipeline stages are empty, but normally there is an instruction in every pipeline stage.

345.e18

4.13  Advanced Topic: An Introduction to Digital Design Using a Hardware Design Language

0
M
u
x
1

Add

4

Clock 3

0
M
u
x
1

Add

4

sub x11, x2, x3

ld x10, 40(x1)

Instruction decode

Execution

IF/ID

ID/EX

EX/MEM

MEM/WB

PC

Address

Instruction
memory

n
o

i
t
c
u
r
t
s
n

I

Add Sum

Shift
left 1

ALU

Zero
ALU
result

0
M
u
x
1

Read
register 1

Read
register 2
Write
register

Write
data

32

Read
data 1

Read
data 2

Registers

64

Imm
Gen

Address

Read
data

Data
memory

Write
data

sub x11, x2, x3

ld x10, x1(40)

Execution

Memory

IF/ID

ID/EX

EX/MEM

MEM/WB

Add Sum

Shift
left 1

ALU

Zero
ALU
result

0
M
u
x
1

Read
register 1

Read
register 2

Write
register

Write
data

Read
data 1

Read
data 2

Registers

32

64

Imm
Gen

Address

Read
data

Data
memory

Write
data

PC

Address

Instruction
memory

n
o
i
t
c
u
r
t
s
n
I

Clock 4

1
M
u
x
0

1
M
u
x
0

FIGURE e4.13.9  Single-cycle pipeline diagrams for clock cycles 3 (top diagram) and 4 (bottom diagram). In the third clock
cycle in the top diagram, ld enters the EX stage. At the same time, sub enters ID. In the fourth clock cycle (bottom datapath), ld moves into
MEM stage, reading memory using the address found in EX/MEM at the beginning of clock cycle 4. At the same time, the ALU subtracts and
then places the difference into EX/MEM at the end of the clock cycle.

 4.13  Advanced Topic: An Introduction to Digital Design Using a Hardware Design Language

345.e19

sub x11, x2, x3
Memory

ld x10, 40(x1)
Write back

IF/ID

ID/EX

EX/MEM

MEM/WB

Add Sum

Shift
left 1

ALU

Zero
ALU
result

0
M
u
x
1

Read
register 1

Read
register 2
Write
register

Read
data 1

Read
data 2

Write
data

32

Registers

64

Imm
Gen

Address

Read
data

Data
memory

Write
data

1
M
u
x
0

sub x11, x2, x3
Write back

PC

Address

Instruction
memory

n
o
i
t
c
u
r
t
s
n
I

0
M
u
x
1

Add

4

Clock 5

0
M
u
x
1

Add

4

IF/ID

ID/EX

EX/MEM

MEM/WB

Add Sum

Shift
left 1

ALU

Zero
ALU
result

0
M
u
x
1

Read
register 1

Read
register 2

Write
register

Write
data

Read
data 1

Read
data 2

Registers

32

64

Imm
Gen

Address

Read
data

Data
memory

Write
data

0
M
u
x
1

PC

Address

Instruction
memory

n
o
i
t
c
u
r
t
s
n
I

Clock 6

FIGURE e4.13.10  Single-cycle pipeline diagrams for clock cycles 5 (top diagram) and 6 (bottom diagram). In clock cycle
5, ld completes by writing the data in MEM/WB into register 10, and sub sends the difference in EX/MEM to MEM/WB. In the next clock
cycle, sub writes the value in MEM/WB to register 11.

345.e20

4.13  Advanced Topic: An Introduction to Digital Design Using a Hardware Design Language

Figures e4.13.11 through e4.13.15 show these instructions proceeding through
the  nine  clock  cycles  it  takes  them  to  complete  execution,  highlighting  what  is
active in a stage and identifying the instruction associated with each stage during a
clock cycle. If you examine them carefully, you may notice:

■	 In Figure e4.13.13 you can see the sequence of the destination register numbers
from left to right at the bottom of the pipeline registers. The numbers advance
to  the  right  during  each  clock  cycle,  with  the  MEM/WB  pipeline  register
supplying the number of the register written during the WB stage.

■	 When a stage is inactive, the values of control lines that are deasserted are

shown as 0 or X (for don’t care).

■	 Sequencing of control is embedded in the pipeline structure itself. First, all
instructions  take  the  same  number  of  clock  cycles,  so  there  is  no  special
control for instruction duration. Second, all control information is computed
during instruction decode and then passed along by the pipeline registers.

Forwarding Illustrations

We  can  use  the  single-clock-cycle  pipeline  diagrams  to  show  how  forwarding
operates, as well as how the control activates the forwarding paths. Consider the
following code sequence in which the dependences have been highlighted:

sub  x2, x1, x3
and  x4, x2, x5
or   x4, x4, x2
add  x9, x4, x2

Figures e4.13.16 and e4.13.17 show the events in clock cycles 3–6 in the execution

of these instructions.

Thus, in clock cycle 5, the forwarding unit selects the EX/MEM pipeline register
for the upper input to the ALU and the MEM/WB pipeline register for the lower
input to the ALU. The following add instruction reads both register x4, the target of
the and instruction, and register x2, which the sub instruction has already written.
Notice that the prior two instructions both write register x4, so the forwarding unit
must pick the immediately preceding one (MEM stage).

In clock cycle 6, the forwarding unit thus selects the EX/MEM pipeline register,
containing the result of the or instruction, for the upper ALU input but uses the
non-forwarding register value for the lower input to the ALU.

Illustrating Pipelines with Stalls and Forwarding

We can use the single-clock-cycle pipeline diagrams to show how the control for
stalls works. Figures e4.13.18 through e4.13.20 show the single-cycle diagram for
clocks 2 through 7 for the following code sequence (dependences highlighted):

x2, 40(x1)
ld
and  x4, x2, x5
or
x4, x4, x2
add  x9, x4, x2

 4.13  Advanced Topic: An Introduction to Digital Design Using a Hardware Design Language

345.e21

IF: ld x10, 40(x1)

ID:
before<1>

EX:
before<2>

MEM:
before<3>

WB:
before<4>

IF/ID

0
M
u
x
1

Add

4

PC

Address

Instruction
memory

n
o
i
t
c
u
r
t
s
n
I

Clock 1

ID/EX

00

00

WB

000

Control

000

M

000

EX

00
0

EX/MEM

MEM/WB

00

WB

0
0
0

M

0
0

WB

e
t
i
r

W
g
e
R

Read
register 1

Read
register 2
Write
register

Write
data

Read
data 1

Read
data 2

Registers

Imm
Gen

Instruction
[31–0]

Instruction
[30, 14–12]

Instruction
[11–7]

Add Sum

ALUSrc

ALU

Zero
ALU
result

Shift
left 1

0
M
u
x
1

ALU
control

ALUOp

Branch

e
t
i
r

W
m
e
M

Address

Read
data

Data
memory

Write
data

MemRead

g
e
R
o
t
m
e
M

1
M
u
x
0

IF:
sub x11, x2, x3

ID:
ld x10, 40(x1)

EX:
before<1>

MEM:
before<2>

WB:
before<3>

IF/ID

ld

Control

11

010

001

ID/EX
00

WB

000

M

EX

00
0

EX/MEM

MEM/WB

00

WB

0
0
0

M

0
0

WB

0
M
u
x
1

Add

4

e
t
i
r

W
g
e
R

Read
register 1

Read
register 2
Write
register

Write
data

x1

X

Read
data 1

Read
data 2

Registers

Add Sum

ALUSrc

Zero

ALU

ALU
result

Shift
left 1

0
M
u
x
1

Instruction
[31–0]

Instruction
[30, 14–12]

Instruction
[11–7]

Sign-
extend

40

3

10

ALU
control

ALUOp

Branch

e
t
i
r

W
m
e
M

Address

Read
data

Data
memory

Write
data

MemRead

g
e
R
o
m
e
M

t

1
M
u
x
0

PC

Address

Instruction
memory

n
o

i
t
c
u
r
t
s
n

I

1

X

Clock 2

FIGURE e4.13.11  Clock cycles 1 and 2. The phrase “before <i>” means the ith instruction before ld. The ld instruction in the top
datapath is in the IF stage. At the end of the clock cycle, the ld instruction is in the IF/ID pipeline registers. In the second clock cycle, seen
in the bottom datapath, the ld moves to the ID stage, and sub enters in the IF stage. Note that the values of the instruction fields and the
selected source registers are shown in the ID stage. Hence, register x1 and the constant 40, the operands of ld, are written into the ID/EX
pipeline register. The number 10, representing the destination register number of ld, is also placed in ID/EX. The top of the ID/EX pipeline
register shows the control values for ld to be used in the remaining stages. These control values can be read from the ld row of the table in
Figure e4.18.

345.e22

4.13  Advanced Topic: An Introduction to Digital Design Using a Hardware Design Language

IF:
and x12, x4, x5

ID:
sub x11, x2, x3

EX:
ld x10, ...

MEM:
before<1>

WB:
before<2>

0
M
u
x
1

Add

4

IF/ID

sub

ID/EX

10

11

WB

000

Control

010

M

100

EX

00
1

EX/MEM

MEM/WB

00

WB

0
0
0

M

0
0

WB

PC

Address

Instruction
memory

n
o
i
t
c
u
r
t
s
n
I

2

3

e
t
i
r

W
g
e
R

Read
register 1
Read
register 2
Write
register
Write
data

Read
data 1

Read
data 2

x2

x3

Registers

Imm
Gen

Instruction
[31–0]

Instruction
[30, 14–12]

Instruction
[11–7]

X

8

11

Clock 3

Add Sum

ALUSrc

ALU

Zero
ALU
result

ALU
control

ALUOp

0
M
u
x
1

Shift
left 1

x1

40

3

10

Branch

e
t
i
r

W
m
e
M

Address

Read
data

Data
memory

Write
data

MemRead

g
e
R
o
t
m
e
M

1
M
u
x
0

IF: or x13, x6, x7

ID: and x12, x4, x5

EX: sub x11, ...

MEM: ld x10, ...

WB: before<1>

IF/ID

0
M
u
x
1

and

Control

10

000

100

ID/EX
10

WB

000

M

EX

10
0

EX/MEM

MEM/WB

11

WB

0
1
0

M

0
0

WB

Add

4

PC

Address

Instruction
memory

e
t
i
r

W
g
e
R

Read
register 1

Read
register 2
Write
register

n
o
i
t
c
u
r
t
s
n
I

4

5

Shift
left 1

Add Sum

ALUSrc

Zero

ALU

ALU
result

0
M
u
x
1

x4

x2

x5

x3

Read
data 1

Read
data 2

Write
data

Registers

Instruction
[31–0]

Instruction
[30, 14–12]

Instruction
[11–7]

Imm
Gen

X

7

ALU
control

8

ALUOp

12

11

10

Clock 4

Branch

e
t
i
r

W
m
e
M

Address

Read
data

Data
memory

Write
data

MemRead

g
e
R
o
t
m
e
M

1
M
u
x
0

FIGURE e4.13.12  Clock cycles 3 and 4. In the top diagram, ld enters the EX stage in the third clock cycle, adding x1 and 40 to
form the address in the EX/MEM pipeline register. (The ld instruction is written ld  x10, … upon reaching EX, because the identity of
instruction operands is not needed by EX or the subsequent stages. In this version of the pipeline, the actions of EX, MEM, and WB depend
only on the instruction and its destination register or its target address.) At the same time, sub enters ID, reading registers x2 and x3, and
the and instruction starts IF. In the fourth clock cycle (bottom datapath), ld moves into MEM stage, reading memory using the value in EX/
MEM as the address. In the same clock cycle, the ALU subtracts x3 from x2 and places the difference into EX/MEM, reads registers x4 and
x5 during ID, and the or instruction enters IF. The two diagrams show the control signals being created in the ID stage and peeled off as they
are used in subsequent pipe stages.

 4.13  Advanced Topic: An Introduction to Digital Design Using a Hardware Design Language

345.e23

IF:
add x14, x8, x9

ID:
or x13, x6, x7

EX:
and x12, ...

MEM:
sub x11, ...

WB:
ld x10, ...

0
M
u
x
1

Add

4

PC

Address

Instruction
memory

Clock 5

IF/ID

ID/EX

10

10

WB

or

000

Control

000

M

100

EX

10
0

EX/MEM

MEM/WB

10

WB

0
0
0

M

1
1

WB

n
o
i
t
c
u
r
t
s
n
I

6

7

10

e
t
i
r

W
g
e
R

Read
register 1
Read
register 2
Write
register
Write
data

x6

x7

Read
data 1

Read
data 2

Registers

Add Sum

ALUSrc

ALU

Zero
ALU
result

Shift
left 1

x4

x5

0
M
u
x
1

Instruction
[31–0]

Instruction
[30, 14–12]

Instruction
[11–7]

X

Imm
Gen

6

7

13

12

ALU
control

ALUOp

Branch

e
t
i
r

W
m
e
M

Address

Read
data

Data
memory

Write
data

MemRead

g
e
R
o
t
m
e
M

1
M
u
x
0

11

10

IF:
after<1>

ID:
add x14, x8, x9

EX:
or x13, ...

MEM:
and x12, ...

WB:
sub x11, ...

0
M
u
x
1

Add

4

PC

Address

Instruction
memory

Clock 6

IF/ID

add

Control

10

000

100

ID/EX
10

WB

000

M

EX

10
0

EX/MEM

MEM/WB

10

WB

0
0
0

M

1
0

WB

n
o
i
t
c
u
r
t
s
n
I

8

9

11

e
t
i
r

W
g
e
R

Read
register 1

Read
register 2
Write
register

Write
data

Shift
left 1

x8

x6

x9

x7

Read
data 1

Read
data 2

Registers

0
M
u
x
1

Add Sum

ALUSrc

Zero

ALU

ALU
result

Instruction
[31–0]

Instruction
[30, 14–12]

Instruction
[11–7]

Imm
Gen

X

0

ALU
control

6

ALUOp

Branch

e
t
i
r

W
m
e
M

Address

Read
data

Data
memory

Write
data

MemRead

g
e
R
o
t
m
e
M

1
M
u
x
0

14

13

21

11

FIGURE e4.13.13  Clock cycles 5 and 6. With add, the final instruction in this example, entering IF in the top datapath, all instructions
are engaged. By writing the data in MEM/WB into register 10, ld completes; both the data and the register number are in MEM/WB. In the
same clock cycle, sub sends the difference in EX/MEM to MEM/WB, and the rest of the instructions move forward. In the next clock cycle,
sub selects the value in MEM/WB to write to register number 11, again found in MEM/WB. The remaining instructions play follow-the-
leader: the ALU calculates the OR of x6 and x7 for the or instruction in the EX stage, and registers x8 and x9 are read in the ID stage for
the add instruction. The instructions after add are shown as inactive just to emphasize what occurs for the five instructions in the example.
The phrase “after <i>” means the ith instruction after add.

345.e24

4.13  Advanced Topic: An Introduction to Digital Design Using a Hardware Design Language

ID:
after<1>

IF/ID

EX:
add x14, ...

MEM:
or x13, ...

WB:
and x12, ...

ID/EX

00

10

WB

000

Control

000

M

000

EX

10
0

EX/MEM

MEM/WB

10

WB

0
0
0

M

1
0

WB

e
t
i
r

W
g
e
R

n
o
i
t
c
u
r
t
s
n
I

12

Read
register 1

Read
register 2
Write
register

Write
data

Read
data 1

Read
data 2

Registers

Imm
Gen

Instruction
[31–0]

Instruction
[30, 14–12]

Instruction
[11–7]

Add Sum

ALUSrc

ALU

Zero
ALU
result

Shift
left 1

x8

x9

0
M
u
x
1

ALU
control

ALUOp

0

14

g
e
R
o
t
m
e
M

1
M
u
x
0

Branch

e
t
i
r

W
m
e
M

Address

Read
data

Data
memory

Write
data

MemRead

13

12

ID:
after<2>

IF/ID

EX:
after<1>

MEM:
add x14, ...

WB:
or x13, ...

00

000

000

ID/EX
00

WB

000

M

EX

00
0

Control

EX/MEM

MEM/WB

10

WB

0
0
0

M

1
0

WB

IF:
after<2>

0
M
u
x
1

Add

4

PC

Address

Instruction
memory

Clock 7

IF:
after<3>

0
M
u
x
1

Add

4

e
t
i
r

W
g
e
R

Read
register 1

Read
register 2
Write
register

Write
data

Read
data 1

Read
data 2

Registers

Imm
Gen

Instruction
[31–0]

Instruction
[30, 14–12]

Instruction
[11–7]

Shift
left 1

Add Sum

ALUSrc

Zero

ALU

ALU
result

0
M
u
x
1

ALU
control

ALUOp

Branch

e
t
i
r

W
m
e
M

Address

Read
data

Data
memory

Write
data

MemRead

g
e
R
o
t
m
e
M

1
M
u
x
0

41

31

PC

Address

Instruction
memory

n
o
i
t
c
u
r
t
s
n
I

13

Clock 8

FIGURE e4.13.14  Clock cycles 7 and 8. In the top datapath, the add instruction brings up the rear,
adding the values corresponding to registers x8 and x9 during the EX stage. The result of the or instruction
is passed from EX/MEM to MEM/WB in the MEM stage, and the WB stage writes the result of the and
instruction in MEM/WB to register x12. Note that the control signals are deasserted (set to 0) in the ID
stage,  since  no  instruction  is  being  executed.  In  the  following  clock  cycle  (lower  drawing),  the  WB  stage
writes the result to register x13, thereby completing or, and the MEM stage passes the sum from the add
in EX/MEM to MEM/WB. The instructions after add are shown as inactive for pedagogical reasons.

 4.13  Advanced Topic: An Introduction to Digital Design Using a Hardware Design Language

345.e25

ID:
after<3>

IF/ID

IF:
after<4>

0
M
u
x
1

Add

4

PC

Address

Instruction
memory

n
o
i
t
c
u
r
t
s
n
I

14

Clock 9

EX:
after<2>

MEM:
after<1>

WB:
add x14, ...

00

000

000

ID/EX
00

WB

000

M

EX

00
0

Control

EX/MEM

MEM/WB

00

WB

0
0
0

M

1
0

WB

e
t
i
r

W
g
e
R

Read
register 1

Read
register 2
Write
register

Write
data

Read
data 1

Read
data 2

Registers

Imm
Gen

Instruction
[31–0]

Instruction
[30, 14–12]

Instruction
[11–7]

Add Sum

ALUSrc

Zero

ALU

ALU
result

Shift
left 1

0
M
u
x
1

ALU
control

ALUOp

Branch

e
t
i
r

W
m
e
M

Address

Read
data

Data
memory

Write
data

MemRead

g
e
R
o
t
m
e
M

1
M
u
x
0

14

FIGURE e4.13.15  Clock cycle 9. The WB stage writes the ALU result in MEM/WB into register x14, completing add and the five-
instruction sequence. The instructions after add are shown as inactive for pedagogical reasons.

345.e26

4.13  Advanced Topic: An Introduction to Digital Design Using a Hardware Design Language

or x4, x4, x2

and x4, x2, x5

sub x2, x1, x3

before<1>

before<2>

IF/ID

2

5

n
o
i
t
c
u
r
t
s
n
I

PC

Instruction
memory

Control

ID/EX

10

10

WB

M

EX

x2

x1

Registers

x5

x3

2
5

4

1
3

2

M
u
x

M
u
x

EX/MEM

WB

M

MEM/WB

WB

ALU

Data
memory

M
u
x

Forwarding
unit

Clock 3

add x9, x4, x2

or x4, x4, x2

and x4, x2, x5

sub X2, ...

before<1>

Control

ID/EX

10

10

WB

M

EX

x4

x2

Registers

x2

x5

4
2
4

2
5

4

M
u
x

M
u
x

EX/MEM

10

WB

M

MEM/WB

WB

ALU

Data
memory

M
u
x

2

Forwarding
unit

IF/ID

4

2

n
o
i
t
c
u
r
t
s
n
I

PC

Instruction
memory

Clock 4

FIGURE e4.13.16  Clock cycles 3 and 4 of the instruction sequence on page 366.e26. The bold lines are those active in a
clock cycle, and the italicized register numbers in color indicate a hazard. The forwarding unit is highlighted by shading it when it is forwarding
data to the ALU. The instructions before sub are shown as inactive just to emphasize what occurs for the four instructions in the example.
Operand names are used in EX for control of forwarding; thus they are included in the instruction label for EX. Operand names are not needed
in MEM or WB, so … is used. Compare this with Figures e4.13.12 through e4.13.15, which show the datapath without forwarding where ID is
the last stage to need operand information.

 4.13  Advanced Topic: An Introduction to Digital Design Using a Hardware Design Language

345.e27

after<1>

add x9, x4, x2

or x4, x4, x2

and x4,...

sub x2, ..

IF/ID

4

2

n
o
i
t
c
u
r
t
s
n
I

Control

Registers

2

PC

Instruction
memory

ID/EX

10

10

WB

M

EX

x4

x4

x2

x2

4
2
9

4
2
4

M
u
x

M
u
x

EX/MEM

10

WB

M

MEM/WB

1

WB

ALU

Data
memory

M
u
x

4

2

Forwarding
unit

Clock 5

after<2>

after<1>

add x9, x4, x2

or x4, ...

and x4, ..

IF/ID

n
o
i
t
c
u
r
t
s
n
I

PC

Instruction
memory

Control

Registers

4

ID/EX

10

WB

M

EX

x4

x2

4
2
9

M
u
x

M
u
x

EX/MEM

10

WB

M

MEM/WB

1

WB

ALU

Data
memory

M
u
x

4

4

Forwarding
unit

Clock 6

FIGURE e4.13.17  Clock cycles 5 and 6 of the instruction sequence on page 366.e26. The forwarding unit is highlighted when
it is forwarding data to the ALU. The two instructions after add are shown as inactive just to emphasize what occurs for the four instructions
in the example. The bold lines are those active in a clock cycle, and the italicized register numbers in color indicate a hazard.

345.e28

4.13  Advanced Topic: An Introduction to Digital Design Using a Hardware Design Language

and x4, x2, x5

ld x2, 40(x1)

before<1>

before<2>

before<3>

Hazard
detection
unit

1
X

ID/EX.MemRead

ID/EX

11

WB

M

EX

Control

0

M
u
x

e

t
i
r

W
D

I
/

F

I

IF/ID

e
t
i
r

W
C
P

PC

Instruction
memory

1

X

n
o

i
t
c
u
r
t
s
n

I

Registers

M
u
x

M
u
x

x1

XX

1

X

2

EX/MEM

WB

M

MEM/WB

WB

ALU

Data
memory

M
u
x

ID/EX.RegisterRd

Forwarding
unit

Clock 2

or x4, x4, x2

and x4, x2, x5

ld x2, 40(x1)

before<1>

before<2>

Hazard
detection
unit

2
5

e
t
i
r

W
D

I
/

F

I

IF/ID

ID/EX.MemRead

ID/EX

00

11

WB

Control

0

M
u
x

M

EX

e
t
i
r

W
C
P

PC

Instruction
memory

2

5

n
o
i
t
c
u
r
t
s
n
I

Registers

M
u
x

M
u
x

x2

x1

x5

XX

2

5
4

1

X

2

EX/MEM

WB

M

MEM/WB

WB

ALU

Data
memory

M
u
x

ID/EX.RegisterRd

Forwarding
unit

Clock 3

FIGURE e4.13.18  Clock cycles 2 and 3 of the instruction sequence on page 366.e26 with a load replacing sub. The
bold lines are those active in a clock cycle, the italicized register numbers in color indicate a hazard, and the … in the place of operands means
that their identity is information not needed by that stage. The values of the significant control lines, registers, and register numbers are labeled
in the figures. The and instruction wants to read the value created by the ld instruction in clock cycle 3, so the hazard detection unit stalls the
and and or instructions. Hence, the hazard detection unit is highlighted.

 4.13  Advanced Topic: An Introduction to Digital Design Using a Hardware Design Language

345.e29

or x4, x4, x2

and x4, x2, x5

Bubble

ld x2,...

before<1>

Hazard
detection
unit

2
5

e

t
i
r

W
D

I
/

F

I

IF/ID

e
t
i
r

W
C
P

PC

Instruction
memory

2

5

n
o

i
t
c
u
r
t
s
n

I

ID/EX.MemRead

Control

0

M
u
x

Registers

ID/EX

10

00

WB

M

EX

x2

x2

x5

x5

2

5
4

2

5

4

M
u
x

M
u
x

EX/MEM

11

WB

M

MEM/WB

WB

ALU

Data
memory

M
u
x

2

ID/EX.RegisterRd

Forwarding
unit

Clock 4

add x9, x4, x2

or x4, x4, x2

and x4, x2, x5

Bubble

ld x2,...

Hazard
detection
unit

4
2

ID/EX.MemRead

ID/EX

10

10

WB

Control

0

M
u
x

M

EX

e
t
i
r

W
D

I
/

F

I

IF/ID

EX/MEM

0

WB

M

MEM/WB

11

WB

e
t
i
r

W
C
P

PC

Instruction
memory

4

2

n
o
i
t
c
u
r
t
s
n
I

2

Registers

M
u
x

M
u
x

x4

x2

x2

x5

4

2

4

2

5

4

ALU

Data
memory

M
u
x

2

ID/EX.RegisterRd

Forwarding
unit

Clock 5

FIGURE e4.13.19  Clock cycles 4 and 5 of the instruction sequence on page 366.e26 with a load replacing sub. The
bubble is inserted in the pipeline in clock cycle 4, and then the and instruction is allowed to proceed in clock cycle 5. The forwarding unit
is highlighted in clock cycle 5 because it is forwarding data from ld to the ALU. Note that in clock cycle 4, the forwarding unit forwards the
address of the ld as if it were the contents of register x2; this is rendered harmless by the insertion of the bubble. The bold lines are those active
in a clock cycle, and the italicized register numbers in color indicate a hazard.

345.e30

4.13  Advanced Topic: An Introduction to Digital Design Using a Hardware Design Language

after<1>

add x9, x4, x2

or x4, x4, x2

and x4, ...

Bubble

Hazard
detection
unit

4
2

e

t
i
r

W
D

I
/

F

I

IF/ID

e
t
i
r

W
C
P

PC

Instruction
memory

4

2

n
o

i
t
c
u
r
t
s
n

I

ID/EX.MemRead

Control

0

M
u
x

Registers

ID/EX

10

10

WB

M

EX

x4

x4

x2

x2

4

2

9

4

2

4

EX/MEM

10

WB

M

MEM/WB

0

WB

M
u
x

M
u
x

ALU

Data
memory

M
u
x

4

ID/EX.RegisterRd

Forwarding
unit

Clock 6

after<2>

after<1>

Hazard
detection
unit

e
t
i
r

W
D

I
/

F

I

IF/ID

n
o
i
t
c
u
r
t
s
n
I

e
t
i
r

W
C
P

PC

Instruction
memory

Clock 7

add x9, x4, x2

or x4, ...

          and x4, ...

ID/EX.MemRead

ID/EX

10

10

WB

Control

0

M
u
x

M

EX

EX/MEM

10

WB

M

MEM/WB

1

WB

4

Registers

M
u
x

M
u
x

x4

x2

4

2

9

ALU

Data
memory

M
u
x

4

4

ID/EX.RegisterRd

Forwarding
unit

FIGURE e4.13.20  Clock cycles 6 and 7 of the instruction sequence on page 366.e26 with a load replacing sub. Note
that unlike in Figure e4.13.17, the stall allows the ld to complete, and so there is no forwarding from MEM/WB in clock cycle 6. Register x4
for the add in the EX stage still depends on the result from or in EX/MEM, so the forwarding unit passes the result to the ALU. The bold lines
show ALU input lines active in a clock cycle, and the italicized register numbers indicate a hazard. The instructions after add are shown as
inactive for pedagogical reasons.

346

Chapter 4  The Processor

Many  of  the  difficulties  of  pipelining  arise  because  of  instruction  set

complications. Here are some examples:

■	 Widely variable instruction lengths and running times can lead to imbalance
among pipeline stages and severely complicate hazard detection in a design
pipelined  at  the  instruction  set  level. This  problem  was  overcome,  initially
in  the  DEC  VAX  8500  in  the  late  1980s,  using  the  micro-operations  and
micropipelined scheme that the Intel Core i7 employs today. Of course, the
overhead of translation and maintaining correspondence between the micro-
operations and the actual instructions remains.

■	 Sophisticated-addressing  modes  can  lead  to  different  sorts  of  problems.
Addressing modes that update registers complicate hazard detection. Other
addressing  modes  that  require  multiple  memory  accesses  substantially
complicate pipeline control and make it difficult to keep the pipeline flowing
smoothly.

■	 Perhaps  the  best  example  is  the  DEC  Alpha  and  the  DEC  NVAX.  In
comparable technology, the newer instruction set architecture of the Alpha
allowed  an  implementation  whose  performance  is  more  than  twice  as  fast
as NVAX. In another example, Bhandarkar and Clark [1991] compared the
MIPS M/2000 and the DEC VAX 8700 by counting clock cycles of the SPEC
benchmarks; they concluded that although the MIPS M/2000 executes more
instructions, the VAX on average executes 2.7 times as many clock cycles, so
the MIPS is faster.

 4.15  Concluding Remarks

As we have seen in this chapter, both the datapath and control for a processor can
be  designed  starting  with  the  instruction  set  architecture  and  an  understanding
of  the  basic  characteristics  of  the  technology.  In  Section  4.3,  we  saw  how  the
datapath for an RISC-V processor could be constructed based on the architecture
and the decision to build a single-cycle implementation. Of course, the underlying
technology also affects many design decisions by dictating what components can
be  used  in  the  datapath,  as  well  as  whether  a  single-cycle  implementation  even
makes sense.

Pipelining  improves  throughput  but  not  the  inherent  execution  time,  or
instruction latency, of instructions; for some instructions, the latency is similar
in length to the single-cycle approach. Multiple instruction issue adds additional
datapath hardware to allow multiple instructions to begin every clock cycle, but at
an increase in effective latency. Pipelining was presented as reducing the clock cycle
time of the simple single-cycle datapath. Multiple instruction issue, in comparison,
clearly focuses on reducing clock cycles per instruction (CPI).

Nine-tenths of wisdom
consists of being wise
in time.
American proverb

instruction latency  The
inherent execution time
for an instruction.

4.17  Exercises

347

Pipelining  and  multiple  issue  both  attempt  to  exploit  instruction-level
parallelism.  The  presence  of  data  and  control  dependences,  which  can  become
hazards,  are  the  primary  limitations  on  how  much  parallelism  can  be  exploited.
Scheduling and speculation via prediction, both in hardware and in software, are
the primary techniques used to reduce the performance impact of dependences.

We  showed  that  unrolling  the  DGEMM  loop  four  times  exposed  more
instructions that could take advantage of the out-of-order execution engine of the
Core i7 to more than double performance.

The  switch  to  longer  pipelines,  multiple  instruction  issue,  and  dynamic
scheduling in the mid-1990s helped sustain the 60% per year processor performance
increase  that  started  in  the  early  1980s.  As  mentioned  in  Chapter  1,  these
microprocessors preserved the sequential programming model, but they eventually
ran into the power wall. Thus, the industry was forced to switch to multiprocessors,
which exploit parallelism at much coarser levels (the subject of Chapter 6). This
trend has also caused designers to reassess the energy-performance implications
of  some  of  the  inventions  since  the  mid-1990s,  resulting  in  a  simplification  of
pipelines in the more recent versions of microarchitectures.

To  sustain  the  advances  in  processing  performance  via  parallel  processors,
Amdahl’s law suggests that another part of the system will become the bottleneck.
That bottleneck is the topic of the next chapter: the memory hierarchy.

  4.16   Historical Perspective and Further

Reading

This  section,  which  appears  online,  discusses  the  history  of  the  first  pipelined
processors,  the  earliest  superscalars,  and  the  development  of  out-of-order  and
speculative  techniques,  as  well  as  important  developments  in  the  accompanying
compiler technology.

 4.17  Exercises

4.1  Consider the following instruction:

Instruction: and rd, rs1, rs2

Interpretation: Reg[rd] = Reg[rs1] AND Reg[rs2]

4.1.1  [5] <§4.3> What are the values of control signals generated by the control
in Figure 4.10 for this instruction?

A

A

P

P

E

N

D

I

X

I always loved that
word, Boolean.

Claude Shannon
 IEEE Spectrum, April 1992
(Shannon’s master’s thesis showed
that the algebra invented by George
Boole in the 1800s could represent the
workings of electrical switches.)

The Basics of Logic
Design

 A.1

 A.2

 A.3

 A.4

 A.5

 A.6

 A.7

Introduction  A-3
Gates, Truth Tables, and Logic

Equations  A-4
Combinational Logic  A-9
Using a Hardware Description

Language  A-20
Constructing a Basic Arithmetic Logic

Unit  A-26
Faster Addition: Carry Lookahead  A-37
Clocks  A-47

 A.8

 A.9

 A.10

 A.11

 A.12

Memory Elements: Flip-Flops, Latches, and Registers  A-49
Memory Elements: SRAMs and DRAMs  A-57
Finite-State Machines  A-66
Timing Methodologies  A-71
Field Programmable Devices  A-77

 A.13  Concluding Remarks  A-78
 A.14  Exercises  A-79

  A.1

Introduction

This appendix provides a brief discussion of the basics of logic design. It does not
replace a course in logic design, nor will it enable you to design significant working
logic  systems.  If  you  have  little  or  no  exposure  to  logic  design,  however,  this
appendix will provide sufficient background to understand all the material in this
book. In addition, if you are looking to understand some of the motivation behind
how computers are implemented, this material will serve as a useful introduction.
If your curiosity is aroused but not sated by this appendix, the references at the end
provide several additional sources of information.

Section A.2 introduces the basic building blocks of logic, namely, gates. Section
A.3  uses  these  building  blocks  to  construct  simple  combinational  logic  systems,
which  contain  no  memory.  If  you  have  had  some  exposure  to  logic  or  digital
systems, you will probably be familiar with the material in these first two sections.
Section A.5 shows how to use the concepts of Sections A.2 and A.3 to design an
ALU for the RISC-V processor. Section A.6 shows how to make a fast adder, and

A-4

Appendix A  The Basics of Logic Design

may be safely skipped if you are not interested in this topic. Section A.7 is a short
introduction to the topic of clocking, which is necessary to discuss how memory
elements work. Section A.8 introduces memory elements, and Section A.9 extends
it to focus on random access memories; it describes both the characteristics that
are important to understanding how they are used, as discussed in Chapter 4, and
the background that motivates many of the aspects of memory hierarchy design
discussed in Chapter 5. Section A.10 describes the design and use of finite-state
 Appendix C,
machines, which are sequential logic blocks. If you intend to read
you should thoroughly understand the material in Sections A.2 through A.10. If
you  intend  to  read  only  the  material  on  control  in  Chapter  4,  you  can  skim  the
appendices; however, you should have some familiarity with all the material except
Section A.11. Section A.11 is intended for those who want a deeper understanding
of clocking methodologies and timing. It explains the basics of how edge-triggered
clocking  works,  introduces  another  clocking  scheme,  and  briefly  describes  the
problem of synchronizing asynchronous inputs.

Throughout  this  appendix,  where  it  is  appropriate,  we  also  include  segments
to  demonstrate  how  logic  can  be  represented  in  Verilog,  which  we  introduce  in
Section A.4. A more extensive and complete Verilog tutorial is available online on
the Companion Web site for this book.

  A.2  Gates, Truth Tables, and Logic Equations

The electronics inside a modern computer are digital. Digital electronics operate
with only two voltage levels of interest: a high voltage and a low voltage. All other
voltage  values  are  temporary  and  occur  while  transitioning  between  the  values.
(As we discuss later in this section, a possible pitfall in digital design is sampling
a signal when it not clearly either high or low.) The fact that computers are digital
is also a key reason they use binary numbers, since a binary system matches the
underlying  abstraction  inherent  in  the  electronics.  In  various  logic  families,  the
values and relationships between the two voltage values differ. Thus, rather than
refer to the voltage levels, we talk about signals that are (logically) true, or 1, or are
asserted; or signals that are (logically) false, or 0, or are deasserted. The values 0
and 1 are called complements or inverses of one another.

Logic blocks are categorized as one of two types, depending on whether they
contain memory. Blocks without memory are called combinational; the output of
a combinational block depends only on the current input. In blocks with memory,
the outputs can depend on both the inputs and the value stored in memory, which
is  called  the  state  of  the  logic  block.  In  this  section  and  the  next,  we  will  focus

asserted signal  A signal
that is (logically) true,
or 1.

deasserted signal
A signal that is (logically)
false, or 0.

A.2  Gates, Truth Tables, and Logic Equations

A-5

only  on  combinational  logic.  After  introducing  different  memory  elements  in
Section A.8, we will describe how sequential logic, which is logic including state,
is designed.

Truth Tables

Because  a  combinational  logic  block  contains  no  memory,  it  can  be  completely
specified by defining the values of the outputs for each possible set of input values.
Such  a  description  is  normally  given  as  a  truth  table.  For  a  logic  block  with  n
inputs,  there  are  2n  entries  in  the  truth  table,  since  there  are  that  many  possible
combinations of input values. Each entry specifies the value of all the outputs for
that particular input combination.

combinational logic
A logic system whose
blocks do not contain
memory and hence
compute the same output
given the same input.

sequential logic
A group of logic elements
that contain memory
and hence whose value
depends on the inputs
as well as the current
contents of the memory.

Truth Tables

Consider a logic function with three inputs, A, B, and C, and three outputs, D,
E, and F. The function is defined as follows: D is true if at least one input is true,
E is true if exactly two inputs are true, and F is true only if all three inputs are
true. Show the truth table for this function.

EXAMPLE

The truth table will contain 23 = 8 entries. Here it is:

ANSWER

Inputs

Outputs

A

0
0
0
0
1
1
1
1

B

0
0
1
1
0
0
1
1

C

0
1
0
1
0
1
0
1

D

0
1
1
1
1
1
1
1

E

0
0
0
1
0
1
1
0

F

0
0
0
0
0
0
0
1

Truth tables can completely describe any combinational logic function; however,
they grow in size quickly and may not be easy to understand. Sometimes we want
to construct a logic function that will be 0 for many input combinations, and we
use a shorthand of specifying only the truth table entries for the nonzero outputs.
This approach is used in Chapter 4 and

 Appendix C.

A-6

Appendix A  The Basics of Logic Design

Boolean Algebra

Another  approach  is  to  express  the  logic  function  with  logic  equations.  This
is  done  with  the  use  of  Boolean  algebra  (named  after  Boole,  a  19th-century
mathematician). In Boolean algebra, all the variables have the values 0 or 1 and, in
typical formulations, there are three operators:

■	 The OR operator is written as +, as in A + B. The result of an OR operator is
1 if either of the variables is 1. The OR operation is also called a logical sum,
since its result is 1 if either operand is 1.

■	 The AND operator is written as · , as in A · B. The result of an AND operator
is 1 only if both inputs are 1. The AND operator is also called logical product,
since its result is 1 only if both operands are 1.

■	 The unary operator NOT is written as A. The result of a NOT operator is 1 only if
the input is 0. Applying the operator NOT to a logical value results in an inversion
or negation of the value (i.e., if the input is 0 the output is 1, and vice versa).

There are several laws of Boolean algebra that are helpful in manipulating logic

equations.

■	 Identity law: A + 0 = A and A · 1 = A

■	 Zero and One laws: A + 1 = 1 and A · 0 = 0
■	 Inverse laws: A A 1 and A A⋅ (cid:31) 0

■	 Commutative laws: A + B = B + A and A · B = B · A

■	 Associative laws: A + (B + C) = (A + B) + C and A · (B · C) = (A · B) · C

■	 Distributive laws: A · (B + C) = (A · B) + (A · C) and

A + (B · C) = (A + B) · (A + C)

In addition, there are two other useful theorems, called DeMorgan’s laws, that

are discussed in more depth in the exercises.

Any set of logic functions can be written as a series of equations with an output
on the left-hand side of each equation and a formula consisting of variables and the
three operators above on the right-hand side.

A.2  Gates, Truth Tables, and Logic Equations

A-7

Logic Equations

Show the logic equations for the logic functions, D, E, and F, described in the
previous example.

EXAMPLE

Here’s the equation for D:

D

A B C

ANSWER

F is equally simple:

F

(cid:31) ⋅

A B C

⋅

E is a little tricky. Think of it in two parts: what must be true for E to be true
(two  of  the  three  inputs  must  be  true),  and  what  cannot  be  true  (all  three
cannot be true). Thus we can write E as

E

((

⋅
A B

)

(

⋅
A C

)

(

⋅
B C

⋅
)) (

A B C

)

⋅

⋅

We can also derive E by realizing that E is true only if exactly two of the inputs
are true. Then we can write E as an OR of the three possible terms that have
two true inputs and one false input:

E

(

A B C

)

(

A C B

)

(

)
B C A

⋅

⋅

⋅

⋅

⋅

⋅

Proving that these two expressions are equivalent is explored in the exercises.

In  Verilog,  we  describe  combinational  logic  whenever  possible  using  the  assign
statement, which is described beginning on page A-23. We can write a definition for
E using the Verilog exclusive-OR operator as  assign  E  =  (A  &  (B  ^  C))  |  (B  &  C
& ~A), which is yet another way to describe this function. D and F have even simpler
representations, which are just like the corresponding C code: assign D = A | B | C and
assign F = A & B & C.

A-8

Appendix A  The Basics of Logic Design

gate  A device that
implements basic logic
functions, such as AND
or OR.

NOR gate  An inverted
OR gate.

NAND gate  An inverted
AND gate.

Gates

Logic blocks are built from gates that implement basic logic functions. For example,
an AND gate implements the AND function, and an OR gate implements the OR
function. Since both AND and OR are commutative and associative, an AND or an
OR gate can have multiple inputs, with the output equal to the AND or OR of all
the inputs. The logical function NOT is implemented with an inverter that always
has a single input. The standard representation of these three logic building blocks
is shown in Figure A.2.1.

Rather  than  draw  inverters  explicitly,  a  common  practice  is  to  add  “bubbles”
to  the  inputs  or  outputs  of  a  gate  to  cause  the  logic  value  on  that  input  line  or
output line to be inverted. For example, Figure A.2.2 shows the logic diagram for
the  function  A B(cid:31) ,  using  explicit  inverters  on  the  left  and  bubbled  inputs  and
outputs on the right.

Any  logical  function  can  be  constructed  using  AND  gates,  OR  gates,  and
inversion;  several  of  the  exercises  give  you  the  opportunity  to  try  implementing
some  common  logic  functions  with  gates.  In  the  next  section,  we’ll  see  how  an
implementation of any logic function can be constructed using this knowledge.

In fact, all logic functions can be constructed with only a single gate type, if that
gate is inverting. The two common inverting gates are called NOR and NAND and
correspond to inverted OR and AND gates, respectively. NOR and NAND gates are
called universal, since any logic function can be built using this one gate type. The
exercises explore this concept further.

Check
Yourself

Are the following two logical expressions equivalent? If not, find a setting of the
variables to show they are not:

■	 (

A B C

⋅

⋅

)

(cid:31)

(

A C B

⋅

⋅

)

(cid:31)

(

B C A
)

⋅

⋅

⋅
■	 B A C C A
)

(cid:31)

(

⋅

⋅

FIGURE A.2.1  Standard drawing for an AND gate, OR gate, and an inverter, shown from
left to right. The signals to the left of each symbol are the inputs, while the output appears on the right. The
AND and OR gates both have two inputs. Inverters have a single input.

A
B

A
B

FIGURE A.2.2  Logic gate implementation of A
B+  using explicit inverts on the left and
bubbled inputs and outputs on the right. This logic function can be simplified to A B(cid:31)  or in Verilog,
A & ~ B.

A.3  Combinational Logic

A-9

  A.3  Combinational Logic

In  this  section,  we  look  at  a  couple  of  larger  logic  building  blocks  that  we  use
heavily,  and  we  discuss  the  design  of  structured  logic  that  can  be  automatically
implemented from a logic equation or truth table by a translation program. Last,
we discuss the notion of an array of logic blocks.

Decoders

One logic block that we will use in building larger components is a decoder. The
most common type of decoder has an n-bit input and 2n outputs, where only one
output  is  asserted  for  each  input  combination.  This  decoder  translates  the  n-bit
input  into  a  signal  that  corresponds  to  the  binary  value  of  the  n-bit  input.  The
outputs are thus usually numbered, say, Out0, Out1, …, Out2n −1. If the value of
the input is i, then Outi will be true and all other outputs will be false. Figure A.3.1
shows a 3-bit decoder and the truth table. This decoder is called a 3-to-8 decoder
since  there  are  three  inputs  and  eight  (23)  outputs. There  is  also  a  logic  element
called an encoder that performs the inverse function of a decoder, taking 2n inputs
and producing an n-bit output.

decoder  A logic block
that has an n-bit input and
2n outputs, where only
one output is asserted for
each input combination.

3

Decoder

Out0

Out1

Out2

Out3

Out4

Out5

Out6

Out7

stupnI

stuptuO

12

11

10

Out7 Out6 Out5 Out4 Out3 Out2 Out1 Out0

0

0

0

0

1

1

1

1

0

0

1

1

0

0

1

1

0

1

0

1

0

1

0

1

0

0

0

0

0

0

0

1

0

0

0

0

0

0

1

0

0

0

0

0

0

1

0

0

0

0

0

0

1

0

0

0

0

0

0

1

0

0

0

0

0

0

1

0

0

0

0

0

01

10

00

00

00

00

00

00

a. A 3-bit decoder

b. The truth table for a 3-bit decoder

FIGURE A.3.1  A 3-bit decoder has three inputs, called 12, 11, and 10, and 23 = 8 outputs, called Out0 to Out7. Only the
output corresponding to the binary value of the input is true, as shown in the truth table. The label 3 on the input to the decoder says that the
input signal is 3 bits wide.

A-10

Appendix A  The Basics of Logic Design

A

B

0
M
u
x

1

S

C

A

B

S

C

FIGURE A.3.2  A two-input multiplexor on the left and its implementation with gates on
the right. The multiplexor has two data inputs (A and B), which are labeled 0 and 1, and one selector input
(S), as well as an output C. Implementing multiplexors in Verilog requires a little more work, especially when
they are wider than two inputs. We show how to do this beginning on page A-23.

Multiplexors

selector value  Also
called control value. The
control signal that is used
to select one of the input
values of a multiplexor
as the output of the
multiplexor.

One basic logic function that we use quite often in Chapter 4 is the multiplexor.
A multiplexor might more properly be called a selector, since its output is one of
the inputs that is selected by a control. Consider the two-input multiplexor. The
left side of Figure A.3.2 shows this multiplexor has three inputs: two data values
and  a  selector  (or  control)  value.  The  selector  value  determines  which  of  the
inputs  becomes  the  output.  We  can  represent  the  logic  function  computed  by  a
two-input  multiplexor,  shown  in  gate  form  on  the  right  side  of  Figure  A.3.2,  as
C

⋅
A S

⋅
B S

(

)

(

)
.

Multiplexors  can  be  created  with  an  arbitrary  number  of  data  inputs.  When
there are only two inputs, the selector is a single signal that selects one of the inputs
if it is true (1) and the other if it is false (0). If there are n data inputs, there will
 selector inputs. In this case, the multiplexor basically consists of

need to be  log2 n
three parts:

1.  A decoder that generates n signals, each indicating a different input value

2.  An array of n AND gates, each combining one of the inputs with a signal

from the decoder

3.  A single large OR gate that incorporates the outputs of the AND gates

To  associate  the  inputs  with  selector  values,  we  often  label  the  data  inputs
numerically  (i.e.,  0,  1,  2,  3,  …,  n  −1)  and  interpret  the  data  selector  inputs  as  a
binary number. Sometimes, we make use of a multiplexor with undecoded selector
signals.

Multiplexors  are  easily  represented  combinationally  in  Verilog  by  using  if
expressions. For larger multiplexors, case statements are more convenient, but care
must be taken to synthesize combinational logic.

A.3  Combinational Logic

A-11

Two-Level Logic and PLAs

As pointed out in the previous section, any logic function can be implemented with
only AND, OR, and NOT functions. In fact, a much stronger result is true. Any logic
function can be written in a canonical form, where every input is either a true or
complemented variable and there are only two levels of gates—one being AND and
the other OR—with a possible inversion on the final output. Such a representation
is called a two-level representation, and there are two forms, called sum of products
and product of sums. A sum-of-products representation is a logical sum (OR) of
products (terms using the AND operator); a product of sums is just the opposite.
In our earlier example, we had two equations for the output E:

E

((

⋅
A B

)

(

⋅
A C

)

(

⋅
B C

⋅
)) (

A B C

)

⋅

⋅

sum of products  A form
of logical representation
that employs a logical sum
(OR) of products (terms
joined using the AND
operator).

and

E

(

A B C

)

(

A C B

)

(

)
B C A

⋅

⋅

⋅

⋅

⋅

⋅

This second equation is in a sum-of-products form: it has two levels of logic and
the only inversions are on individual variables. The first equation has three levels
of logic.

Elaboration:  We can also write E as a product of sums:

E

(

A B C

⋅
) (

A C

B

⋅
) (

)
B C A

To derive this form, you need to use DeMorgan’s theorems, which are discussed in the
exercises.

In this text, we use the sum-of-products form. It is easy  to see that any logic
function  can  be  represented  as  a  sum  of  products  by  constructing  such  a
representation  from  the  truth  table  for  the  function.  Each  truth  table  entry  for
which  the  function  is  true  corresponds  to  a  product  term.  The  product  term
consists  of  a  logical  product  of  all  the  inputs  or  the  complements  of  the  inputs,
depending on whether the entry in the truth table has a 0 or 1 corresponding to
this variable. The logic function is the logical sum of the product terms where the
function is true. This is more easily seen with an example.

A-12

Appendix A  The Basics of Logic Design

Sum of Products

EXAMPLE

Show the sum-of-products representation for the following truth table for D.

Inputs

Outputs

A

0
0
0
0
1
1
1
1

B

0
0
1
1
0
0
1
1

C

0
1
0
1
0
1
0
1

D

0
1
1
0
1
0
0
1

ANSWER

There are four product terms, since the function is true (1) for four different
input combinations. These are:

A B C
A B C
A B C
A B C

⋅
⋅
⋅
⋅

⋅
⋅
⋅
⋅

Thus, we can write the function for D as the sum of these terms:

D

(

A B C

)

(

A B C

)

(

A B C

)

(

A B C

)

⋅

⋅

⋅

⋅

⋅

⋅

⋅

⋅

Note that only those truth table entries for which the function is true generate
terms in the equation.

We can use this relationship between a truth table and a two-level representation
to generate a gate-level implementation of any set of logic functions. A set of logic
functions corresponds to a truth table with multiple output columns, as we saw in
the example on page A-5. Each output column represents a different logic function,
which may be directly constructed from the truth table.

The sum-of-products representation corresponds to a common structured-logic
implementation  called  a  programmable  logic  array  (PLA).  A  PLA  has  a  set  of
inputs and corresponding input complements (which can be implemented with a
set of inverters), and two stages of logic. The first stage is an array of AND gates that
form a set of product terms (sometimes called minterms); each product term can
consist of any of the inputs or their complements. The second stage is an array of
OR gates, each of which forms a logical sum of any number of the product terms.
Figure A.3.3 shows the basic form of a PLA.

programmable logic
array (PLA)
A structured-logic
element composed
of a set of inputs and
corresponding input
complements and two
stages of logic: the first
generates product terms
of the inputs and input
complements, and the
second generates sum
terms of the product
terms. Hence, PLAs
implement logic functions
as a sum of products.

minterms  Also called
product terms. A set
of logic inputs joined
by conjunction (AND
operations); the product
terms form the first logic
stage of the programmable
logic array (PLA).

A.3  Combinational Logic

A-13

Inputs

AND gates

Product terms

OR gates

Outputs

FIGURE A.3.3  The basic form of a PLA consists of an array of AND gates followed by an
array of OR gates. Each entry in the AND gate array is a product term consisting of any number of inputs or
inverted inputs. Each entry in the OR gate array is a sum term consisting of any number of these product terms.

A PLA can directly implement the truth table of a set of logic functions with
multiple  inputs  and  outputs.  Since  each  entry  where  the  output  is  true  requires
a  product  term,  there  will  be  a  corresponding  row  in  the  PLA.  Each  output
corresponds to a potential row of OR gates in the second stage. The number of OR
gates corresponds to the number of truth table entries for which the output is true.
The total size of a PLA, such as that shown in Figure A.3.3, is equal to the sum of
the size of the AND gate array (called the AND plane) and the size of the OR gate
array (called the OR plane). Looking at Figure A.3.3, we can see that the size of
the AND gate array is equal to the number of inputs times the number of different
product terms, and the size of the OR gate array is the number of outputs times the
number of product terms.

A PLA has two characteristics that help make it an efficient way to implement a
set of logic functions. First, only the truth table entries that produce a true value for
at least one output have any logic gates associated with them. Second, each different
product term will have only one entry in the PLA, even if the product term is used
in multiple outputs. Let’s look at an example.

PLAs

Consider the set of logic functions defined in the example on page A-5. Show
a PLA implementation of this example for D, E, and F.

EXAMPLE

A-14

Appendix A  The Basics of Logic Design

ANSWER

Here is the truth table we constructed earlier:

Inputs

Outputs

A

0
0
0
0
1
1
1
1

B

0
0
1
1
0
0
1
1

C

0
1
0
1
0
1
0
1

D

0
1
1
1
1
1
1
1

E

0
0
0
1
0
1
1
0

F

0
0
0
0
0
0
0
1

Since there are seven unique product terms with at least one true value in the
output section, there will be seven columns in the AND plane. The number of
rows in the AND plane is three (since there are three inputs), and there are also
three rows in the OR plane (since there are three outputs). Figure A.3.4 shows
the  resulting  PLA,  with  the  product  terms  corresponding  to  the  truth  table
entries from top to bottom.

Rather than drawing all the gates, as we do in Figure A.3.4, designers often show
just the position of AND gates and OR gates. Dots are used on the intersection of a
product term signal line and an input line or an output line when a corresponding
AND gate or OR gate is required. Figure A.3.5 shows how the PLA of Figure A.3.4
would look when drawn in this way. The contents of a PLA are fixed when the PLA
is created, although there are also forms of PLA-like structures, called PLAs, that
can be programmed electronically when a designer is ready to use them.

ROMs

Another  form  of  structured  logic  that  can  be  used  to  implement  a  set  of  logic
functions is a read-only memory (ROM). A ROM is called a memory because it
has a set of locations that can be read; however, the contents of these locations are
fixed, usually at the time the ROM is manufactured. There are also programmable
ROMs (PROMs) that can be programmed electronically, when a designer knows
their contents. There are also erasable PROMs; these devices require a slow erasure
process  using  ultraviolet  light,  and  thus  are  used  as  read-only  memories,  except
during the design and debugging process.

A  ROM  has  a  set  of  input  address  lines  and  a  set  of  outputs.  The  number  of
addressable  entries  in  the  ROM  determines  the  number  of  address  lines:  if  the

read-only memory
(ROM)  A memory
whose contents are
designated at creation
time, after which the
contents can only be read.
ROM is used as structured
logic to implement a
set of logic functions by
using the terms in the
logic functions as address
inputs and the outputs as
bits in each word of the
memory.

programmable ROM
(PROM)  A form of
read-only memory that
can be programmed
when a designer knows its
contents.

A.3  Combinational Logic

A-15

ROM  contains  2m  addressable  entries,  called  the  height,  then  there  are  m  input
lines. The number of bits in each addressable entry is equal to the number of output
bits and is sometimes called the width of the ROM. The total number of bits in the
ROM is equal to the height times the width. The height and width are sometimes
collectively referred to as the shape of the ROM.

Inputs

A
B
C

Outputs
D

E

F

FIGURE A.3.4  The PLA for implementing the logic function described in the example.

A ROM can encode a collection of logic functions directly from the truth table.
For example, if there are n functions with m inputs, we need a ROM with m address
lines (and 2m entries), with each entry being n bits wide. The entries in the input
portion of the truth table represent the addresses of the entries in the ROM, while
the contents of the output portion of the truth table constitute the contents of the
ROM. If the truth table is organized so that the sequence of entries in the input
portion  constitutes  a  sequence  of  binary  numbers  (as  have  all  the  truth  tables
we have shown so far), then the output portion gives the ROM contents in order
as well. In the example starting on page A-13, there were three inputs and three
outputs. This leads to a ROM with 23 = 8 entries, each 3 bits wide. The contents of
those entries in increasing order by address are directly given by the output portion
of the truth table that appears on page A-14.

ROMs and PLAs are closely related. A ROM is fully decoded: it contains a full
output word for every possible input combination. A PLA is only partially decoded.
This means that a ROM will always contain more entries. For the earlier truth table
on page A-14, the ROM contains entries for all eight possible inputs, whereas the
PLA contains only the seven active product terms. As the number of inputs grows,

A-16

Appendix A  The Basics of Logic Design

Inputs

A

B

C

OR plane

AND plane

Outputs

D

E

F

FIGURE A.3.5  A PLA drawn using dots to indicate the components of the product terms
and sum terms in the array. Rather than use inverters on the gates, usually all the inputs are run the
width of the AND plane in both true and complement forms. A dot in the AND plane indicates that the
input, or its inverse, occurs in the product term. A dot in the OR plane indicates that the corresponding
product term appears in the corresponding output.

the number of entries in the ROM grows exponentially. In contrast, for most real
logic functions, the number of product terms grows much more slowly (see the
 Appendix C). This difference makes PLAs generally more efficient
examples in
for  implementing  combinational  logic  functions.  ROMs  have  the  advantage  of
being able to implement any logic function with the matching number of inputs
and outputs. This advantage makes it easier to change the ROM contents if the logic
function changes, since the size of the ROM need not change.

In  addition  to  ROMs  and  PLAs,  modern  logic  synthesis  systems  will  also
translate  small  blocks  of  combinational  logic  into  a  collection  of  gates  that  can
be placed and wired automatically. Although some small collections of gates are
usually not area-efficient, for small logic functions they have less overhead than the
rigid structure of a ROM and PLA and so are preferred.

For designing logic outside of a custom or semicustom integrated circuit, a common

choice is a field programming device; we describe these devices in Section A.12.

A.3  Combinational Logic

A-17

Don’t Cares

Often in implementing some combinational logic, there are situations where we do
not care what the value of some output is, either because another output is true or
because a subset of the input combinations determines the values of the outputs.
Such situations are referred to as don’t cares. Don’t cares are important because they
make it easier to optimize the implementation of a logic function.

There are two types of don’t cares: output don’t cares and input don’t cares, both
of which can be represented in a truth table. Output don’t cares arise when we don’t
care about the value of an output for some input combination. They appear as Xs in
the output portion of a truth table. When an output is a don’t care for some input
combination, the designer or logic optimization program is free to make the output
true  or  false  for  that  input  combination.  Input  don’t  cares  arise  when  an  output
depends on only some of the inputs, and they are also shown as Xs, though in the
input portion of the truth table.

Don’t Cares

Consider a logic function with inputs A, B, and C defined as follows:

■	 If A or C is true, then output D is true, whatever the value of B.

■	 If A or B is true, then output E is true, whatever the value of C.

■	 Output F is true if exactly one of the inputs is true, although we don’t care

about the value of F, whenever D and E are both true.

Show the full truth table for this function and the truth table using don’t cares.
How many product terms are required in a PLA for each of these?

EXAMPLE

Here’s the full truth table, without don’t cares:

ANSWER

Inputs

Outputs

A

0
0
0
0
1
1
1
1

B

0
0
1
1
0
0
1
1

C

0
1
0
1
0
1
0
1

D

0
1
0
1
1
1
1
1

E

0
0
1
1
1
1
1
1

F

0
1
1
0
1
0
0
0

A-18

Appendix A  The Basics of Logic Design

This  requires  seven  product  terms  without  optimization.  The  truth  table

written with output don’t cares looks like this:

Inputs

Outputs

A

0
0
0
0
1
1
1
1

B

0
0
1
1
0
0
1
1

C

0
1
0
1
0
1
0
1

D

0
1
0
1
1
1
1
1

E

0
0
1
1
1
1
1
1

F

0
1
1
X
X
X
X
X

If we also use the input don’t cares, this truth table can be further simplified

to yield the following:

Inputs

Outputs

A

0
0
0
X
1

B

0
0
1
1
X

C

0
1
0
1
X

D

0
1
0
1
1

E

0
0
1
1
1

F

0
1
1
X
X

This simplified truth table requires a PLA with four minterms, or it can be
implemented in discrete gates with one two-input AND gate and three OR gates
(two with three inputs and one with two inputs). This compares to the original
truth table that had seven minterms and would have required four AND gates.

Logic minimization is critical to achieving efficient implementations. One tool
useful for hand minimization of random logic is Karnaugh maps. Karnaugh maps
represent the truth table graphically, so that product terms that may be combined
are  easily  seen.  Nevertheless,  hand  optimization  of  significant  logic  functions
using Karnaugh maps is impractical, both because of the size of the maps and their
complexity. Fortunately, the process of logic minimization is highly mechanical and
can be performed by design tools. In the process of minimization, the tools take
advantage of the don’t cares, so specifying them is important. The textbook references
at  the  end  of  this  appendix  provide  further  discussion  on  logic  minimization,
Karnaugh maps, and the theory behind such minimization algorithms.

Arrays of Logic Elements

Many of the combinational operations to be performed on data have to be done
to an entire word (64 bits) of data. Thus we often want to build an array of logic

A.3  Combinational Logic

A-19

bus  In logic design, a
collection of data lines
that is treated together
as a single logical signal;
also, a shared collection
of lines with multiple
sources and uses.

elements, which we can represent simply by showing that a given operation will
happen to an entire collection of inputs. Inside a machine, much of the time we
want to select between a pair of buses. A bus is a collection of data lines that is
treated together as a single logical signal. (The term bus is also used to indicate a
shared collection of lines with multiple sources and uses.)

For example, in the RISC-V instruction set, the result of an instruction that is
written into a register can come from one of two sources. A multiplexor is used to
choose which of the two buses (each 64 bits wide) will be written into the Result
register. The 1-bit multiplexor, which we showed earlier, will need to be replicated
64 times.

We indicate that a signal is a bus rather than a single 1-bit line by showing it with
a thicker line in a figure. Most buses are 64 bits wide; those that are not are explicitly
labeled with their width. When we show a logic unit whose inputs and outputs are
buses, this means that the unit must be replicated a sufficient number of times to
accommodate the width of the input. Figure A.3.6 shows how we draw a multiplexor
that selects between a pair of 64-bit buses and how this expands in terms of 1-bit-
wide  multiplexors.  Sometimes  we  need  to  construct  an  array  of  logic  elements
where the inputs for some elements in the array are outputs from earlier elements.
For example, this is how a multibit-wide ALU is constructed. In such cases, we must
explicitly show how to create wider arrays, since the individual elements of the array
are no longer independent, as they are in the case of a 64-bit-wide multiplexor.

Select

Select

64

A

64

B

M
u
x

64

C

A63

B63

A62

B62

A0

B0

M
u
x

M
u
x

...

M
u
x

C63

C62

...

C0

a. A 64-bit wide 2-to-1 multiplexor

b. The 64-bit wide multiplexor is actually
an array of 64 1-bit multiplexors

FIGURE  A.3.6  A  multiplexor  is  arrayed  64  times  to  perform  a  selection  between  two
64-bit inputs. Note that there is still only one data selection signal used for all 64 1-bit multiplexors.

A-20

Appendix A  The Basics of Logic Design

Check
Yourself

Parity is a function in which the output depends on the number of 1s in the input.
For an even parity function, the output is 1 if the input has an even number of ones.
Suppose a ROM is used to implement an even parity function with a 4-bit input.
Which of A, B, C, or D represents the contents of the ROM?

Address

0
1
2
3
4
5
6
7
8
9
10
11
12
13
14
15

A

0
0
0
0
0
0
0
0
1
1
1
1
1
1
1
1

B

1
1
1
1
1
1
1
1
0
0
0
0
0
0
0
0

C

0
1
0
1
0
1
0
1
0
1
0
1
0
1
0
1

D

1
0
1
0
1
0
1
0
1
0
1
0
1
0
1
0

  A.4  Using a Hardware Description Language

2.  A  reg  (register)  holds  a  value,  which  can  vary  with  time.  A  reg  need  not

necessarily correspond to an actual register in an implementation, although

reg  In Verilog, a register.

wire  In Verilog, specifies

a combinational signal.

hardware description
language
A programming language
for describing hardware,
used for generating
simulations of a hardware
design and also as input
to synthesis tools that can
generate actual hardware.

Verilog  One of the two
most common hardware
description languages.

VHDL  One of the two
most common hardware
description languages.

Today  most  digital  design  of  processors  and  related  hardware  systems  is  done
using  a  hardware  description  language.  Such  a  language  serves  two  purposes.
First, it provides an abstract description of the hardware to simulate and debug the
design. Second, with the use of logic synthesis and hardware compilation tools, this
description can be compiled into the hardware implementation.

In  this  section,  we  introduce  the  hardware  description  language  Verilog  and
show  how  it  can  be  used  for  combinational  design.  In  the  rest  of  the  appendix,
we expand the use of Verilog to include design of sequential logic. In the optional
sections  of  Chapter  4  that  appear  online,  we  use  Verilog  to  describe  processor
implementations. In the optional section from Chapter 5 that appears online, we
use system Verilog to describe cache controller implementations. System Verilog
adds structures and some other useful features to Verilog.

Verilog  is  one  of  the  two  primary  hardware  description  languages;  the  other
is VHDL. Verilog is somewhat more heavily used in industry and is based on C,
as opposed to VHDL, which is based on Ada. The reader generally familiar with
C  will  find  the  basics  of  Verilog,  which  we  use  in  this  appendix,  easy  to  follow.

Readers  already  familiar  with  VHDL  should  find  the  concepts  simple,  provided

they have been exposed to the syntax of C.

Verilog  can  specify  both  a  behavioral  and  a  structural  definition  of  a  digital

system.  A  behavioral  specification  describes  how  a  digital  system  functionally

behavioral

operates. A structural specification describes the detailed organization of a digital

specification  Describes

system, usually using a hierarchical description. A structural specification can be

used to describe a hardware system in terms of a hierarchy of basic elements such

as gates and switches. Thus, we could use Verilog to describe the exact contents of

the truth tables and datapath of the last section.

With the arrival of hardware synthesis tools, most designers now use Verilog

or VHDL to structurally describe only the datapath, relying on logic synthesis to

generate the control from a behavioral description. In addition, most CAD systems

provide  extensive  libraries  of  standardized  parts,  such  as  ALUs,  multiplexors,

register files, memories, and programmable logic blocks, as well as basic gates.

Obtaining an acceptable result using libraries and logic synthesis requires that

the  specification  be  written  with  an  eye  toward  the  eventual  synthesis  and  the

desired outcome. For our simple designs, this primarily means making clear what

we expect to be implemented in combinational logic and what we expect to require

in sequential logic. In most of the examples we use in this section and the remainder

of this appendix, we have written the Verilog with the eventual synthesis in mind.

how a digital system

operates functionally.

structural

specification  Describes

how a digital system is

organized in terms of a

hierarchical connection of

elements.

hardware synthesis

tools  Computer-aided

design software that

can generate a gate-

level design based on

behavioral descriptions of

a digital system.

Datatypes and Operators in Verilog

There are two primary datatypes in Verilog:

1.  A wire specifies a combinational signal.

it often will.

A register or wire, named X, that is 64 bits wide is declared as an array:  reg

[63:0]  X or wire  [63:0]  X, which also sets the index of 0 to designate the

least significant bit of the register. Because we often want to access a subfield of a

register or wire, we can refer to a contiguous set of bits of a register or wire with the

notation [starting bit: ending bit], where both indices must be constant

An array of registers is used for a structure like a register file or memory. Thus,

values.

the declaration

reg [63:0] registerfile[0:31]

specifies  a  variable  registerfile  that  is  equivalent  to  a  RISC-V  registerfile,  where

register 0 is the first. When accessing an array, we can refer to a single element, as

in C, using the notation registerfile[regnum].

A.4  Using a Hardware Description Language

A-21

behavioral
specification  Describes
how a digital system
operates functionally.

structural
specification  Describes
how a digital system is
organized in terms of a
hierarchical connection of
elements.

hardware synthesis
tools  Computer-aided
design software that
can generate a gate-
level design based on
behavioral descriptions of
a digital system.

wire  In Verilog, specifies
a combinational signal.

reg  In Verilog, a register.

Readers  already  familiar  with  VHDL  should  find  the  concepts  simple,  provided
they have been exposed to the syntax of C.

Verilog  can  specify  both  a  behavioral  and  a  structural  definition  of  a  digital
system.  A  behavioral  specification  describes  how  a  digital  system  functionally
operates. A structural specification describes the detailed organization of a digital
system, usually using a hierarchical description. A structural specification can be
used to describe a hardware system in terms of a hierarchy of basic elements such
as gates and switches. Thus, we could use Verilog to describe the exact contents of
the truth tables and datapath of the last section.

With the arrival of hardware synthesis tools, most designers now use Verilog
or VHDL to structurally describe only the datapath, relying on logic synthesis to
generate the control from a behavioral description. In addition, most CAD systems
provide  extensive  libraries  of  standardized  parts,  such  as  ALUs,  multiplexors,
register files, memories, and programmable logic blocks, as well as basic gates.

Obtaining an acceptable result using libraries and logic synthesis requires that
the  specification  be  written  with  an  eye  toward  the  eventual  synthesis  and  the
desired outcome. For our simple designs, this primarily means making clear what
we expect to be implemented in combinational logic and what we expect to require
in sequential logic. In most of the examples we use in this section and the remainder
of this appendix, we have written the Verilog with the eventual synthesis in mind.

Datatypes and Operators in Verilog

There are two primary datatypes in Verilog:

1.  A wire specifies a combinational signal.

2.  A  reg  (register)  holds  a  value,  which  can  vary  with  time.  A  reg  need  not
necessarily correspond to an actual register in an implementation, although
it often will.

A register or wire, named X, that is 64 bits wide is declared as an array:  reg
[63:0]  X or wire  [63:0]  X, which also sets the index of 0 to designate the
least significant bit of the register. Because we often want to access a subfield of a
register or wire, we can refer to a contiguous set of bits of a register or wire with the
notation [starting bit: ending bit], where both indices must be constant
values.

An array of registers is used for a structure like a register file or memory. Thus,

the declaration

reg [63:0] registerfile[0:31]

specifies  a  variable  registerfile  that  is  equivalent  to  a  RISC-V  registerfile,  where
register 0 is the first. When accessing an array, we can refer to a single element, as
in C, using the notation registerfile[regnum].

Verilog  One of the two

most common hardware

description languages.

VHDL  One of the two

most common hardware

description languages.

A-22

Appendix A  The Basics of Logic Design

The possible values for a register or wire in Verilog are

■	 0 or 1, representing logical false or true

■	 X, representing unknown, the initial value given to all registers and to any

wire not connected to something

■	 Z, representing the high-impedance state for tristate gates, which we will not

discuss in this appendix

Constant values can be specified as decimal numbers as well as binary, octal, or
hexadecimal. We often want to say exactly how large a constant field is in bits. This
is done by prefixing the value with a decimal number specifying its size in bits. For
example:

■	 4’b0100 specifies a 4-bit binary constant with the value 4, as does 4’d4.

■	 −8’h4  specifies  an  8-bit  constant  with  the  value  −4  (in  two’s  complement

representation)

Values can also be concatenated by placing them within { } separated by commas.

The notation {x{bitfield}} replicates bitfield x times. For example:

■	 {32{2’b01}} creates a 64-bit value with the pattern 0101 … 01.

■	 {A[31:16],B[15:0]}  creates  a  value  whose  upper  16  bits  come  from  A

and whose lower 16 bits come from B.

Verilog provides the full set of unary and binary operators from C, including
the arithmetic operators (+, −, *. /), the logical operators (&, |, ~), the comparison
operators  (=  =,  !  =,  >,  <  ,  <  =,  >  =),  the  shift  operators  (<<,  >>),  and  C’s
conditional operator (?, which is used in the form condition ? expr1 :expr2
and returns expr1 if the condition is true and expr2 if it is false). Verilog adds
a set of unary logic reduction operators (&, |, ^) that yield a single bit by applying
the logical operator to all the bits of an operand. For example, &A returns the value
obtained by ANDing all the bits of A together, and ^A returns the reduction obtained
by using exclusive OR on all the bits of A.

Check
Yourself

Which of the following define exactly the same value?

1. 8’bimoooo

2. 8’hF0

3. 8’d240

4. {{4{1’b1}},{4{1’b0}}}

5. {4’b1,4’b0)

A.4  Using a Hardware Description Language

A-23

Structure of a Verilog Program

A Verilog program is structured as a set of modules, which may represent anything
from a collection of logic gates to a complete system. Modules are similar to classes
in C++, although not nearly as powerful. A module specifies its input and output
ports,  which  describe  the  incoming  and  outgoing  connections  of  a  module.  A
module may also declare additional variables. The body of a module consists of:

■	 initial constructs, which can initialize reg variables

■	 Continuous assignments, which define only combinational logic

■	 always  constructs,  which  can  define  either  sequential  or  combinational

logic

■	 Instances of other modules, which are used to implement the module being

defined

Representing Complex Combinational Logic in Verilog

A continuous assignment, which is indicated with the keyword assign, acts like
a combinational logic function: the output is continuously assigned the value, and
a  change  in  the  input  values  is  reflected  immediately  in  the  output  value.  Wires
may  only  be  assigned  values  with  continuous  assignments.  Using  continuous
assignments, we can define a module that implements a half-adder, as Figure A.4.1
shows.

Assign statements are one sure way to write Verilog that generates combinational
logic. For more complex structures, however, assign statements may be awkward or
tedious to use. It is also possible to use the always block of a module to describe
a  combinational  logic  element,  although  care  must  be  taken.  Using  an  always
block allows the inclusion of Verilog control constructs, such as if-then-else, case
statements, for statements, and repeat statements, to be used. These statements are
similar to those in C with small changes.

An  always  block  specifies  an  optional  list  of  signals  on  which  the  block  is
sensitive (in a list starting with @). The always block is re-evaluated if any of the

FIGURE A.4.1  A Verilog module that defines a half-adder using continuous assignments.

A-24

Appendix A  The Basics of Logic Design

sensitivity list  The list of
signals that specifies when
an always block should
be re-evaluated.

listed signals changes value; if the list is omitted, the always block is constantly re-
evaluated. When an always block is specifying combinational logic, the sensitivity
list should include all the input signals. If there are multiple Verilog statements to
be executed in an always block, they are surrounded by the keywords begin and
end, which take the place of the { and } in C. An always block thus looks like this:

blocking assignment  In
Verilog, an assignment
that completes before
the execution of the next
statement.

nonblocking
assignment  An
assignment that continues
after evaluating the right-
hand side, assigning the
left-hand side the value
only after all right-hand
sides are evaluated.

always @(list of signals that cause reevaluation) begin
   Verilog statements including assignments and other
control statements end

Reg variables may only be assigned inside an always block, using a procedural
assignment  statement  (as  distinguished  from  continuous  assignment  we  saw
earlier).  There  are,  however,  two  different  types  of  procedural  assignments.  The
assignment operator = executes as it does in C; the right-hand side is evaluated,
and  the  left-hand  side  is  assigned  the  value.  Furthermore,  it  executes  like  the
normal C assignment statement: that is, it is completed before the next statement
is executed. Hence, the assignment operator = has the name blocking assignment.
This blocking can be useful in the generation of sequential logic, and we will return
to it shortly. The other form of assignment (nonblocking) is indicated by <=. In
nonblocking  assignment,  all  right-hand  sides  of  the  assignments  in  an  always
group  are  evaluated  and  the  assignments  are  done  simultaneously.  As  a  first
example of combinational logic implemented using an always block, Figure A.4.2
shows the implementation of a 4-to-1 multiplexor, which uses a case construct to
make it easy to write. The case construct looks like a C switch statement. Figure
A.4.3 shows a definition of a RISC-V ALU, which also uses a case statement.

Since only reg variables may be assigned inside always blocks, when we want to
describe combinational logic using an always block, care must be taken to ensure
that the reg does not synthesize into a register. A variety of pitfalls are described in
the elaboration below.

Elaboration:  Continuous  assignment  statements  always  yield  combinational  logic,
but other Verilog structures, even when in always blocks, can yield unexpected results
during  logic  synthesis.  The  most  common  problem  is  creating  sequential  logic  by
implying the existence of a latch or register, which results in an implementation that is
both slower and more costly than perhaps intended. To ensure that the logic that you
intend to be combinational is synthesized that way, make sure you do the following:

1.  Place all combinational logic in a continuous assignment or an always block.

2.  Make sure that all the signals used as inputs appear in the sensitivity list of an

always block.

3.  Ensure that every path through an always block assigns a value to the exact

same set of bits.

The  last  of  these  is  the  easiest  to  overlook;  read  through  the  example  in  Figure

A.5.15 to convince yourself that this property is adhered to.

A.4  Using a Hardware Description Language

A-25

FIGURE A.4.2  A Verilog definition of a 4-to-1 multiplexor with 64-bit inputs, using a case
statement. The case statement acts like a C switch statement, except that in Verilog only the code
associated with the selected case is executed (as if each case state had a break at the end) and there is no
fall-through to the next statement.

FIGURE A.4.3  A Verilog behavioral definition of a RISC-V ALU. This could be synthesized using a module library containing basic
arithmetic and logical operations.

A-26

Appendix A  The Basics of Logic Design

Check
Yourself

Assuming all values are initially zero, what are the values of A and B after executing
this Verilog code inside an always block?

C = 1;
A <= C;
B = C;

  A.5  Constructing a Basic Arithmetic

Logic Unit

ALU n. [Arthritic
Logic Unit or (rare)
Arithmetic Logic Unit]
A random-number
generator supplied
as standard with all
computer systems.
Stan Kelly-Bootle, The
Devil’s DP Dictionary,
1981

The arithmetic logic unit (ALU) is the brawn of the computer, the device that per-
forms the arithmetic operations like addition and subtraction or logical operations
like AND and OR. This section constructs an ALU from four hardware building
blocks  (AND  and  OR  gates,  inverters,  and  multiplexors)  and  illustrates  how
combinational logic works. In the next section, we will see how addition can be
sped up through more clever designs.

Because  the  RISC-V  registers  are  64  bits  wide,  we  need  a  64-bit-wide  ALU.
Let’s assume that we will connect 64 1-bit ALUs to create the desired ALU. We’ll
therefore start by constructing a 1-bit ALU.

A 1-Bit ALU

The  logical  operations  are  easiest,  because  they  map  directly  onto  the  hardware
components in Figure A.2.1.

The 1-bit logical unit for AND and OR looks like Figure A.5.1. The multiplexor
on  the  right  then  selects  a  AND  b  or  a  OR  b,  depending  on  whether  the  value
of  Operation  is  0  or  1.  The  line  that  controls  the  multiplexor  is  shown  in  color
to distinguish it from the lines containing data. Notice that we have renamed the
control  and  output  lines  of  the  multiplexor  to  give  them  names  that  reflect  the
function of the ALU.

The next function to include is addition. An adder must have two inputs for the
operands and a single-bit output for the sum. There must be a second output to
pass on the carry, called CarryOut. Since the CarryOut from the neighbor adder
must be included as an input, we need a third input. This input is called CarryIn.
Figure A.5.2 shows the inputs and the outputs of a 1-bit adder. Since we know what
addition is supposed to do, we can specify the outputs of this “black box” based on
its inputs, as Figure A.5.3 demonstrates.

We can express the output functions CarryOut and Sum as logical equations,
and these equations can in turn be implemented with logic gates. Let’s do CarryOut.
Figure A.5.4 shows the values of the inputs when CarryOut is a 1.

We can turn this truth table into a logical equation:

CarryOut

(

)
b CarryIn

⋅

)
a CarryIn
(

⋅

⋅
a b
)
(

(
a b CarryIn

)

⋅

⋅

A.5  Constructing a Basic Arithmetic Logic Unit

A-27

Operation

0

1

Result

a

b

FIGURE A.5.1  The 1-bit logical unit for AND and OR.

a

b

CarryIn

+

Sum

CarryOut

FIGURE A.5.2  A 1-bit adder. This adder is called a full adder; it is also called a (3,2) adder because it
has three inputs and two outputs. An adder with only the a and b inputs is called a (2,2) adder or half-adder.

stupnI

stuptuO

a

0

0

0

0

1

1

1

1

b

0

0

1

1

0

0

1

1

CarryIn

CarryOut

Sum

Comments

0

1

0

1

0

1

0

1

00

01

01

10

01

10

10

11

0 + 0 + 0 = 00two
0 + 0 + 1 = 01two
0 + 1 + 0 = 01two
0 + 1 + 1 = 10two
1 + 0 + 0 = 01two
1 + 0 + 1 = 10two
1 + 1 + 0 = 10two
1 + 1 + 1 = 11two

FIGURE A.5.3

Input and output specification for a 1-bit adder.

A-28

Appendix A  The Basics of Logic Design

If a · b · CarryIn is true, then all of the other three terms must also be true, so we
can leave out this last term corresponding to the fourth line of the table. We can
thus simplify the equation to

CarryOut

(

b CarryIn

⋅

)

)
a CarryIn
(

⋅

⋅
a b
)
(

Figure  A.5.5  shows  that  the  hardware  within  the  adder  black  box  for  CarryOut
consists of three AND gates and one OR gate. The three AND gates correspond
exactly to the three parenthesized terms of the formula above for CarryOut, and
the OR gate sums the three terms.

a

0

1

1

1

Inputs

b

1

0

1

1

CarryIn

1

1

0

1

FIGURE A.5.4  Values of the inputs when CarryOut is a 1.

CarryIn

a

b

FIGURE A.5.5  Adder hardware for the CarryOut signal. The rest of the adder hardware is the logic
for the Sum output given in the equation on this page.

CarryOut

The Sum bit is set when exactly one input is 1 or when all three inputs are 1. The

Sum results in a complex Boolean equation (recall that a means NOT a):

Sum

)
a b CarryIn
(

⋅

⋅

(

a b CarryIn

)

(

)
a b CarryIn

⋅

⋅

⋅

⋅

))
a b CarryIn
(

⋅

⋅

The drawing of the logic for the Sum bit in the adder black box is left as an exercise
for the reader.

A.5  Constructing a Basic Arithmetic Logic Unit

A-29

Figure A.5.6 shows a 1-bit ALU derived by combining the adder with the earlier
components.  Sometimes  designers  also  want  the  ALU  to  perform  a  few  more
simple operations, such as generating 0. The easiest way to add an operation is to
expand the multiplexor controlled by the Operation line and, for this example, to
connect 0 directly to the new input of that expanded multiplexor.

Operation

CarryIn

a

b

(cid:31)

CarryOut

0

1

2

Result

FIGURE A.5.6  A 1-bit ALU that performs AND, OR, and addition (see Figure A.5.5).

A 64-Bit ALU

Now  that  we  have  completed  the  1-bit  ALU,  the  full  64-bit  ALU  is  created  by
connecting adjacent “black boxes.” Using xi to mean the ith bit of x, Figure A.5.7
shows a 64-bit ALU. Just as a single stone can cause ripples to radiate to the shores
of a quiet lake, a single carry out of the least significant bit (Result0) can ripple all
the way through the adder, causing a carry out of the most significant bit (Result63).
Hence, the adder created by directly linking the carries of 1-bit adders is called a
ripple  carry  adder.  We’ll  see  a  faster  way  to  connect  the  1-bit  adders  starting  on
page A-38.

Subtraction is the same as adding the negative version of an operand, and this
is  how  adders  perform  subtraction.  Recall  that  the  shortcut  for  negating  a  two’s
complement number is to invert each bit (sometimes called the one’s complement)
and then add 1. To invert each bit, we simply add a 2:1 multiplexor that chooses
between b and b, as Figure A.5.8 shows.

Suppose we connect 64 of these 1-bit ALUs, as we did in Figure A.5.7. The added
multiplexor gives the option of b or its inverted value, depending on Binvert, but

Operation

Result0

Result1

Result2

CarryIn

CarryIn
ALU0
CarryOut

CarryIn
ALU1
CarryOut

CarryIn
ALU2
CarryOut

a0

b0

a1

b1

a2

b2

...

...

...

a63

b63

CarryIn
ALU63

Result63

FIGURE A.5.7  A 64-bit ALU constructed from 64 1-bit ALUs. CarryOut of the less significant bit
is connected to the CarryIn of the more significant bit. This organization is called ripple carry.

Binvert

Operation

CarryIn

a

b

0

1

2

Result

0

1

(cid:31)

CarryOut

FIGURE A.5.8  A 1-bit ALU that performs AND, OR, and addition on a and b or a and b. By
selecting b (Binvert = 1) and setting CarryIn to 1 in the least significant bit of the ALU, we get two’s comple-
ment subtraction of b from a instead of addition of b to a.

A.5  Constructing a Basic Arithmetic Logic Unit

A-31

this is only one step in negating a two’s complement number. Notice that the least
significant bit still has a CarryIn signal, even though it’s unnecessary for addition.
What happens if we set this CarryIn to 1 instead of 0? The adder will then calculate
a + b + 1. By selecting the inverted version of b, we get exactly what we want:

a

b

1

a

(

b

)
1

a

(

)
b

a

b

The simplicity of the hardware design of a two’s complement adder helps explain
why  two’s  complement  representation  has  become  the  universal  standard  for
integer computer arithmetic.

We also wish to add a NOR function. Instead of adding a separate gate for NOR,
we can reuse much of the hardware already in the ALU, like we did for subtract. The
insight comes from the following truth about NOR:

a
(

b
)

a b⋅

That  is,  NOT  (a  OR  b)  is  equivalent  to  NOT  a  AND  NOT  b.  This  fact  is  called
DeMorgan’s theorem and is explored in the exercises in more depth.

Since we have AND and NOT b, we only need to add NOT a to the ALU. Figure

A.5.9 shows that change.

Tailoring the 64-Bit ALU to RISC-V

These four operations—add, subtract, AND, OR—are found in the ALU of almost
every computer, and the operations of most RISC-V instructions can be performed
by this ALU. But the design of the ALU is incomplete.

One instruction that still needs support is the set less than instruction (slt).
Recall that the operation produces 1 if rs1 < rs2, and 0 otherwise. Consequently,
slt  will  set  all  but  the  least  significant  bit  to  0,  with  the  least  significant  bit  set
according to the comparison. For the ALU to perform slt, we first need to expand
the three-input multiplexor in Figure A.5.9 to add an input for the slt result. We
call that new input Less and use it only for slt.

The top drawing of Figure A.5.10 shows the new 1-bit ALU with the expanded
multiplexor.  From  the  description  of  slt  above,  we  must  connect  0  to  the  Less
input for the upper 63 bits of the ALU, since those bits are always set to 0. What
remains to consider is how to compare and set the least significant bit for set less
than instructions.

What happens if we subtract b from a? If the difference is negative, then a < b since

a
(

b
)

< ⇒
0

a
(
(

b

)

+ <
)
b

0
(

b
)

⇒ <
a

b

We want the least significant bit of a set less than operation to be a 1 if a < b;
that is, a 1 if a − b is negative and a 0 if it’s positive. This desired result corresponds
exactly to the sign bit values: 1 means negative and 0 means positive. Following
this line of argument, we need only connect the sign bit from the adder output to
the least significant bit to get set less than. (Alas, this argument only holds if the
subtraction does not overflow; we will explore a complete implementation in the
exercises.)

A-32

Appendix A  The Basics of Logic Design

Ainvert

Operation

Binvert

CarryIn

a

b

0

1

0

1

0

1

2

Result

(cid:31)

CarryOut

FIGURE A.5.9  A 1-bit ALU that performs AND, OR, and addition on a and b or a
selecting a (Ainvert = 1) and b (Binvert = 1), we get a NOR b instead of a AND b.

and b. By

Unfortunately, the Result output from the most significant ALU bit in the top of
Figure A.5.10 for the slt operation is not the output of the adder; the ALU output
for the slt operation is obviously the input value Less.

Thus, we need a new 1-bit ALU for the most significant bit that has an extra
output  bit:  the  adder  output.  The  bottom  drawing  of  Figure  A.5.10  shows  the
design,  with  this  new  adder  output  line  called  Set.  As  long  as  we  need  a  special
ALU for the most significant bit, we added the overflow detection logic since it is
also associated with that bit. Figure A.5.11 shows the 64-bit ALU.

Notice that every time we want the ALU to subtract, we set both CarryIn and
Binvert to 1. For adds or logical operations, we want both control lines to be 0. We
can therefore simplify control of the ALU by combining the CarryIn and Binvert to
a single control line called Bnegate.

To  further  tailor  the  ALU  to  the  RISC-V  instruction  set,  we  must  support
conditional branch instructions such as Branch if Equal (beq), which branches if
two registers are equal. The easiest way to test equality with the ALU is to subtract
b from a and then test to see if the result is 0, since

a
(

b

0 ⇒
)

a

b

A.5  Constructing a Basic Arithmetic Logic Unit

A-33

a

b

Less

a

b

Less

Ainvert

Operation

Binvert

CarryIn

0

1

0

1

(cid:31)

CarryOut

0

1

2

3

Result

Ainvert

Operation

Binvert

CarryIn

0

1

0

1

(cid:31)

Overflow
detection

0

1

2

3

Result

Set

Overflow

FIGURE A.5.10  (Top) A 1-bit ALU that performs AND, OR, and addition on a and b or b, and
(bottom) a 1-bit ALU for the most significant bit. The top drawing includes a direct input that is
connected to perform the set on less than operation (see Figure A.5.11); the bottom has a direct output from
the adder for the less than comparison called Set. (See Exercise A.24 at the end of this appendix to see how
to calculate overflow with fewer inputs.)

A-34

Appendix A  The Basics of Logic Design

Binvert

Ainvert

Operation

CarryIn

CarryIn
ALU0
Less
CarryOut

CarryIn
ALU1
Less
CarryOut

CarryIn
ALU2
Less
CarryOut

a0
b0

a1
b1
0

a2
b2
0

Result0

Result1

Result2

...

...

...

...

...

CarryIn

...

a63
b63
0

CarryIn
ALU63
Less

Set

Result63

Overflow

FIGURE A.5.11  A 64-bit ALU constructed from the 63 copies of the 1-bit ALU in the top of
Figure A.5.10 and one 1-bit ALU in the bottom of that figure. The Less inputs are connected to 0
except for the least significant bit, which is connected to the Set output of the most significant bit. If the ALU
performs a − b and we select the input 3 in the multiplexor in Figure A.5.10, then Result = 0 … 001 if a < b,
and Result = 0 … 000 otherwise.

Thus, if we add hardware to test if the result is 0, we can test for equality. The
simplest way is to OR all the outputs together and then send that signal through
an inverter:

Zero

(
Result

63

Result

62

(cid:31)

Result

2

1
Result

Result

0
)

Figure A.5.12 shows the revised 64-bit ALU. We can think of the combination of
the 1-bit Ainvert line, the 1-bit Bnegate line, and the 2-bit Operation lines as 4-bit
control lines for the ALU, telling it to perform add, subtract, AND, OR, NOR, or

A.5  Constructing a Basic Arithmetic Logic Unit

A-35

Bnegate

Ainvert

Operation

a0
b0

a1
b1
0

a2
b2
0

Result0

Result1

Result2

CarryIn
ALU0
Less
CarryOut

CarryIn
ALU1
Less
CarryOut

CarryIn
ALU2
Less
CarryOut

...

Zero

...

...

...

...

...

CarryIn

...

...

a63
b63
0

CarryIn
ALU63
Less

Result63

Set

Overflow

FIGURE A.5.12  The final 64-bit ALU. This adds a Zero detector to Figure A.5.11.

ALU control lines

Function

0000

0001

0010

0110

0111

1100

AND

OR

add

subtract

set less than

NOR

FIGURE A.5.13  The values of the three ALU control lines, Ainvert, Bnegate, and Operation,
and the corresponding ALU operations.

set  less  than.  Figure  A.5.13  shows  the  ALU  control  lines  and  the  corresponding
ALU operation.

Finally,  now  that  we  have  seen  what  is  inside  a  64-bit  ALU,  we  will  use  the

universal symbol for a complete ALU, as shown in Figure A.5.14.

A-36

Appendix A  The Basics of Logic Design

ALU operation

a

b

ALU

Zero

Result

Overflow

CarryOut

FIGURE  A.5.14  The  symbol  commonly  used  to  represent  an  ALU,  as  shown  in  Figure
A.5.12. This symbol is also used to represent an adder, so it is normally labeled either with ALU or Adder.

FIGURE A.5.15  A Verilog behavioral definition of a RISC-V ALU.

Defining the RISC-V ALU in Verilog

Figure  A.5.15  shows  how  a  combinational  RISC-V  ALU  might  be  specified  in
Verilog; such a specification would probably be compiled using a standard parts
library that provided an adder, which could be instantiated. For completeness, we
show the ALU control for RISC-V in Figure A.5.16, which is used in Chapter 4,
where we build a Verilog version of the RISC-V datapath.

A.6  Faster Addition: Carry Lookahead

A-37

FIGURE A.5.16  The RISC-V ALU control: a simple piece of combinational control logic.

The  next  question  is,  “How  quickly  can  this  ALU  add  two  64-bit  operands?”
We  can  determine  the  a  and  b  inputs,  but  the  CarryIn  input  depends  on  the
operation in the adjacent 1-bit adder. If we trace all the way through the chain of
dependencies,  we  connect  the  most  significant  bit  to  the  least  significant  bit,  so
the most significant bit of the sum must wait for the sequential evaluation of all 64
1-bit adders. This sequential chain reaction is too slow to be used in time-critical
hardware. The next section explores how to speed-up addition. This topic is not
crucial to understanding the rest of the appendix and may be skipped.

Suppose you wanted to add the operation NOT (a AND b), called NAND. How

could the ALU change to support it?

Check
Yourself

1.  No change. You can calculate NAND quickly using the current ALU since

⋅
a b
(

)

a

b

 and we already have NOT a, NOT b, and OR.

2.  You must expand the big multiplexor to add another input, and then add

new logic to calculate NAND.

  A.6

Faster Addition: Carry Lookahead

The key to speeding up addition is determining the carry in to the high-order bits
sooner. There  are  a  variety  of  schemes  to  anticipate  the  carry  so  that  the  worst-
case  scenario  is  a  function  of  the  log2  of  the  number  of  bits  in  the  adder. These

A-38

Appendix A  The Basics of Logic Design

anticipatory signals are faster because they go through fewer gates in sequence, but
it takes many more gates to anticipate the proper carry.

A key to understanding fast-carry schemes is to remember that, unlike software,

hardware executes in parallel whenever inputs change.

Fast Carry Using “Infinite” Hardware

As we mentioned earlier, any equation can be represented in two levels of logic.
Since the only external inputs are the two operands and the CarryIn to the least
significant bit of the adder, in theory we could calculate the CarryIn values to all
the remaining bits of the adder in just two levels of logic.

For example, the CarryIn for bit 2 of the adder is exactly the CarryOut of bit 1,

so the formula is

CarryIn

2

(

)
1
b CarryIn
1

⋅

)
1
(
a CarryIn
1

⋅

(
1
a

⋅

)
1
b

Similarly, CarryIn1 is defined as

1
CarryIn

(

)
0
b CarryIn
0

⋅

)
0
(
a CarryIn
0

⋅

(
a

0

⋅

)
0
b

Using  the  shorter  and  more  traditional  abbreviation  of  ci  for  CarryIni,  we  can
rewrite the formulas as

2
c
1
c

(
1
b
(
b
0

⋅
⋅

)
1
c
)
0
c

(
a
1
(
a
0

⋅
)
1
c
⋅
)
0
c

⋅

(
a
1
(
a
0

)
1
b
⋅
)
0
b

Substituting the definition of c1 for the first equation results in this formula:

c

2

(
a
1
(

⋅

a
1
b

⋅

0
⋅
a

)
0
b
⋅
)
0
b
0

(
a
1
(

⋅

a
1
b

0
⋅

⋅

a

)
0
c
⋅
c
0

)
0

(
a
1
((

⋅

0
b
⋅
1
b

⋅

c
0
b

)
0
⋅
c

0
)

1
a
(

⋅

1
)
b

You can imagine how the equation expands as we get to higher bits in the adder;
it grows rapidly with the number of bits. This complexity is reflected in the cost of
the hardware for fast carry, making this simple scheme prohibitively expensive for
wide adders.

Fast Carry Using the First Level of Abstraction: Propagate
and Generate

Most  fast-carry  schemes  limit  the  complexity  of  the  equations  to  simplify  the
hardware,  while  still  making  substantial  speed  improvements  over  ripple  carry.
One  such  scheme  is  a  carry-lookahead  adder.  In  Chapter  1,  we  said  computer
systems  cope  with  complexity  by  using  levels  of  abstraction.  A  carry-lookahead
adder relies on levels of abstraction in its implementation.

A.6  Faster Addition: Carry Lookahead

A-39

Let’s factor our original equation as a first step:

c

i

1

(
i
b
(
a
i

⋅
⋅

i
c
i
b

)
)

(
i
a
(
a
i

⋅

)
i
c
b
i

⋅

)

(
i
a
c
i

⋅

b

i

)

If we were to rewrite the equation for c2 using this formula, we would see some
repeated patterns:

2
c

(
a
1

⋅

)
1
b

(
a
1

⋅

⋅
) ((
a
1
b

0

⋅

)
0
b

(
a

0

)
0
b

⋅

c

)
0

Note the repeated appearance of (ai · bi) and (ai + bi) in the formula above. These
two important factors are traditionally called generate (gi) and propagate (pi):

g
p

i
i

⋅

a
i
i
a

i
b
b

i

Using them to define ci + 1, we get

c

i

1

i
g

p

i

⋅

i
c

To see where the signals get their names, suppose gi is 1. Then

c

i

1

i
g

p

i

⋅

i
c

1

p

i

⋅

i
c

1

That  is,  the  adder  generates  a  CarryOut  (ci + 1)  independent  of  the  value  of
CarryIn (ci). Now suppose that gi is 0 and pi is 1. Then

c

i

1

i
g

p

i

⋅

i
c

0

1

⋅

i
c

i
c

That  is,  the  adder  propagates  CarryIn  to  a  CarryOut.  Putting  the  two  together,
CarryIni + 1 is a 1 if either gi is 1 or both pi is 1 and CarryIni is 1.

As an analogy, imagine a row of dominoes set on edge. The end domino can be
tipped over by pushing one far away, provided there are no gaps between the two.
Similarly,  a  carry  out  can  be  made  true  by  a  generate  far  away,  provided  all  the
propagates between them are true.

Relying  on  the  definitions  of  propagate  and  generate  as  our  first  level  of
abstraction, we can express the CarryIn signals more economically. Let’s show it
for 4 bits:

c
1
2
c
c
3
4
c

g
0
1
g
2
g
3
g

⋅
0
(
p
0
)
c
⋅
(
p
1
)
0
g
⋅
)
(
g
p
2
1
⋅
)
(
2
3
g
p

(
1
p
p
2
(
3
p
(
3
p
((

⋅
⋅
⋅
⋅

0
p
1
p
2
p
2
p

⋅
)
0
c
⋅ gg
)
0
⋅
1
g
)
⋅
1
p

⋅

⋅
⋅

0
p
1
p

⋅
⋅

)
0
c
)
0
g

(
2
p
p
3
(
⋅
0
c
p

⋅
⋅

1
p
p
2
0
)

A-40

Appendix A  The Basics of Logic Design

These equations just represent common sense: CarryIni is a 1 if some earlier adder
generates a carry and all intermediary adders propagate a carry. Figure A.6.1 uses
plumbing to try to explain carry lookahead.

Even this simplified form leads to large equations and, hence, considerable logic

even for a 16-bit adder. Let’s try moving to two levels of abstraction.

Fast Carry Using the Second Level of Abstraction

First, we consider this 4-bit adder with its carry-lookahead logic as a single building
block. If we connect them in ripple carry fashion to form a 16-bit adder, the add
will be faster than the original with a little more hardware.

To  go  faster,  we’ll  need  carry  lookahead  at  a  higher  level.  To  perform  carry
lookahead for 4-bit adders, we need to propagate and generate signals at this higher
level. Here they are for the four 4-bit adder blocks:

P
0
1
P
2
P
3
P

(cid:31)
(cid:31)
(cid:31)
(cid:31)

⋅
⋅

p
3
7
p
11
p
15
p

⋅
⋅

⋅
⋅

p
p
p
0
1
2
p
p
p
4
5
6
⋅
⋅
⋅
8
9
10
p
p
p
⋅⋅ p12
⋅
⋅
13
14
p
p

That is, the “super” propagate signal for the 4-bit abstraction (Pi) is true only if each
of the bits in the group will propagate a carry.

For the “super” generate signal (Gi), we care only if there is a carry out of the
most  significant  bit  of  the  4-bit  group.  This  obviously  occurs  if  generate  is  true
for that most significant bit; it also occurs if an earlier generate is true and all the
intermediate propagates, including that of the most significant bit, are also true:

0
G
G
1
2
G
3
G

3
g
g
7
11
g
15
g

⋅
⋅⋅

⋅
⋅

⋅
⋅

p
)
2
(
3
g
p
)
g
6
(
7
⋅
)
10
(
11
g
p
⋅
)
(
14
g
15
p

p
(
3
2
p
7
(
p
p
6
⋅
(
11
p
⋅
(
15
p

)
1
g
g
)
5
10
p
14
p

⋅
⋅

p
3
(
p
(
7
)
9
g
)
13
g

⋅
⋅

⋅

⋅
⋅

2
p
p
6
(
11
p
(
15
p

0
1
p
g
)
⋅
g
p
4
)
5
⋅
⋅
9
pp
g
10
p
⋅
⋅
13
p
14
p

⋅

)
8
⋅
)
12
g

Figure A.6.2 updates our plumbing analogy to show P0 and G0.

Then the equations at this higher level of abstraction for the carry in for each
4-bit group of the 16-bit adder (C1, C2, C3, C4 in Figure A.6.3) are very similar to
the carry out equations for each bit of the 4-bit adder (c1, c2, c3, c4) on page A-40:

1
C
2
C
C
3
4
C

0
G
1
G
G
2
3
G

⋅
)
0
(
P
c
0
⋅
P G
)
0
(
1
⋅
P G
)
(
1
2
⋅
)
(
2
3
P G

⋅
⋅
0
c
)
P P
(
0
1
⋅ GG
⋅
)
0
(
2
P
P
1
2
(
P
⋅
⋅
P
)
P G
(
3
3
1
P
(
2
⋅
⋅
⋅
⋅
(
0
1
2
3
c
P P
P
PP

⋅
⋅

⋅
⋅
)
0
0
1
P P
c
⋅
⋅
P
P G
)
0
1
2
)
0

A.6  Faster Addition: Carry Lookahead

A-41

c0

p0

c0

p0

g0

c0

p0

p1

g1

p1

p2

p3

g0

g1

g3

c1

c2

c4

g0

g2

FIGURE A.6.1  A plumbing analogy for carry lookahead for 1 bit, 2 bits, and 4 bits using
water pipes and valves. The wrenches are turned to open and close valves. Water is shown in color. The
output of the pipe (ci + 1) will be full if either the nearest generate value (gi) is turned on or if the i propagate
value (pi) is on and there is water further upstream, either from an earlier generate or a propagate with water
behind it. CarryIn (c0) can result in a carry out without the help of any generates, but with the help of all
propagates.

A-42

Appendix A  The Basics of Logic Design

p0

g0

p1

p2

p1

p2

P0

p3

g1

g2

p3

g3

G0

FIGURE A.6.2  A plumbing analogy for the next-level carry-lookahead signals P0 and G0.
P0 is open only if all four propagates (pi) are open, while water flows in G0 only if at least one generate (gi) is
open and all the propagates downstream from that generate are open.

Figure A.6.3 shows 4-bit adders connected with such a carry-lookahead unit.
The exercises explore the speed differences between these carry schemes, different
notations for multibit propagate and generate signals, and the design of a 64-bit
adder.

A.6  Faster Addition: Carry Lookahead

A-43

CarryIn

CarryIn

ALU0

  P0
  G0

CarryIn

ALU1

  P1
  G1

CarryIn

ALU2

  P2
  G2

CarryIn

ALU3

  P3
  G3

a0
b0
a1
b1
a2
b2
a3
b3

a4
b4
a5
b5
a6
b6
a7
b7

a8
b8
a9
b9
a10
b10
a11
b11

a12
b12
a13
b13
a14
b14
a15
b15

pi
gi

C1

ci + 1

pi + 1
gi + 1

ci + 2

C2

pi + 2
gi + 2

ci + 3

C3

pi + 3
gi + 3

ci + 4

C4

Result0–3

Carry-lookahead unit

Result4–7

Result8–11

Result12–15

CarryOut

FIGURE A.6.3  Four 4-bit ALUs using carry lookahead to form a 16-bit adder. Note that the
carries come from the carry-lookahead unit, not from the 4-bit ALUs.

A-44

Appendix A  The Basics of Logic Design

EXAMPLE

Both Levels of the Propagate and Generate

Determine the gi, pi, Pi, and Gi values of these two 16-bit numbers:

a:       0001  1010  0011  0011two
b:       1110  0101  1110  1011two

Also, what is CarryOut15 (C4)?

ANSWER

Aligning  the  bits  makes  it  easy  to  see  the  values  of  generate  gi  (ai·bi)  and
propagate pi (ai + bi):

a:       0001  1010  0011  0011
b:       1110  0101  1110  1011
gi:      0000  0000  0010  0011
pi:      1111  1111  1111  1011

where  the  bits  are  numbered  15  to  0  from  left  to  right.  Next,  the  “super”
propagates (P3, P2, P1, P0) are simply the AND of the lower-level propagates:

P
3
2
P
P
1
0
P

(cid:31)
(cid:31)
(cid:31)
(cid:31)

⋅
⋅
1 1 11
⋅
⋅
1 1 1 1
⋅
⋅
1 1 1 1
⋅
⋅
1 0 1 1

⋅
⋅
⋅
⋅

(cid:31)
1
(cid:31)
(cid:31)
(cid:31)

1
1
0

The “super” generates are more complex, so use the following equations:

G

0

G
1

G

2

GG

3

7

3

g
0
g
0
g
11
0
15
g
0

⋅

⋅

⋅

p
(
3
⋅
1 0
)
(
⋅
p
(
7
⋅
1 0
)
((
p
11
(
⋅
)
1 0
(
(
15
p
⋅
1 0
)
(

g

g

⋅

⋅

⋅

⋅

p
(
)
g
1
3
2
p
p
3
2
(
)
⋅ 00 1 1
⋅
⋅
⋅
)
1
(
1 0 1
(
)
⋅
p
g
p
(
p
)
7
5
6
(
)
7
6
⋅
⋅
⋅
⋅
)
1 1 1 0
(
(
1 1 1
)
⋅
g
)
g
p 00
9
p
11
(
10
)
1
⋅
⋅
⋅
⋅
⋅
1 1 1 0
)
1 1 0
(
)
(
⋅
)
13
(
)
14
15
p
14
g
p
g
⋅
⋅
⋅
⋅
⋅
1 1 1 0
1 1 0
(
((
)
)

⋅

⋅

⋅

⋅

⋅

⋅

⋅

p
2
0
p
6
0
(
p
11
0
(
0

0

⋅

p
1
0
p
5
0
⋅

g
)
0
00
g
4
1
p
10

⋅

⋅

)
0
p
9

1
)
8

⋅

)
12
g

⋅

g
0
13
p
0

0
15
p
0

⋅

00
14
p
00

⋅

Finally, CarryOut15 is

C

4

G

3

0
0

⋅

⋅
P
)
P G
(
2
(
3
3
⋅
⋅
⋅
P P
P
2
P
3
(
0
1
⋅
⋅
⋅
1 1 1
1 0
(
)
((
)
0
0
1
0

1

⋅
P G
)
1
2
⋅
0
c
)
⋅
⋅
1 1 1 0
)
(

⋅

(
P
3

⋅

2
P

⋅

⋅
P G
1

)
0

⋅
1 1 1 0 0
(
)

⋅

⋅

⋅

Hence, there is a carry out when adding these two 16-bit numbers.

A.6  Faster Addition: Carry Lookahead

A-45

The  reason  carry  lookahead  can  make  carries  faster  is  that  all  logic  begins
evaluating the moment the clock cycle begins, and the result will not change once
the output of each gate stops changing. By taking the shortcut of going through
fewer gates to send the carry in signal, the output of the gates will stop changing
sooner, and hence the time for the adder can be less.

To  appreciate  the  importance  of  carry  lookahead,  we  need  to  calculate  the

relative performance between it and ripple carry adders.

Speed of Ripple Carry versus Carry Lookahead

One simple way to model time for logic is to assume each AND or OR gate
takes the same time for a signal to pass through it. Time is estimated by simply
counting the number of gates along the path through a piece of logic. Compare
the number of gate delays for paths of two 16-bit adders, one using ripple carry
and one using two-level carry lookahead.

EXAMPLE

Figure  A.5.5  on  page  A-28  shows  that  the  carry  out  signal  takes  two  gate
delays per bit. Then the number of gate delays between a carry in to the least
significant bit and the carry out of the most significant is 32 × 2 = 64.

ANSWER

For  carry  lookahead,  the  carry  out  of  the  most  significant  bit  is  just  C4,
defined in the example. It takes two levels of logic to specify C4 in terms of
Pi and Gi (the OR of several AND terms). Pi is specified in one level of logic
(AND) using pi, and Gi is specified in two levels using pi and gi, so the worst
case for this next level of abstraction is two levels of logic. pi and gi are each
one level of logic, defined in terms of ai and bi. If we assume one gate delay for
each level of logic in these equations, the worst case is 2 + 2 + 1 = 5 gate delays.
Hence,  for  the  path  from  carry  in  to  carry  out,  the  16-bit  addition  by  a
carry-lookahead  adder  is  six  times  faster,  using  this  very  simple  estimate  of
hardware speed.

Summary

Carry lookahead offers a faster path than waiting for the carries to ripple through
all 32 1-bit adders. This faster path is paved by two signals, generate and propagate.

A-46

Appendix A  The Basics of Logic Design

The former creates a carry regardless of the carry input, and the latter passes a carry
along. Carry lookahead also gives another example of how abstraction is important
in computer design to cope with complexity.

Check
Yourself

Using the simple estimate of hardware speed above with gate delays, what is the
relative performance of a ripple carry 8-bit add versus a 64-bit add using carry-
lookahead logic?

1.  A 64-bit carry-lookahead adder is three times faster: 8-bit adds are 16 gate

delays and 64-bit adds are seven gate delays.

2.  They are about the same speed, since 64-bit adds need more levels of logic in

the 16-bit adder.

3.  Eight-bit adds are faster than 64 bits, even with carry lookahead.

Elaboration:  We  have  now  accounted  for  all  but  one  of  the  arithmetic  and  logical
operations for the core RISC-V instruction set: the ALU in Figure A.5.14 omits support of
shift instructions. It would be possible to widen the ALU multiplexor to include a left shift
by 1 bit or a right shift by 1 bit. But hardware designers have created a circuit called a
barrel shifter, which can shift from 1 to 63 bits in no more time than it takes to add two
64-bit numbers, so shifting is normally done outside the ALU.

Elaboration:  The logic equation for the Sum output of the full adder on page A-28 can
be expressed more simply by using a more powerful gate than AND and OR. An exclusive
OR gate is true if the two operands disagree; that is,

x

y
≠ ⇒

1

and

x

y
== ⇒

0

In some technologies, exclusive OR is more efficient than two levels of AND and OR

gates. Using the symbol ⊕ to represent exclusive OR, here is the new equation:

Sum a

(cid:31) ⊕ ⊕

b

CarryIn

Also, we have drawn the ALU the traditional way, using gates. Computers are designed
today in CMOS transistors, which are basically switches. CMOS ALU and barrel shifters
take advantage of these switches and have many fewer multiplexors than shown in our
designs, but the design principles are similar.

Elaboration:  Using lowercase and uppercase to distinguish the hierarchy of generate
and propagate symbols breaks down when you have more than two levels. An alternate
notation that scales is gi..j and pi..j for the generate and propagate signals for bits i to j.
Thus, g1..1 is generated for bit 1, g4..1 is for bits 4 to 1, and g16..1 is for bits 16 to 1.

A.7  Clocks

A-47

  A.7  Clocks

Before  we  discuss  memory  elements  and  sequential  logic,  it  is  useful  to  discuss
briefly  the  topic  of  clocks. This  short  section  introduces  the  topic  and  is  similar
to  the  discussion  found  in  Section  4.2.  More  details  on  clocking  and  timing
methodologies are presented in Section A.11.

Clocks are needed in sequential logic to decide when an element that contains
state should be updated. A clock is simply a free-running signal with a fixed cycle
time; the clock frequency is simply the inverse of the cycle time. As shown in Figure
A.7.1, the clock cycle time or  clock period is divided into two portions: when the
clock is high and when the clock is low. In this text, we use only edge-triggered
clocking.  This  means  that  all  state  changes  occur  on  a  clock  edge.  We  use  an
edge-triggered  methodology  because  it  is  simpler  to  explain.  Depending  on  the
technology, it may or may not be the best choice for a clocking methodology.

Falling edge

Clock period

Rising edge

FIGURE A.7.1  A clock signal oscillates between high and low values. The clock period is the
time for one full cycle. In an edge-triggered design, either the rising or falling edge of the clock is active and
causes state to be changed.

edge-triggered
clocking  A clocking
scheme in which all state
changes occur on a clock
edge.

clocking
methodology  The
approach used to
determine when data are
valid and stable relative to
the clock.

In an edge-triggered methodology, either the rising edge or the falling edge of
the  clock  is  active  and  causes  state  changes  to  occur.  As  we  will  see  in  the  next
section, the state elements in an edge-triggered design are implemented so that the
contents of the state elements only change on the active clock edge. The choice of
which edge is active is influenced by the implementation technology and does not
affect the concepts involved in designing the logic.

The clock edge acts as a sampling signal, causing the value of the data input to a
state element to be sampled and stored in the state element. Using an edge trigger
means that the sampling process is essentially instantaneous, eliminating problems
that could occur if signals were sampled at slightly different times.

The major constraint in a clocked system, also called a synchronous system, is
that the signals that are written into state elements must be valid when the active

state element
A memory element.

synchronous system  A
memory system that
employs clocks and where
data signals are read only
when the clock indicates
that the signal values are
stable.

A-48

Appendix A  The Basics of Logic Design

clock edge occurs. A signal is valid if it is stable (i.e., not changing), and the value
will not change again until the inputs change. Since combinational circuits cannot
have  feedback,  if  the  inputs  to  a  combinational  logic  unit  are  not  changed,  the
outputs will eventually become valid.

Figure  A.7.2  shows  the  relationship  among  the  state  elements  and  the
combinational  logic  blocks  in  a  synchronous,  sequential  logic  design.  The  state
elements,  whose  outputs  change  only  after  the  clock  edge,  provide  valid  inputs
to the combinational logic block. To ensure that the values written into the state
elements  on  the  active  clock  edge  are  valid,  the  clock  must  have  a  long  enough
period so that all the signals in the combinational logic block stabilize, and then the
clock edge samples those values for storage in the state elements. This constraint
sets a lower bound on the length of the clock period, which must be long enough
for all state element inputs to be valid.

In the rest of this appendix, as well as in Chapter 4, we usually omit the clock
signal, since we are assuming that all state elements are updated on the same clock
edge. Some state elements will be written on every clock edge, while others will be
written only under certain conditions (such as a register being updated). In such
cases, we will have an explicit write signal for that state element. The write signal
must still be gated with the clock so that the update occurs only on the clock edge if
the write signal is active. We will see how this is done and used in the next section.
One  other  advantage  of  an  edge-triggered  methodology  is  that  it  is  possible
to  have  a  state  element  that  is  used  as  both  an  input  and  output  to  the  same
combinational  logic  block,  as  shown  in  Figure  A.7.3.  In  practice,  care  must  be
taken to prevent races in such situations and to ensure that the clock period is long
enough; this topic is discussed further in Section A.11.

Now that we have discussed how clocking is used to update state elements, we

can discuss how to construct the state elements.

State
element
1

Combinational logic

State
element
2

Clock cycle

FIGURE A.7.2  The inputs to a combinational logic block come from a state element, and
the outputs are written into a state element. The clock edge determines when the contents of the
state elements are updated.

A.7  Memory Elements: Flip-Flops, Latches, and Registers

A-49

State
element

Combinational logic

FIGURE  A.7.3  An  edge-triggered  methodology  allows  a  state  element  to  be  read  and
written in the same clock cycle without creating a race that could lead to undetermined
data values. Of course, the clock cycle must still be long enough so that the input values are stable when
the active clock edge occurs.

Elaboration  Occasionally,  designers  find  it  useful  to  have  a  small  number  of  state
elements that change on the opposite clock edge from the majority of the state elements.
Doing  so  requires  extreme  care,  because  such  an  approach  has  effects  on  both  the
inputs and the outputs of the state element. Why then would designers ever do this?
Consider  the  case  where  the  amount  of  combinational  logic  before  and  after  a  state
element is small enough so that each could operate in one-half clock cycle, rather than
the more usual full clock cycle. Then the state element can be written on the clock edge
corresponding to a half clock cycle, since the inputs and outputs will both be usable
after one-half clock cycle. One common place where this technique is used is in register
files, where simply reading or writing the register file can often be done in half the normal
clock cycle. Chapter 4 makes use of this idea to reduce the pipelining overhead.

register file  A state
element that consists
of a set of registers that
can be read and written
by supplying a register
number to be accessed.

  A.8  Memory Elements: Flip-Flops, Latches,

and Registers

In  this  section  and  the  next,  we  discuss  the  basic  principles  behind  memory
elements,  starting  with  flip-flops  and  latches,  moving  on  to  register  files,  and
finishing  with  memories.  All  memory  elements  store  state:  the  output  from  any
memory element depends both on the inputs and on the value that has been stored
inside the memory element. Thus all logic blocks containing a memory element
contain state and are sequential.

R

S

Q

Q

FIGURE  A.8.1  A  pair  of  cross-coupled  NOR  gates  can  store  an  internal  value.  The value
stored on the output Q is recycled by inverting it to obtain Q and then inverting Q to obtain Q. If either R or
Q is asserted, Q will be deasserted and vice versa.

A-50

Appendix A  The Basics of Logic Design

The simplest type of memory elements are unclocked; that is, they do not have
any clock input. Although we only use clocked memory elements in this text, an
unclocked latch is the simplest memory element, so let’s look at this circuit first.
Figure A.8.1 shows an S-R latch (set-reset latch), built from a pair of NOR gates
(OR gates with inverted outputs). The outputs Q and Q represent the value of the
stored  state  and  its  complement.  When  neither  S  nor  R  are  asserted,  the  cross-
coupled NOR gates act as inverters and store the previous values of Q and Q.

For example, if the output, Q, is true, then the bottom inverter produces a false
output (which is Q), which becomes the input to the top inverter, which produces
a  true  output,  which  is  Q,  and  so  on.  If  S  is  asserted,  then  the  output  Q  will  be
asserted and Q will be deasserted, while if R is asserted, then the output Q will be
asserted and Q will be deasserted. When S and R are both deasserted, the last values
of Q and Q will continue to be stored in the cross-coupled structure. Asserting S
and R simultaneously can lead to incorrect operation: depending on how S and R
are deasserted, the latch may oscillate or become metastable (this is described in
more detail in Section A.11).

This cross-coupled structure is the basis for more complex memory elements
that allow us to store data signals. These elements contain additional gates used to
store signal values and to cause the state to be updated only in conjunction with a
clock. The next section shows how these elements are built.

Flip-Flops and Latches

Flip-flops and latches are the simplest memory elements. In both flip-flops and
latches,  the  output  is  equal  to  the  value  of  the  stored  state  inside  the  element.
Furthermore, unlike the S-R latch described above, all the latches and flip-flops we
will use from this point on are clocked, which means that they have a clock input
and the change of state is triggered by that clock. The difference between a flip-flop
and a latch is the point at which the clock causes the state to actually change. In a
clocked latch, the state is changed whenever the appropriate inputs change and the
clock is asserted, whereas in a flip-flop, the state is changed only on a clock edge.
Since  throughout  this  text  we  use  an  edge-triggered  timing  methodology  where
state is only updated on clock edges, we need only use flip-flops. Flip-flops are often
built from latches, so we start by describing the operation of a simple clocked latch
and then discuss the operation of a flip-flop constructed from that latch.

For  computer  applications,  the  function  of  both  flip-flops  and  latches  is  to
store a signal. A D latch or D flip-flop stores the value of its data input signal in
the internal memory. Although there are many other types of latch and flip-flop,
the D type is the only basic building block that we will need. A D latch has two
inputs and two outputs. The inputs are the data value to be stored (called D) and
a  clock  signal  (called  C)  that  indicates  when  the  latch  should  read  the  value  on
the D input and store it. The outputs are simply the value of the internal state (Q)

flip-flop  A memory
element for which the
output is equal to the
value of the stored state
inside the element and for
which the internal state is
changed only on a clock
edge.

latch  A memory element
in which the output is
equal to the value of the
stored state inside the
element and the state is
changed whenever the
appropriate inputs change
and the clock is asserted.

D flip-flop  A flip-flop
with one data input
that stores the value of
that input signal in the
internal memory when
the clock edge occurs.

A.7  Memory Elements: Flip-Flops, Latches, and Registers

A-51

and its complement (Q). When the clock input C is asserted, the latch is said to be
open, and the value of the output (Q) becomes the value of the input D. When the
clock input C is deasserted, the latch is said to be closed, and the value of the output
(Q) is whatever value was stored the last time the latch was open.

Figure A.8.2 shows how a D latch can be implemented with two additional gates
added to the cross-coupled NOR gates. Since when the latch is open the value of Q
changes as D changes, this structure is sometimes called a transparent latch. Figure
A.8.3 shows how this D latch works, assuming that the output Q is initially false
and that D changes first.

As mentioned earlier, we use flip-flops as the basic building block, rather than
latches. Flip-flops are not transparent: their outputs change only on the clock edge.
A flip-flop can be built so that it triggers on either the rising (positive) or falling
(negative) clock edge; for our designs we can use either type. Figure A.8.4 shows
how a falling-edge D flip-flop is constructed from a pair of D latches. In a D flip-
flop, the output is stored when the clock edge occurs. Figure A.8.5 shows how this
flip-flop operates.

C

D

Q

Q

FIGURE A.8.2  A D latch implemented with NOR gates. A NOR gate acts as an inverter if the other
input is 0. Thus, the cross-coupled pair of NOR gates acts to store the state value unless the clock input, C, is
asserted, in which case the value of input D replaces the value of Q and is stored. The value of input D must
be stable when the clock signal C changes from asserted to deasserted.

D

C

Q

FIGURE A.8.3  Operation of a D latch, assuming the output is initially deasserted. When
the clock, C, is asserted, the latch is open and the Q output immediately assumes the value of the D input.

A-52

Appendix A  The Basics of Logic Design

Q

D
latch

D

C

D

C

D
latch

Q

Q

Q

Q

D

C

FIGURE A.8.4  A D flip-flop with a falling-edge trigger. The first latch, called the master, is open and
follows the input D when the clock input, C, is asserted. When the clock input, C, falls, the first latch is closed, but
the second latch, called the slave, is open and gets its input from the output of the master latch.

D

C

Q

FIGURE A.8.5  Operation of a D flip-flop with a falling-edge trigger, assuming the output is
initially deasserted. When the clock input (C) changes from asserted to deasserted, the Q output stores
the value of the D input. Compare this behavior to that of the clocked D latch shown in Figure A.8.3. In a
clocked latch, the stored value and the output, Q, both change whenever C is high, as opposed to only when
C transitions.

Here is a Verilog description of a module for a rising-edge D flip-flop, assuming

that C is the clock input and D is the data input:

module DFF(clock,D,Q,Qbar);
    input clock, D;
    output reg Q;
    output Qbar;
    assign Qbar= ~ Q;
    always @(posedge clock)
       Q=D;
endmodule

Because the D input is sampled on the clock edge, it must be valid for a period
of  time  immediately  before  and  immediately  after  the  clock  edge.  The  minimum
time that the input must be valid before the clock edge is called the setup time; the

setup time  The
minimum time that the
input to a memory device
must be valid before the
clock edge.

A.7  Memory Elements: Flip-Flops, Latches, and Registers

A-53

D

C

Setup time

Hold time

FIGURE A.8.6  Setup and hold time requirements for a D flip-flop with a falling-edge trigger.
The  input  must  be  stable  for  a  period  of  time  before  the  clock  edge,  as  well  as  after  the  clock  edge.  The
minimum time the signal must be stable before the clock edge is called the setup time, while the minimum
time the signal must be stable after the clock edge is called the hold time. Failure to meet these minimum
requirements can result in a situation where the output of the flip-flop may not be predictable, as described
in Section A.11. Hold times are usually either 0 or very small and thus not a cause of worry.

minimum time during which it must be valid after the clock edge is called the hold
time. Thus the inputs to any flip-flop (or anything built using flip-flops) must be valid
during a window that begins at time tsetup before the clock edge and ends at thold after
the clock edge, as shown in Figure A.8.6. Section A.11 talks about clocking and timing
constraints, including the propagation delay through a flip-flop, in more detail.

We can use an array of D flip-flops to build a register that can hold a multibit datum,

such as a byte or word. We used registers throughout our datapaths in Chapter 4.

hold time  The minimum
time during which the
input must be valid after
the clock edge.

Register Files

One structure that is central to our datapath is a register file. A register file consists
of a set of registers that can be read and written by supplying a register number to be
accessed. A register file can be implemented with a decoder for each read or write
port and an array of registers built from D flip-flops. Because reading a register
does not change any state, we need only supply a register number as an input, and
the only output will be the data contained in that register. For writing a register we
will need three inputs: a register number, the data to write, and a clock that controls
the writing into the register. In Chapter 4, we used a register file that has two read
ports and one write port. This register file is drawn as shown in Figure A.8.7. The
read ports can be implemented with a pair of multiplexors, each of which is as wide
as the number of bits in each register of the register file. Figure A.8.8 shows the
implementation of two register read ports for a 64-bit-wide register file.

Implementing the write port is slightly more complex, since we can only change
the contents of the designated register. We can do this by using a decoder to generate
a signal that can be used to determine which register to write. Figure A.8.9 shows
how to implement the write port for a register file. It is important to remember that
the flip-flop changes state only on the clock edge. In Chapter 4, we hooked up write
signals for the register file explicitly and assumed the clock shown in Figure A.8.9
is attached implicitly.

What  happens  if  the  same  register  is  read  and  written  during  a  clock  cycle?
Because the write of the register file occurs on the clock edge, the register will be

A-54

Appendix A  The Basics of Logic Design

Read register
number 1

Read register
number 2

Write
register

Write
data

Register file

Write

Read
data 1

Read
data 2

FIGURE A.8.7  A register file with two read ports and one write port has five inputs and
two outputs. The control input Write is shown in color.

Read register
number 1

Read register
number 2

Register 0

Register 1

. . .

Register n – 2

Register n – 1

M

u

x

M

u

x

Read data 1

Read data 2

FIGURE A.8.8  The implementation of two read ports for a register file with n registers
can be done with a pair of n-to-1 multiplexors, each 64 bits wide. The register read number
signal is used as the multiplexor selector signal. Figure A.8.9 shows how the write port is implemented.

A.7  Memory Elements: Flip-Flops, Latches, and Registers

A-55

Write

Register number

0
1

n-to-2n
decoder

.
..

n – 2

n – 1

Register data

C

D

C

D

C

D

C

D

Register 0

Register 1

.
.
.

Register n – 2

Register n – 1

FIGURE A.8.9  The write port for a register file is implemented with a decoder that is used
with  the  write  signal  to  generate  the  C  input  to  the  registers.  All three inputs (the register
number, the data, and the write signal) will have setup and hold-time constraints that ensure that the correct
data are written into the register file.

valid during the time it is read, as we saw earlier in Figure A.7.2. The value returned
will be the value written in an earlier clock cycle. If we want a read to return the
value currently being written, additional logic in the register file or outside of it is
needed. Chapter 4 makes extensive use of such logic.

Specifying Sequential Logic in Verilog

To  specify  sequential  logic  in  Verilog,  we  must  understand  how  to  generate  a
clock, how to describe when a value is written into a register, and how to specify
sequential control. Let us start by specifying a clock. A clock is not a predefined
object  in  Verilog;  instead,  we  generate  a  clock  by  using  the  Verilog  notation  #n
before a statement; this causes a delay of n simulation time steps before the execu-
tion  of  the  statement.  In  most  Verilog  simulators,  it  is  also  possible  to  generate
a  clock  as  an  external  input,  allowing  the  user  to  specify  at  simulation  time  the
number of clock cycles during which to run a simulation.

The code in Figure A.8.10 implements a simple clock that is high or low for one
simulation unit and then switches state. We use the delay capability and blocking
assignment to implement the clock.

A-56

Appendix A  The Basics of Logic Design

reg clock;
always #1 clock = ~clock;

FIGURE A.8.10  A specification of a clock.

Next, we must be able to specify the operation of an edge-triggered register. In
Verilog, this is done by using the sensitivity list on an always block and specifying
as  a  trigger  either  the  positive  or  negative  edge  of  a  binary  variable  with  the
notation  posedge  or  negedge,  respectively.  Hence,  the  following  Verilog  code
causes register A to be written with the value b at the positive edge clock:

FIGURE A.8.11  A RISC-V register file written in behavioral Verilog. This register file writes on
the rising clock edge.

Throughout this chapter and the Verilog sections of Chapter 4, we will assume
a  positive  edge-triggered  design.  Figure  A.8.11  shows  a  Verilog  specification  of
a RISC-V register file that assumes two reads and one write, with only the write
being clocked.

A.9  Memory Elements: SRAMs and DRAMs

A-57

In the Verilog for the register file in Figure A.8.11, the output ports corresponding to
the registers being read are assigned using a continuous assignment, but the register
being written is assigned in an always block. Which of the following is the reason?

Check
Yourself

a.  There is no special reason. It was simply convenient.

b.  Because Data1 and Data2 are output ports and WriteData is an input port.

c.  Because reading is a combinational event, while writing is a sequential event.

  A.9  Memory Elements: SRAMs and DRAMs

Registers and register files provide the basic building blocks for small memories,
but  larger  amounts  of  memory  are  built  using  either  SRAMs  (static  random
access memories) or DRAMs (dynamic random access memories). We first discuss
SRAMs, which are somewhat simpler, and then turn to DRAMs.

SRAMs

SRAMs are simply integrated circuits that are memory arrays with (usually) a single
access port that can provide either a read or a write. SRAMs have a fixed access
time to any datum, though the read and write access characteristics often differ.
An SRAM chip has a specific configuration in terms of the number of addressable
locations, as well as the width of each addressable location. For example, a 4M × 8
SRAM provides 4M entries, each of which is 8 bits wide. Thus it will have 22 address
lines (since 4M = 222), an 8-bit data output line, and an 8-bit single data input line.
As with ROMs, the number of addressable locations is often called the height, with
the number of bits per unit called the width. For a variety of technical reasons, the
newest and fastest SRAMs are typically available in narrow configurations: × 1 and
× 4. Figure A.9.1 shows the input and output signals for a 2M × 16 SRAM.

static random access
memory (SRAM)
A memory where data
are stored statically
(as in flip-flops) rather
than dynamically (as
in DRAM). SRAMs are
faster than DRAMs,
but less dense and more
expensive per bit.

21

Address

Chip select

Output enable

Write enable

Din[15–0]

16

SRAM
2M (cid:31) 16

16

Dout[15–0]

FIGURE  A.9.1  A  32K  × 8  SRAM  showing  the  21  address  lines  (32K  =  215)  and  16  data
inputs, the three control lines, and the 16 data outputs.

A-58

Appendix A  The Basics of Logic Design

To initiate a read or write access, the Chip select signal must be made active. For
reads, we must also activate the Output enable signal that controls whether or not
the datum selected by the address is actually driven on the pins. The Output enable
is useful for connecting multiple memories to a single-output bus and using Output
enable to determine which memory drives the bus. The SRAM read access time is
usually  specified  as  the  delay  from  the  time  that  Output  enable  is  true  and  the
address lines are valid until the time that the data are on the output lines. Typical
read access times for SRAMs in 2004 varied from about 2–4 ns for the fastest CMOS
parts, which tend to be somewhat smaller and narrower, to 8–20 ns for the typical
largest parts, which in 2004 had more than 32 million bits of data. The demand for
low-power SRAMs for consumer products and digital appliances has grown greatly
in  the  past  5  years;  these  SRAMs  have  much  lower  stand-by  and  access  power,
but usually are 5–10 times slower. Most recently, synchronous SRAMs—similar to
the synchronous DRAMs, which we discuss in the next section—have also been
developed.

For  writes,  we  must  supply  the  data  to  be  written  and  the  address,  as  well  as
signals to cause the write to occur. When both the Write enable and Chip select
are true, the data on the data input lines are written into the cell specified by the
address. There are setup-time and hold-time requirements for the address and data
lines, just as there were for D flip-flops and latches. In addition, the Write enable
signal is not a clock edge but a pulse with a minimum width requirement. The time
to  complete  a  write  is  specified  by  the  combination  of  the  setup  times,  the  hold
times, and the Write enable pulse width.

Large SRAMs cannot be built in the same way we build a register file because,
unlike a register file where a 32-to-1 multiplexor might be practical, the 64K-to-
1  multiplexor  that  would  be  needed  for  a  64K  ×  1  SRAM  is  totally  impractical.
Rather than use a giant multiplexor, large memories are implemented with a shared
output line, called a bit line, which multiple memory cells in the memory array can
assert. To allow multiple sources to drive a single line, a three-state buffer (or tristate
buffer) is used. A three-state buffer has two inputs—a data signal and an Output
enable—and a single output, which is in one of three states: asserted, deasserted,
or high impedance. The output of a tristate buffer is equal to the data input signal,
either asserted or deasserted, if the Output enable is asserted, and is otherwise in a
high-impedance state that allows another three-state buffer whose Output enable is
asserted to determine the value of a shared output.

Figure A.9.2 shows a set of three-state buffers wired to form a multiplexor with
a decoded input. It is critical that the Output enable at most one of the three-state
buffers be asserted; otherwise, the three-state buffers may try to set the output line
differently. By using three-state buffers in the individual cells of the SRAM, each
cell that corresponds to a particular output can share the same output line. The use
of a set of distributed three-state buffers is a more efficient implementation than a
large centralized multiplexor. The three-state buffers are incorporated into the flip-
flops that form the basic cells of the SRAM. Figure A.9.3 shows how a small 4 × 2
SRAM might be built, using D latches with an input called Enable that controls the
three-state output.

A.9  Memory Elements: SRAMs and DRAMs

A-59

Select 0

Data 0

Select 1

Data 1

Select 2

Data 2

Select 3

Data 3

Enable

In

Out

Enable

In

Out

Enable

Output

In

Out

Enable

In

Out

FIGURE A.9.2  Four three-state buffers are used to form a multiplexor. Only one of the four
Select inputs can be asserted. A three-state buffer with a deasserted Output enable has a high-impedance
output that allows a three-state buffer whose Output enable is asserted to drive the shared output line.

The design in Figure A.9.3 eliminates the need for an enormous multiplexor;
however, it still requires a very large decoder and a correspondingly large number
of word lines. For example, in a 4M × 8 SRAM, we would need a 22-to-4M decoder
and 4M word lines (which are the lines used to enable the individual flip-flops)!
To circumvent this problem, large memories are organized as rectangular arrays
and  use  a  two-step  decoding  process.  Figure  A.9.4  shows  how  a  4M  ×  8  SRAM
might be organized internally using a two-step decode. As we will see, the two-level
decoding process is quite important in understanding how DRAMs operate.

Recently we have seen the development of both synchronous SRAMs (SSRAMs)
and synchronous DRAMs (SDRAMs). The key capability provided by synchronous
RAMs is the ability to transfer a burst of data from a series of sequential addresses
within an array or row. The burst is defined by a starting address, supplied in the
usual  fashion,  and  a  burst  length.  The  speed  advantage  of  synchronous  RAMs
comes from the ability to transfer the bits in the burst without having to specify
additional address bits. Instead, a clock is used to transfer the successive bits in the
burst. The elimination of the need to specify the address for the transfers within
the burst significantly improves the rate for transferring the block of data. Because
of  this  capability,  synchronous  SRAMs  and  DRAMs  are  rapidly  becoming  the
RAMs of choice for building memory systems in computers. We discuss the use of
synchronous DRAMs in a memory system in more detail in the next section and
in Chapter 5.

A-60

Appendix A  The Basics of Logic Design

Din[1]

Din[1]

Write enable

Address

0

2-to-4
decoder

1

2

3

D

C

D

latch

Q

Enable

D

C

D

latch

Q

Enable

D

C

D

latch

Q

Enable

D

C

D

latch

Q

Enable

D

C

D

latch

Q

Enable

D

C

D

latch

Q

Enable

D

C

D

latch

Q

Enable

D

C

D

latch

Q

Enable

FIGURE A.9.3  The basic structure of a 4 × 2 SRAM consists of a decoder that selects which pair of cells to activate.
The activated cells use a three-state output connected to the vertical bit lines that supply the requested data. The address that selects the cell is
sent on one of a set of horizontal address lines, called word lines. For simplicity, the Output enable and Chip select signals have been omitted,
but they could easily be added with a few AND gates.

Dout[1]

Dout[0]

4096

12
to
4096
decoder

Address
[21–10]

Address
[9–0]

4K (cid:31)
1024
SRAM

4K (cid:31)
1024
SRAM

4K (cid:31)
1024
SRAM

4K (cid:31)
1024
SRAM

4K (cid:31)
1024
SRAM

4K (cid:31)
1024
SRAM

4K (cid:31)
1024
SRAM

4K (cid:31)
1024
SRAM

1024

Mux

Mux

Mux

Mux

Mux

Mux

Mux

Mux

Dout7

Dout6

Dout5

Dout4

Dout3

Dout2

Dout1

Dout0

FIGURE  A.9.4  Typical  organization  of  a  4M ×  8  SRAM  as  an  array  of  4K ×  1024  arrays.  The first decoder generates the
addresses for eight 4K × 1024 arrays; then a set of multiplexors is used to select 1 bit from each 1024-bit-wide array. This is a much easier
design than a single-level decode that would need either an enormous decoder or a gigantic multiplexor. In practice, a modern SRAM of this
size would probably use an even larger number of blocks, each somewhat smaller.

A-62

Appendix A  The Basics of Logic Design

DRAMs

In a static RAM (SRAM), the value stored in a cell is kept on a pair of inverting gates,
and as long as power is applied, the value can be kept indefinitely. In a dynamic
RAM (DRAM), the value kept in a cell is stored as a charge in a capacitor. A single
transistor is then used to access this stored charge, either to read the value or to
overwrite the charge stored there. Because DRAMs use only a single transistor per
bit of storage, they are much denser and cheaper per bit. By comparison, SRAMs
require  four  to  six  transistors  per  bit.  Because  DRAMs  store  the  charge  on  a
capacitor, it cannot be kept indefinitely and must periodically be refreshed. That is
why this memory structure is called dynamic, as opposed to the static storage in a
SRAM cell.

To refresh the cell, we merely read its contents and write it back. The charge can
be kept for several milliseconds, which might correspond to close to a million clock
cycles.  Today,  single-chip  memory  controllers  often  handle  the  refresh  function
independently of the processor. If every bit had to be read out of the DRAM and
then written back individually, with large DRAMs containing multiple megabytes,
we  would  constantly  be  refreshing  the  DRAM,  leaving  no  time  for  accessing  it.
Fortunately,  DRAMs  also  use  a  two-level  decoding  structure,  and  this  allows  us
to  refresh  an  entire  row  (which  shares  a  word  line)  with  a  read  cycle  followed
immediately by a write cycle. Typically, refresh operations consume 1% to 2% of
the  active  cycles  of  the  DRAM,  leaving  the  remaining  98%  to  99%  of  the  cycles
available for reading and writing data.

Elaboration:  How  does  a  DRAM  read  and  write  the  signal  stored  in  a  cell?  The
transistor inside the cell is a switch, called a pass transistor, that allows the value stored
on the capacitor to be accessed for either reading or writing. Figure A.9.5 shows how
the single-transistor cell looks. The pass transistor acts like a switch: when the signal
on the word line is asserted, the switch is closed, connecting the capacitor to the bit
line. If the operation is a write, then the value to be written is placed on the bit line. If
the value is a 1, the capacitor will be charged. If the value is a 0, then the capacitor will
be discharged. Reading is slightly more complex, since the DRAM must detect a very
small charge stored in the capacitor. Before activating the word line for a read, the bit
line is charged to the voltage that is halfway between the low and high voltage. Then, by
activating the word line, the charge on the capacitor is read out onto the bit line. This
causes the bit line to move slightly toward the high or low direction, and this change is
detected with a sense amplifier, which can detect small changes in voltage.

A.9  Memory Elements: SRAMs and DRAMs

A-63

Word line

Pass transistor

Capacitor

FIGURE  A.9.5  A  single-transistor  DRAM  cell  contains  a  capacitor  that  stores  the  cell
contents and a transistor used to access the cell.

Bit line

Row
decoder
11-to-2048

2048 (cid:31) 2048
array

Address[10–0]

Column latches

Mux

Dout

FIGURE A.9.6  A 4M × 1 DRAM is built with a 2048 × 2048 array. The row access uses 11 bits to
select a row, which is then latched in 2048 1-bit latches. A multiplexor chooses the output bit from these 2048
latches. The RAS and CAS signals control whether the address lines are sent to the row decoder or column
multiplexor.

A-64

Appendix A  The Basics of Logic Design

DRAMs use a two-level decoder consisting of a row access followed by a column
access, as shown in Figure A.9.6. The row access chooses one of a number of rows
and activates the corresponding word line. The contents of all the columns in the
active row are then stored in a set of latches. The column access then selects the
data from the column latches. To save pins and reduce the package cost, the same
address lines are used for both the row and column address; a pair of signals called
RAS (Row Access Strobe) and CAS (Column Access Strobe) are used to signal the
DRAM that either a row or column address is being supplied. Refresh is performed
by simply reading the columns into the column latches and then writing the same
values back. Thus, an entire row is refreshed in one cycle. The two-level addressing
scheme,  combined  with  the  internal  circuitry,  makes  DRAM  access  times  much
longer (by a factor of 5–10) than SRAM access times. In 2004, typical DRAM access
times ranged from 45 to 65 ns; 256 Mbit DRAMs are in full production, and the
first  customer  samples  of  1 GB  DRAMs  became  available  in  the  first  quarter  of
2004.  The  much  lower  cost  per  bit  makes  DRAM  the  choice  for  main  memory,
while the faster access time makes SRAM the choice for caches.

You might observe that a 64M × 4 DRAM actually accesses 8K bits on every
row  access  and  then  throws  away  all  but  four  of  those  during  a  column  access.
DRAM designers have used the internal structure of the DRAM as a way to provide
higher bandwidth out of a DRAM. This is done by allowing the column address to
change without changing the row address, resulting in an access to other bits in the
column latches. To make this process faster and more precise, the address inputs
were clocked, leading to the dominant form of DRAM in use today: synchronous
DRAM or SDRAM.

Since  about  1999,  SDRAMs  have  been  the  memory  chip  of  choice  for  most
cache-based main memory systems. SDRAMs provide fast access to a series of bits
within a row by sequentially transferring all the bits in a burst under the control
of a clock signal. In 2004, DDRRAMs (Double Data Rate RAMs), which are called
double data rate because they transfer data on both the rising and falling edge of
an externally supplied clock, were the most heavily used form of SDRAMs. As we
discuss in Chapter 5, these high-speed transfers can be used to boost the bandwidth
available out of main memory to match the needs of the processor and caches.

Error Correction

Because  of  the  potential  for  data  corruption  in  large  memories,  most  computer
systems use some sort of error-checking code to detect possible corruption of data.
One simple code that is heavily used is a parity code. In a parity code the number
of 1s in a word is counted; the word has odd parity if the number of 1s is odd and

A.9  Memory Elements: SRAMs and DRAMs

A-65

error detection code  A
code that enables the
detection of an error in
data, but not the precise
location and, hence,
correction of the error.

even otherwise. When a word is written into memory, the parity bit is also written
(1 for odd, 0 for even). Then, when the word is read out, the parity bit is read and
checked. If the parity of the memory word and the stored parity bit do not match,
an error has occurred.

A 1-bit parity scheme can detect at most 1 bit of error in a data item; if there
are 2 bits of error, then a 1-bit parity scheme will not detect any errors, since the
parity  will  match  the  data  with  two  errors.  (Actually,  a  1-bit  parity  scheme  can
detect any odd number of errors; however, the probability of having three errors is
much lower than the probability of having two, so, in practice, a 1-bit parity code is
limited to detecting a single bit of error.) Of course, a parity code cannot tell which
bit in a data item is in error.

A 1-bit parity scheme is an error detection code; there are also error correction
codes  (ECC)  that  will  detect  and  allow  correction  of  an  error.  For  large  main
memories, many systems use a code that allows the detection of up to 2 bits of error
and the correction of a single bit of error. These codes work by using more bits to
encode the data; for example, the typical codes used for main memories require 7
or 8 bits for every 128 bits of data.

Elaboration:  A  1-bit  parity  code  is  a  distance-2  code,  which  means  that  if  we  look
at the data plus the parity bit, no 1-bit change is sufficient to generate another legal
combination of the data plus parity. For example, if we change a bit in the data, the parity
will be wrong, and vice versa. Of course, if we change 2 bits (any 2 data bits or 1 data
bit and the parity bit), the parity will match the data and the error cannot be detected.
Hence, there is a distance of two between legal combinations of parity and data.

To detect more than one error or correct an error, we need a distance-3 code, which
has the property that any legal combination of the bits in the error correction code and
the data has at least 3 bits differing from any other combination. Suppose we have such
a code and we have one error in the data. In that case, the code plus data will be one bit
away from a legal combination, and we can correct the data to that legal combination.
If  we  have  two  errors,  we  can  recognize  that  there  is  an  error,  but  we  cannot  correct
the errors. Let’s look at an example. Here are the data words and a distance-3 error
correction code for a 4-bit data item.

Data Word

Code bits

0000
0001
0010
0011
0100
0101
0110
0111

000
011
101
110
110
101
011
000

Data

1000
1001
1010
1011
1100
1101
1110
1111

Code bits

111
100
010
001
001
010
100
111

A-66

Appendix A  The Basics of Logic Design

To see how this works, let’s choose a data word, say 0110, whose error correction
code is 011. Here are the four 1-bit error possibilities for this data: 1110, 0010, 0100,
and 0111. Now look at the data item with the same code (011), which is the entry with
the value 0001. If the error correction decoder received one of the four possible data
words with an error, it would have to choose between correcting to 0110 or 0001. While
these four words with error have only 1 bit changed from the correct pattern of 0110,
they each have 2 bits that are different from the alternate correction of 0001. Hence,
the  error  correction  mechanism  can  easily  choose  to  correct  to  0110,  since  a  single
error is a much higher probability. To see that two errors can be detected, simply notice
that all the combinations with 2 bits changed have a different code. The one reuse of
the same code is with 3 bits different, but if we correct a 2-bit error, we will correct to
the wrong value, since the decoder will assume that only a single error has occurred. If
we want to correct 1-bit errors and detect, but not erroneously correct, 2-bit errors, we
need a distance-4 code.

Although we distinguished between the code and data in our explanation, in truth,
an error correction code treats the combination of code and data as a single word in
a larger code (7 bits in this example). Thus, it deals with errors in the code bits in the
same fashion as errors in the data bits.

While the above example requires n −1 bits for n bits of data, the number of bits
required grows slowly, so that for a distance-3 code, a 64-bit word needs 7 bits and a
128-bit word needs 8. This type of code is called a Hamming code, after R. Hamming,
who described a method for creating such codes.

 A.10  Finite-State Machines

finite-state machine
A sequential logic
function consisting of a
set of inputs and outputs,
a next-state function that
maps the current state and
the inputs to a new state,
and an output function
that maps the current
state and possibly the
inputs to a set of asserted
outputs.

next-state function  A
combinational function
that, given the inputs
and the current state,
determines the next state
of a finite-state machine.

As  we  saw  earlier,  digital  logic  systems  can  be  classified  as  combinational  or
sequential. Sequential systems contain state stored in memory elements internal to
the system. Their behavior depends both on the set of inputs supplied and on the
contents of the internal memory, or state of the system. Thus, a sequential system
cannot be described with a truth table. Instead, a sequential system is described as
a finite-state machine (or often just state machine). A finite-state machine has a set
of states and two functions, called the next-state function and the output function.
The  set  of  states  corresponds  to  all  the  possible  values  of  the  internal  storage.
Thus, if there are n bits of storage, there are 2n states. The next-state function is a
combinational function that, given the inputs and the current state, determines the
next state of the system. The output function produces a set of outputs from the
current state and the inputs. Figure A.10.1 shows this diagrammatically.

The state machines we discuss here and in Chapter 4 are synchronous. This means
that the state changes together with the clock cycle, and a new state is computed
once every clock. Thus, the state elements are updated only on the clock edge. We
use  this  methodology  in  this  section  and  throughout  Chapter  4,  and  we  do  not
usually show the clock explicitly. We use state machines throughout Chapter 4 to
control the execution of the processor and the actions of the datapath.

A.10  Finite-State Machines

A-67

Next
state

Next-state
function

Current state

Clock

Inputs

Output
function

Outputs

FIGURE A.10.1  A state machine consists of internal storage that contains the state and
two  combinational  functions:  the  next-state  function  and  the  output  function.  Often, the
output function is restricted to take only the current state as its input; this does not change the capability of
a sequential machine, but does affect its internals.

To illustrate how a finite-state machine operates and is designed, let’s look at a
simple and classic example: controlling a traffic light. (Chapters 4 and 5 contain more
detailed examples of using finite-state machines to control processor execution.)
When a finite-state machine is used as a controller, the output function is often
restricted to depend on just the current state. Such a finite-state machine is called
a Moore machine. This is the type of finite-state machine we use throughout this
book. If the output function can depend on both the current state and the current
input, the machine is called a Mealy machine. These two machines are equivalent
in their capabilities, and one can be turned into the other mechanically. The basic
advantage of a Moore machine is that it can be faster, while a Mealy machine may
be smaller, since it may need fewer states than a Moore machine. In Chapter 5, we
discuss  the  differences  in  more  detail  and  show  a  Verilog  version  of  finite-state
control using a Mealy machine.

Our example concerns the control of a traffic light at an intersection of a north-
south route and an east-west route. For simplicity, we will consider only the green
and red lights; adding the yellow light is left for an exercise. We want the lights to
cycle no faster than 30 seconds in each direction, so we will use a 0.033-Hz clock
so that the machine cycles between states at no faster than once every 30 seconds.
There are two output signals:

■	 NSlite:  When  this  signal  is  asserted,  the  light  on  the  north-south  road  is
green; when this signal is deasserted, the light on the north-south road is red.

A-68

Appendix A  The Basics of Logic Design

■	 EWlite: When this signal is asserted, the light on the east-west road is green;

when this signal is deasserted, the light on the east-west road is red.

In addition, there are two inputs:

■	 NScar: Indicates that a car is over the detector placed in the roadbed in front

of the light on the north-south road (going north or south).

■	 EWcar: Indicates that a car is over the detector placed in the roadbed in front

of the light on the east-west road (going east or west).

The  traffic  light  should  change  from  one  direction  to  the  other  only  if  a  car  is
waiting to go in the other direction; otherwise, the light should continue to show
green in the same direction as the last car that crossed the intersection.

To implement this simple traffic light we need two states:

■	 NSgreen: The traffic light is green in the north-south direction.

■	 EWgreen: The traffic light is green in the east-west direction.

We also need to create the next-state function, which can be specified with a table:

NScar

EWcar

Next state

Inputs

NSgreen
NSgreen
NSgreen
NSgreen
EWgreen
EWgreen
EWgreen
EWgreen

0
0
1
1
0
0
1
1

0
1
0
1
0
1
0
1

NSgreen
EWgreen
NSgreen
EWgreen
EWgreen
EWgreen
NSgreen
NSgreen

Notice  that  we  didn’t  specify  in  the  algorithm  what  happens  when  a  car
approaches from both directions. In this case, the next-state function given above
changes the state to ensure that a steady stream of cars from one direction cannot
lock out a car in the other direction.

The finite-state machine is completed by specifying the output function.
Before  we  examine  how  to  implement  this  finite-state  machine,  let’s  look  at
a  graphical  representation,  which  is  often  used  for  finite-state  machines.  In  this
representation, nodes are used to indicate states. Inside the node we place a list of
the outputs that are active for that state. Directed arcs are used to show the next-state
function, with labels on the arcs specifying the input condition as logic functions.
Figure A.10.2 shows the graphical representation for this finite-state machine.

Outputs

NSlite

EWlite

NSgreen
EWgreen

1
0

0
1

A.10  Finite-State Machines

A-69

EWcar

NSgreen

EWgreen

NSlite

NScar

EWlite

EWcar

NScar

FIGURE A.10.2  The graphical representation of the two-state traffic light controller. We
simplified the logic functions on the state transitions. For example, the transition from NSgreen to EWgreen
⋅
in the next-state table is (
NScar EWcar

, which is equivalent to EWcar.
)

⋅
NScar EWcar

(cid:31)

)

(

A finite-state machine can be implemented with a register to hold the current
state and a block of combinational logic that computes the next-state function and
the output function. Figure A.10.3 shows how a finite-state machine with 4 bits of
state, and thus up to 16 states, might look. To implement the finite-state machine
in this way, we must first assign state numbers to the states. This process is called
state assignment. For example, we could assign NSgreen to state 0 and EWgreen to
state 1. The state register would contain a single bit. The next-state function would
be given as

NextState

(
CurrentState EWcar

⋅

)

(
CurrentState NScar

⋅

)

where CurrentState is the contents of the state register (0 or 1) and NextState is the
output of the next-state function that will be written into the state register at the
end of the clock cycle. The output function is also simple:

NSlite
EWlite

(cid:31)
(cid:31)

CurrentState
CurrentState

The  combinational  logic  block  is  often  implemented  using  structured  logic,
such as a PLA. A PLA can be constructed automatically from the next-state and
output function tables. In fact, there are computer-aided design (CAD) programs

A-70

Appendix A  The Basics of Logic Design

Outputs

Next state

Combinational logic

State register

Inputs

FIGURE  A.10.3  A  finite-state  machine  is  implemented  with  a  state  register  that  holds
the current state and a combinational logic block to compute the next state and output
functions. The latter two functions are often split apart and implemented with two separate blocks of logic,
which may require fewer gates.

that take either a graphical or textual representation of a finite-state machine and
produce an optimized implementation automatically. In Chapters 4 and 5, finite-
state machines were used to control processor execution.
 Appendix C discusses
the detailed implementation of these controllers with both PLAs and ROMs.

To  show  how  we  might  write  the  control  in  Verilog,  Figure  A.10.4  shows  a
Verilog version designed for synthesis. Note that for this simple control function,
a Mealy machine is not useful, but this style of specification is used in Chapter 5 to
implement a control function that is a Mealy machine and has fewer states than the
Moore machine controller.

A.11  Timing Methodologies

A-71

FIGURE A.10.4  A Verilog version of the traffic light controller.

What  is  the  smallest  number  of  states  in  a  Moore  machine  for  which  a  Mealy
machine could have fewer states?

Check
Yourself

a.  Two, since there could be a one-state Mealy machine that might do the same

thing.

b.  Three, since there could be a simple Moore machine that went to one of two
different states and always returned to the original state after that. For such a
simple machine, a two-state Mealy machine is possible.

c.  You need at least four states to exploit the advantages of a Mealy machine

over a Moore machine.

 A.11  Timing Methodologies

Throughout  this  appendix  and  in  the  rest  of  the  text,  we  use  an  edge-triggered
timing  methodology.  This  timing  methodology  has  an  advantage  in  that  it  is
simpler  to  explain  and  understand  than  a  level-triggered  methodology.  In  this
section,  we  explain  this  timing  methodology  in  a  little  more  detail  and  also
introduce level-sensitive clocking. We conclude this section by briefly discussing

A-72

Appendix A  The Basics of Logic Design

the  issue  of  asynchronous  signals  and  synchronizers,  an  important  problem  for
digital designers.

The  purpose  of  this  section  is  to  introduce  the  major  concepts  in  clocking
methodology. The section makes some important simplifying assumptions; if you
are interested in understanding timing methodology in more detail, consult one of
the references listed at the end of this appendix.

We use an edge-triggered timing methodology because it is simpler to explain
and  has  fewer  rules  required  for  correctness.  In  particular,  if  we  assume  that  all
clocks arrive at the same time, we are guaranteed that a system with edge-triggered
registers between blocks of combinational logic can operate correctly without races
if we simply make the clock long enough. A race occurs when the contents of a
state element depend on the relative speed of different logic elements. In an edge-
triggered design, the clock cycle must be long enough to accommodate the path
from  one  flip-flop  through  the  combinational  logic  to  another  flip-flop  where  it
must satisfy the setup-time requirement. Figure A.11.1 shows this requirement for
a system using rising edge-triggered flip-flops. In such a system the clock period
(or cycle time) must be at least as large as

t

prop

(cid:31)

t

combinational

(cid:31)

t

setup

for the worst-case values of these three delays, which are defined as follows:

■	 tprop is the time for a signal to propagate through a flip-flop; it is also sometimes

called clock-to-Q.

■	 tcombinational is the longest delay for any combinational logic (which by definition

is surrounded by two flip-flops).

■	 tsetup is the time before the rising clock edge that the input to a flip-flop must

be valid.

Q

Flip-flop

D

C

Combinational
logic block

Q

Flip-flop

D

C

tprop

tcombinational

tsetup

FIGURE  A.11.1
In  an  edge-triggered  design,  the  clock  must  be  long  enough  to  allow
signals to be valid for the required setup time before the next clock edge. The time for a
flip-flop input to propagate to the flip-flip outputs is tprop; the signal then takes tcombinational to travel through the
combinational logic and must be valid tsetup before the next clock edge.

A.11  Timing Methodologies

A-73

We make one simplifying assumption: the hold-time requirements are satisfied,

which is almost never an issue with modern logic.

One additional complication that must be considered in edge-triggered designs
is clock skew. Clock skew is the difference in absolute time between when two state
elements  see  a  clock  edge.  Clock  skew  arises  because  the  clock  signal  will  often
use two different paths, with slightly different delays, to reach two different state
elements. If the clock skew is large enough, it may be possible for a state element to
change and cause the input to another flip-flop to change before the clock edge is
seen by the second flip-flop.

Figure  A.11.2  illustrates  this  problem,  ignoring  setup  time  and  flip-flop
propagation delay. To avoid incorrect operation, the clock period is increased to
allow for the maximum clock skew. Thus, the clock period must be longer than

t

prop

(cid:31)

t

combinational

(cid:31)

t

setup

(cid:31)

t

skew

With  this  constraint  on  the  clock  period,  the  two  clocks  can  also  arrive  in  the
opposite order, with the second clock arriving tskew earlier, and the circuit will work

clock skew  The
difference in absolute time
between the times when
two state elements see a
clock edge.

Clock arrives
at time t

Q

Flip-flop

D

C

Combinational
logic block with
delay time of ∆

Clock arrives
after t + ∆

Q

Flip-flop

D

C

FIGURE A.11.2
Illustration of how clock skew can cause a race, leading to incorrect operation. Because of the difference
in when the two flip-flops see the clock, the signal that is stored into the first flip-flop can race forward and change the input to the second flip-
flop before the clock arrives at the second flip-flop.

correctly.  Designers  reduce  clock-skew  problems  by  carefully  routing  the  clock
signal to minimize the difference in arrival times. In addition, smart designers also
provide some margin by making the clock a little longer than the minimum; this
allows for variation in components as well as in the power supply. Since clock skew
can also affect the hold-time requirements, minimizing the size of the clock skew
is important.

Edge-triggered designs have two drawbacks: they require extra logic and they
may sometimes be slower. Just looking at the D flip-flop versus the level-sensitive
latch  that  we  used  to  construct  the  flip-flop  shows  that  edge-triggered  design
requires more logic. An alternative is to use level-sensitive clocking. Because state
changes  in  a  level-sensitive  methodology  are  not  instantaneous,  a  level-sensitive
scheme is slightly more complex and requires additional care to make it operate
correctly.

level-sensitive
clocking  A timing
methodology in which
state changes occur
at either high or low
clock levels but are not
instantaneous as such
changes are in edge-
triggered designs.

A-74

Appendix A  The Basics of Logic Design

Level-Sensitive Timing

In  level-sensitive  timing,  the  state  changes  occur  at  either  high  or  low  levels,  but
they are not instantaneous as they are in an edge-triggered methodology. Because of
the noninstantaneous change in state, races can easily occur. To ensure that a level-
sensitive design will also work correctly if the clock is slow enough, designers use two-
phase clocking. Two-phase clocking is a scheme that makes use of two nonoverlapping
clock signals. Since the two clocks, typically called ϕ1 and ϕ2, are nonoverlapping, at
most one of the clock signals is high at any given time, as Figure A.11.3 shows. We
can use these two clocks to build a system that contains level-sensitive latches but is
free from any race conditions, just as the edge-triggered designs were.

Φ1

Φ2

Nonoverlapping
periods

FIGURE A.11.3  A two-phase clocking scheme showing the cycle of each clock and the
nonoverlapping periods.

Q

Latch

D

C

Φ1

Combinational
logic block

Φ2

Q

Latch

D

C

Combinational
logic block

Φ1

D

C

Latch

FIGURE A.11.4  A two-phase timing scheme with alternating latches showing how the system operates on both clock
phases. The output of a latch is stable on the opposite phase from its C input. Thus, the first block of combinational inputs has a stable input
during ϕ2, and its output is latched by ϕ2. The second (rightmost) combinational block operates in just the opposite fashion, with stable inputs
during ϕ1. Thus, the delays through the combinational blocks determine the minimum time that the respective clocks must be asserted. The
size of the nonoverlapping period is determined by the maximum clock skew and the minimum delay of any logic block.

One simple way to design such a system is to alternate the use of latches that are
open on ϕ1 with latches that are open on ϕ2. Because both clocks are not asserted
at the same time, a race cannot occur. If the input to a combinational block is a ϕ1
clock, then its output is latched by a ϕ2 clock, which is open only during ϕ2 when
the input latch is closed and hence has a valid output. Figure A.11.4 shows how
a system with two-phase timing and alternating latches operates. As in an edge-
triggered design, we must pay attention to clock skew, particularly between the two

A.11  Timing Methodologies

A-75

clock phases. By increasing the amount of nonoverlap between the two phases, we
can reduce the potential margin of error. Thus, the system is guaranteed to operate
correctly  if  each  phase  is  long  enough  and  if  there  is  large  enough  nonoverlap
between the phases.

Asynchronous Inputs and Synchronizers

By  using  a  single  clock  or  a  two-phase  clock,  we  can  eliminate  race  conditions
if  clock-skew  problems  are  avoided.  Unfortunately,  it  is  impractical  to  make  an
entire  system  function  with  a  single  clock  and  still  keep  the  clock  skew  small.
While the CPU may use a single clock, I/O devices will probably have their own
clock. An asynchronous device may communicate with the CPU through a series
of handshaking steps. To translate the asynchronous input to a synchronous signal
that can be used to change the state of a system, we need to use a synchronizer,
whose inputs are the asynchronous signal and a clock and whose output is a signal
synchronous with the input clock.

Our  first  attempt  to  build  a  synchronizer  uses  an  edge-triggered  D  flip-flop,
whose  D  input  is  the  asynchronous  signal,  as  Figure  A.11.5  shows.  Because  we
communicate with a handshaking protocol, it does not matter whether we detect
the asserted state of the asynchronous signal on one clock or the next, since the
signal will be held asserted until it is acknowledged. Thus, you might think that this
simple structure is enough to sample the signal accurately, which would be the case
except for one small problem.

Asynchronous input

Clock

Q

Flip-flop

D

C

Synchronous output

FIGURE A.11.5  A synchronizer built from a D flip-flop is used to sample an asynchronous
signal to produce an output that is synchronous with the clock. This “synchronizer” will not
work properly!

The  problem  is  a  situation  called  metastability.  Suppose  the  asynchronous
signal is transitioning between high and low when the clock edge arrives. Clearly,
it is not possible to know whether the signal will be latched as high or low. That
problem we could live with. Unfortunately, the situation is worse: when the signal
that is sampled is not stable for the required setup and hold times, the flip-flop may
go into a metastable state. In such a state, the output will not have a legitimate high
or low value, but will be in the indeterminate region between them. Furthermore,

metastability
A situation that occurs if
a signal is sampled when
it is not stable for the
required setup and hold
times, possibly causing
the sampled value to
fall in the indeterminate
region between a high and
low value.

A-76

Appendix A  The Basics of Logic Design

synchronizer failure
A situation in which
a flip-flop enters a
metastable state and
where some logic blocks
reading the output of the
flip-flop see a 0 while
others see a 1.

the flip-flop is not guaranteed to exit this state in any bounded amount of time.
Some logic blocks that look at the output of the flip-flop may see its output as 0,
while others may see it as 1. This situation is called a synchronizer failure.

In a purely synchronous system, synchronizer failure can be avoided by ensuring
that  the  setup  and  hold  times  for  a  flip-flop  or  latch  are  always  met,  but  this  is
impossible when the input is asynchronous. Instead, the only solution possible is
to  wait  long  enough  before  looking  at  the  output  of  the  flip-flop  to  ensure  that
its output is stable, and that it has exited the metastable state, if it ever entered it.
How long is long enough? Well, the probability that the flip-flop will stay in the
metastable state decreases exponentially, so after a very short time the probability
that  the  flip-flop  is  in  the  metastable  state  is  very  low;  however,  the  probability
never  reaches  0!  So  designers  wait  long  enough  such  that  the  probability  of  a
synchronizer failure is very low, and the time between such failures will be years or
even thousands of years.

For most flip-flop designs, waiting for a period that is several times longer than
the  setup  time  makes  the  probability  of  synchronization  failure  very  low.  If  the
clock rate is longer than the potential metastability period (which is likely), then a
safe synchronizer can be built with two D flip-flops, as Figure A.11.6 shows. If you
are interested in reading more about these problems, look into the references.

Asynchronous input

Clock

Q

Flip-flop

D

C

Q

Flip-flop

D

C

Synchronous output

FIGURE A.11.6  This synchronizer will work correctly if the period of metastability that
we wish to guard against is less than the clock period. Although the output of the first flip-flop
may be metastable, it will not be seen by any other logic element until the second clock, when the second D
flip-flop samples the signal, which by that time should no longer be in a metastable state.

Check
Yourself

Suppose  we  have  a  design  with  very  large  clock  skew—longer  than  the  register
propagation time. Is it always possible for such a design to slow the clock down
enough to guarantee that the logic operates properly?

propagation time  The
time required for an input
to a flip-flop to propagate
to the outputs of the flip-
flop.

a.  Yes,  if  the  clock  is  slow  enough  the  signals  can  always  propagate  and  the

design will work, even if the skew is very large.

b.  No, since it is possible that two registers see the same clock edge far enough
apart that a register is triggered, and its outputs propagated and seen by a
second register with the same clock edge.

A.12  Field Programmable Devices

A-77

 A.12  Field Programmable Devices

Within a custom or semicustom chip, designers can make use of the flexibility of the
underlying structure to easily implement combinational or sequential logic. How
can a designer who does not want to use a custom or semicustom IC implement
a  complex  piece  of  logic  taking  advantage  of  the  very  high  levels  of  integration
available?  The  most  popular  component  used  for  sequential  and  combinational
logic  design  outside  of  a  custom  or  semicustom  IC  is  a  field  programmable
device (FPD). An FPD is an integrated circuit containing combinational logic, and
possibly memory devices, that are configurable by the end user.

FPDs  generally  fall  into  two  camps:  programmable  logic  devices  (PLDs),
which are purely combinational, and field programmable gate arrays (FPGAs),
which provide both combinational logic and flip-flops. PLDs consist of two forms:
simple PLDs (SPLDs), which are usually either a PLA or a programmable array
logic (PAL), and complex PLDs, which allow more than one logic block as well as
configurable interconnections among blocks. When we speak of a PLA in a PLD,
we mean a PLA with user programmable and-plane and or-plane. A PAL is like a
PLA, except that the or-plane is fixed.

Before we discuss FPGAs, it is useful to talk about how FPDs are configured.
Configuration  is  essentially  a  question  of  where  to  make  or  break  connections.
Gate  and  register  structures  are  static,  but  the  connections  can  be  configured.
Notice that by configuring the connections, a user determines what logic functions
are  implemented.  Consider  a  configurable  PLA:  by  determining  where  the
connections are in the and-plane and the or-plane, the user dictates what logical
functions are computed in the PLA. Connections in FPDs are either permanent
or reconfigurable. Permanent connections involve the creation or destruction of
a connection between two wires. Current FPLDs all use an antifuse technology,
which allows a connection to be built at programming time that is then permanent.
The  other  way  to  configure  CMOS  FPLDs  is  through  a  SRAM.  The  SRAM  is
downloaded at power-on, and the contents control the setting of switches, which
in  turn  determines  which  metal  lines  are  connected.  The  use  of  SRAM  control
has the advantage in that the FPD can be reconfigured by changing the contents
of  the  SRAM.  The  disadvantages  of  the  SRAM-based  control  are  two-fold:  the
configuration is volatile and must be reloaded on power-on, and the use of active
transistors for switches slightly increases the resistance of such connections.

FPGAs  include  both  logic  and  memory  devices,  usually  structured  in  a  two-
dimensional  array  with  the  corridors  dividing  the  rows  and  columns  used  for

field programmable
devices (FPD)  An
integrated circuit
containing combinational
logic, and possibly
memory devices, that are
configurable by the end
user.

programmable logic
device (PLD)
An integrated circuit
containing combinational
logic whose function is
configured by the end
user.

field programmable
gate array (FPGA)
A configurable integrated
circuit containing both
combinational logic
blocks and flip-flops.

simple programmable
logic device
(SPLD)  Programmable
logic device, usually
containing either a single
PAL or PLA.

programmable array
logic (PAL)  Contains a
programmable and-plane
followed by a fixed or-
plane.

antifuse  A structure in
an integrated circuit that
when programmed makes
a permanent connection
between two wires.

A-78

Appendix A  The Basics of Logic Design

lookup tables (LUTs)  In
a field programmable
device, the name given
to the cells because they
consist of a small amount
of logic and RAM.

global  interconnect  between  the  cells  of  the  array.  Each  cell  is  a  combination  of
gates and flip-flops that can be programmed to perform some specific function.
Because they are basically small, programmable RAMs, they are also called lookup
tables (LUTs). Newer FPGAs contain more sophisticated building blocks such as
pieces  of  adders  and  RAM  blocks  that  can  be  used  to  build  register  files.  Some
FPGAs even contain 64-bit RISC-V cores!

In  addition  to  programming  each  cell  to  perform  a  specific  function,  the
interconnections between cells are also programmable, allowing modern FPGAs
with hundreds of blocks and hundreds of thousands of gates to be used for complex
logic functions. Interconnect is a major challenge in custom chips, and this is even
more true for FPGAs, because cells do not represent natural units of decomposition
for structured design. In many FPGAs, 90% of the area is reserved for interconnect
and only 10% is for logic and memory blocks.

Just as you cannot design a custom or semicustom chip without CAD tools, you
also  need  them  for  FPDs.  Logic  synthesis  tools  have  been  developed  that  target
FPGAs,  allowing  the  generation  of  a  system  using  FPGAs  from  structural  and
behavioral Verilog.

 A.13  Concluding Remarks

This  appendix  introduces  the  basics  of  logic  design.  If  you  have  digested  the
material in this appendix, you are ready to tackle the material in Chapters 4 and 5,
both of which use the concepts discussed in this appendix extensively.

Further Reading

There are a number of good texts on logic design. Here are some you might like to
look into.

Ciletti, M. D. [2002]. Advanced Digital Design with the Verilog HDL, Englewood
Cliffs, NJ: Prentice Hall.
A thorough book on logic design using Verilog.

Katz, R. H. [2004]. Modern Logic Design, 2nd ed., Reading, MA: Addison-Wesley.
A general text on logic design.

Wakerly, J. F. [2000]. Digital Design: Principles and Practices, 3rd ed., Englewood
Cliffs, NJ: Prentice Hall.
A general text on logic design.

