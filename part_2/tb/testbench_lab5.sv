// ============================================================================
// CSE 598 ADDV - Lab 5 Part 2
// Testbench for constrained-random MIPS instruction generator
// ============================================================================

module testbench;

    // ------------------------------------------------------------------------
    // DUT signals
    // ------------------------------------------------------------------------

    logic clk;
    logic reset;

    logic [31:0] writedata;
    logic [31:0] dataadr;
    logic        memwrite;


    // ------------------------------------------------------------------------
    // Instruction generator
    // ------------------------------------------------------------------------

    instruction_generator gen;


    // ------------------------------------------------------------------------
    // Instantiate Lab 2 pipelined MIPS processor
    // ------------------------------------------------------------------------

    top dut (
        .clk       (clk),
        .reset     (reset),
        .writedata (writedata),
        .dataadr   (dataadr),
        .memwrite  (memwrite)
    );


    // ------------------------------------------------------------------------
    // Clock
    // ------------------------------------------------------------------------

    initial begin
        clk = 1'b0;
    end

    always #5 clk = ~clk;


    // ------------------------------------------------------------------------
    // Generate program, initialize memories, and release reset
    // ------------------------------------------------------------------------

    initial begin

        // Hold processor in reset while program is being generated/loaded.
        reset = 1'b1;


        // --------------------------------------------------------------------
        // Initialize the four data-memory locations used by this lab.
        //
        // Address 0x00 -> RAM[0]
        // Address 0x04 -> RAM[1]
        // Address 0x08 -> RAM[2]
        // Address 0x0C -> RAM[3]
        //
        // 0x0C contains the trickbox value.
        // --------------------------------------------------------------------

        dut.dmem.RAM[0] = 32'h0000_0005;
        dut.dmem.RAM[1] = 32'h0000_0003;
        dut.dmem.RAM[2] = 32'h0000_000F;
        dut.dmem.RAM[3] = 32'hDEAD_BEEF;


        // --------------------------------------------------------------------
        // Construct and run the instruction generator.
        // --------------------------------------------------------------------

        gen = new();

        gen.generate_machine_code();

        gen.display_all();


        // --------------------------------------------------------------------
        // Clear instruction memory before loading the generated program.
        // --------------------------------------------------------------------

        for (int i = 0; i < 64; i++) begin
            dut.imem.RAM[i] = 32'h0000_0000;
        end


        // --------------------------------------------------------------------
        // Load the generated machine-code program into DUT instruction memory.
        //
        // The generator used $writememh to create this file.
        // Here the testbench uses $readmemh to copy it into the processor.
        // --------------------------------------------------------------------

        $readmemh(
            "generated/generated_program.mem",
            dut.imem.RAM
        );


        $display("");
        $display("==============================================");
        $display(" PROGRAM LOADED INTO MIPS INSTRUCTION MEMORY");
        $display("==============================================");
        $display("");


        // Keep reset asserted for two clock cycles.
        repeat (2) @(negedge clk);


        // Start processor execution.
        reset = 1'b0;

        $display(
            "[TB] Reset deasserted at time %0t. Processor starting.",
            $time
        );

    end


    // ------------------------------------------------------------------------
    // Instruction-fetch monitor
    //
    // This is mainly useful for terminal/debugging and for confirming
    // that the generated instructions are actually being fetched.
    // ------------------------------------------------------------------------

    always @(posedge clk) begin

        if (!reset) begin

            $display(
                "[FETCH] time=%0t PC=0x%08h instruction=0x%08h",
                $time,
                dut.pc,
                dut.instr
            );

        end

    end


    // ------------------------------------------------------------------------
    // End-of-simulation trickbox
    //
    // The final generated sequence loads 0xDEADBEEF from address 0x0C and
    // stores it back to address 0x0C.
    //
    // When the testbench observes:
    //
    //     MemWrite  = 1
    //     Address   = 0x0000000C
    //     WriteData = 0xDEADBEEF
    //
    // the generated program has reached its end.
    // ------------------------------------------------------------------------

    always @(posedge clk) begin

        if (!reset &&
            memwrite &&
            (dataadr   == 32'h0000_000C) &&
            (writedata == 32'hDEAD_BEEF)) begin

            $display("");
            $display("==============================================");
            $display(" END-OF-SIMULATION TRICKBOX DETECTED");
            $display(" Address = 0x%08h", dataadr);
            $display(" Data    = 0x%08h", writedata);
            $display(" Simulation completed successfully.");
            $display("==============================================");
            $display("");

            #1;
            $finish;

        end

    end


    // ------------------------------------------------------------------------
    // Simulation timeout
    // ------------------------------------------------------------------------

    initial begin

        #10000;

        $fatal(
            1,
            "TEST TIMEOUT: End-of-simulation trickbox was not reached."
        );

    end


    // ------------------------------------------------------------------------
    // Waveform
    // ------------------------------------------------------------------------

    initial begin

        $fsdbDumpfile("lab5_part2.fsdb");

        $fsdbDumpvars(
            0,
            testbench
        );

    end

endmodule
