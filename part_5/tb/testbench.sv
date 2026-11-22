// Runs one hand-written program on the processor and writes a trace with the
// same information the ISS prints: for every executed instruction its PC and
// the 32 register values after it, and at the end the data memory.
// Lab 5 handout, Part 5.
module testbench;

    logic        clk = 0;
    logic        reset;
    logic [31:0] writedata, dataadr;
    logic        memwrite;

    top dut (
        .clk       (clk),
        .reset     (reset),
        .writedata (writedata),
        .dataadr   (dataadr),
        .memwrite  (memwrite)
    );

    always #5 clk = ~clk;

    string program_file, data_file, trace_file;
    int    trace;

    initial begin
        reset = 1;

        if (!$value$plusargs("PROG=%s",  program_file)) $fatal(1, "+PROG=<machine code file> is missing");
        if (!$value$plusargs("DMEM=%s",  data_file))    $fatal(1, "+DMEM=<data memory file> is missing");
        if (!$value$plusargs("TRACE=%s", trace_file))   $fatal(1, "+TRACE=<trace file> is missing");
        trace = $fopen(trace_file, "w");

        // The ISS starts with every memory word at zero.
        for (int i = 0; i < 64; i++) dut.dmem.RAM[i] = 0;
        $readmemh(data_file, dut.dmem.RAM);

        // imem loads memfile.dat by itself at time 0. Load the program after that.
        #1;
        for (int i = 0; i < 64; i++) dut.imem.RAM[i] = 0;
        // REQ P5: the RTL runs the machine code that the ISS assembled
        $readmemb(program_file, dut.imem.RAM);

        repeat (2) @(negedge clk);
        reset = 0;
    end

    // The datapath does not carry the PC past the execute stage, so the
    // testbench follows each instruction from execute to the cycle after
    // writeback, when its register write has happened.
    logic [31:0] pc_memory, pc_writeback, pc_done;
    logic        done_valid;            // a real instruction finished, not a bubble
    logic        last_writeback, last_done;

    always @(posedge clk) begin
        pc_memory    <= dut.mips.dp.pcplus4E - 32'd4;
        pc_writeback <= pc_memory;
        pc_done      <= pc_writeback;
        done_valid   <= dut.mips.dp.validW && !reset;

        // End of simulation: the store of 0xDEADBEEF to address 12 is in the memory stage.
        last_writeback <= !reset && memwrite && dataadr == 32'h0000_000C && writedata == 32'hDEAD_BEEF;
        last_done      <= last_writeback;
    end

    // REQ P5: write the RTL trace to a file while the processor executes
    always @(negedge clk) begin
        if (done_valid) begin
            $fwrite(trace, "PC=%08h REGS=00000000", pc_done);
            for (int i = 1; i < 32; i++) $fwrite(trace, " %08h", dut.mips.dp.rf.rf[i]);
            $fwrite(trace, "\n");

            if (last_done) begin
                for (int i = 0; i < 4; i++) $fwrite(trace, "MEM[%02h]=%08h\n", i * 4, dut.dmem.RAM[i]);
                $fclose(trace);
                $display("Program finished. Trace written to %s", trace_file);
                $finish;
            end
        end
    end

    initial begin
        #100000;
        $fatal(1, "TIMEOUT: the end-of-simulation store was not reached.");
    end

    initial begin
        $fsdbDumpfile("lab5_part5.fsdb");
        $fsdbDumpvars(0, testbench);
    end

endmodule
