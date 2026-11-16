////////////////////////////////////////////////////////////////////////////
// ========================================================================
// This file has the following module implementations:
// 1. top
// 2. mips
// 3. dmem
// 4. imem
// =========================================================================
////////////////////////////////////////////////////////////////////////////
// Top Module 
//  - This module connects the MIPS processor to instruction and data memory
////////////////////////////////////////////////////////////////////////////
module top (
    input clk, reset,
    output [31:0] writedata, dataadr,
    output memwrite
);
    logic [31:0] pc, instr, readdata;

    // instantiate processor and memories
    mips mips (clk, reset, pc, instr, memwrite, dataadr, writedata, readdata);
    imem imem (pc[7:2], instr);
    dmem dmem (clk, memwrite, dataadr, writedata, readdata);
endmodule


//////////////////////////////////////////////////////////////////////
// 5-stage Pipelined MIPS Processor Module
//////////////////////////////////////////////////////////////////////
module mips (
    input           clk, reset,
    output  [31:0]  pc,
    input   [31:0]  instr,
    output          memwrite,
    output  [31:0]  aluout, writedata,
    input   [31:0]  readdata
    );

    logic memtoreg, branch, alusrc, regdst, regwrite, jump;
    logic zero, pcsrc;
    logic [2:0] alucontrol;
    logic [31:0] instrD;
    logic memwriteD;

    // Decode the instruction stored in IF/ID
    controller c(
    instrD[31:26],
    instrD[5:0],
    zero,
    memtoreg,
    memwriteD,
    pcsrc,
    alusrc,
    regdst,
    regwrite,
    jump,
    alucontrol
    );

// Datapath instance
datapath dp(
    .clk(clk),
    .reset(reset),

    .memtoreg(memtoreg),
    .pcsrc(pcsrc),
    .alusrc(alusrc),
    .regdst(regdst),
    .regwrite(regwrite),
    .jump(jump),
    .memwriteD(memwriteD),
    .memwriteM(memwrite),

    .alucontrol(alucontrol),
    .zero(zero),

    .pc(pc),
    .instr(instr),
    .aluout(aluout),
    .writedata(writedata),
    .readdata(readdata),
    .instrD(instrD)
);

endmodule


//////////////////////////////////////////////////////////////////////
// Data Memory Module
//////////////////////////////////////////////////////////////////////
module dmem (
    input clk, we,
    input [31:0] a, wd,
    output [31:0] rd
);
    logic [31:0] RAM[63:0];

    assign rd = RAM[a[31:2]]; // word aligned
    
    always @(posedge clk) begin
        if (we)
            RAM[a[31:2]] <= wd;
    end        
endmodule


//////////////////////////////////////////////////////////////////////
// Instruction Memory Module
// - Note that it uses $readmemh to load imem from memfile.dat
// - This has a capacity of 64 words, If the memfile.dat has fewer than 64 words,
//   you will get a warning that some addresses are not initialized or the file has not enough words
//   you can ignre this warning
//////////////////////////////////////////////////////////////////////
module imem (
    input [5:0] a,
    output [31:0] rd
);
    logic [31:0] RAM[63:0];
    
    initial begin
        $readmemh("memfile.dat",RAM);
    end
    assign rd = RAM[a]; // word aligned
endmodule