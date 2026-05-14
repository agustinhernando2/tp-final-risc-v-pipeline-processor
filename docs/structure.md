# Folder Structure


```
src/
├── sources_1/
│   ├── Generic/                  # Reusable primitives
│   │   ├── posEdgeRegister.sv
│   │   ├── adder.sv
│   │   ├── mux1_2.sv
│   │   ├── mux2_4.sv
│   │   └── mux3_8.sv
│   │
│   ├── IF/                       # Instruction Fetch stage
│   │   ├── InstructionFetch.sv
│   │   └── InstructionMemory.sv
│   │
│   ├── ID/                       # Instruction Decode stage
│   │   ├── InstructionDecode.sv
│   │   ├── RegisterFile.sv
│   │   ├── ControlUnit.sv         
│   │   └── SignExtension.sv
│   │
│   ├── EX/                       # Execute stage 
│   │   ├── ALU.sv
│   │   └── ALUControl.sv
│   │
│   ├── MEM/                      # Memory Access stage 
│   │   └── DataMemory.sv
│   │
│   ├── WB/                       # Write Back stage 
│   │   └── WriteBack.sv
│   │
│   ├── Buffers/                  # Inter-stage pipeline registers
│   │   ├── IF_ID_Buffer.sv
│   │   ├── ID_EX_Buffer.sv
│   │   ├── EX_MEM_Buffer.sv      
│   │   └── MEM_WB_Buffer.sv      
│   │
│   ├── HazardUnit/               # Hazard detection & forwarding 
│   │   ├── HazardDetection.sv
│   │   └── ForwardingUnit.sv
│   │
│   ├── UART/                     # UART interface 
│   │   ├── UartRx.sv
│   │   └── UartTx.sv
│   │
│   └── Top/
│       └── riscv.sv              # Top-level module
│
├── sim_1/
│   ├── IF/                       # Unit tests for IF stage
│   │   ├── tb_IF.sv
│   │   ├── tb_IF_ID_Buffer.sv
│   │   └── tb_adder.sv
│   │
│   ├── ID/                       # Unit tests for ID stage 
│   │   └── tb_ID.sv
│   │
│   ├── EX/                       # Unit tests for EX stage 
│   │   └── tb_EX.sv
│   │
│   ├── MEM/                      # Unit tests for MEM stage 
│   │   └── tb_MEM.sv
│   │
│   ├── WB/                       # Unit tests for WB stage 
│   │   └── tb_WB.sv
│   │
│   ├── Integrador/               # Integration tests across stages
│   │   ├── tb_IF_ID.sv
│   │   ├── tb_IF_ID_EX.sv        
│   │   └── tb_RISCV.sv           # Full pipeline test 
│   │
│   └── UART/                     # UART-level tests 
│       └── tb_UART.sv
│
└── mem/                          # Memory init files
    └── program.hex               # Shared across testbenches
```

## Notes

- Use `logic` instead of `reg`/`wire`.
- Use `always_ff` for sequential logic, `always_comb` for combinational. Never use plain `always`.
- Port naming: `i_` inputs, `o_` outputs, `w_` internal wires, `r_` registers/state.
- All widths parameterized; default 32-bit. No hardcoded widths.
- `program.hex` lives in `src/mem/` and is shared across all testbenches.
