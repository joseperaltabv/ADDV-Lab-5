// The wires the monitor watches: the instruction fetch interface of the processor.
// Lab 5 handout, Part 3, Monitor.
interface fetch_if (input logic clk, input logic reset);
    logic [31:0] pc;            // address sent to the instruction memory
    logic [31:0] instr;         // instruction read back from it
    logic        branch_taken;  // the BEQ in decode redirects the PC in this cycle
endinterface
