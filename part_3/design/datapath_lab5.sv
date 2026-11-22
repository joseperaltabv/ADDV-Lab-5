//////////////////////////////////////////////////////////////////////
// ===================================================================
// This file has the following module implementations:
// 1. datapath
// 2. regfile
// 3. alu
// 4. adder
// 5. mux2
// 6. sl2
// 7. signext
// 8. flopr
// ===================================================================
//////////////////////////////////////////////////////////////////////
// Datapath module
//////////////////////////////////////////////////////////////////////
module datapath (
    input clk, reset,
    input memtoreg, pcsrc,
    input alusrc, regdst,
    input regwrite, jump,
    input memwriteD,
    output logic memwriteM,
    input [2:0] alucontrol,
    output zero,
    output [31:0] pc,
    input [31:0] instr,
    output [31:0] aluout, writedata,
    input [31:0] readdata,
    output logic [31:0] instrD
    );

    // ========================================
    // Fetch-stage signals
    // ========================================
    logic [31:0] pcF;
    logic [31:0] instrF;
    logic [31:0] pcplus4F;

    // Next-PC signals
    logic [31:0] pcnext, pcnextbr, pcbranch;

    // Original datapath signals
    logic [4:0] writereg;
    logic [31:0] signimm, signimmsh;
    logic [31:0] srca;
    logic [31:0] rd2D;
    logic [31:0] rd1RF, rd2RF;
    logic zeroE;
    logic [31:0] signimmD;

    logic stallF, stallD;
    logic takeBranchD, takeJumpD, redirectD;

    // ========================================
    // Decode-stage pipeline registers
    // ========================================
    logic [31:0] pcplus4D;
    logic validD;
    
    // ========================================
    // FETCH STAGE
    // ========================================

    // Connect the existing processor ports to Fetch signals
    assign pcF = pc;
    assign instrF = instr;

    // Program counter register
    flopenr #(32) pcreg(
        .clk(clk),
        .reset(reset),
        .en(!stallF),
        .d(pcnext),
        .q(pc)
    );

    // Calculate PC + 4
    adder pcadd1(
        pcF, 32'd4, pcplus4F
    );

    // Temporary original branch and jump logic
    sl2 immsh(
        signimmD, signimmsh
    );

    adder pcadd2(
        pcplus4D, signimmsh, pcbranch
    );

    mux2 #(32) pcbrmux(
        pcplus4F, pcbranch, takeBranchD, pcnextbr
    );

    mux2 #(32) pcmux(
        pcnextbr,
        {pcplus4D[31:28], instrD[25:0], 2'b00},
        takeJumpD,
        pcnext
    );

    // ========================================
    // FETCH TO DECODE PIPELINE REGISTERS
    // ========================================

    always_ff @(posedge clk or posedge reset) begin

        if (reset) begin
            instrD   <= 32'b0;
            pcplus4D <= 32'b0;
            validD   <= 1'b0;
        end

        else if (redirectD) begin
            // Discard incorrectly fetched instruction
            instrD   <= 32'b0;
            pcplus4D <= 32'b0;
            validD   <= 1'b0;
        end

        else if (!stallD) begin
            // Advance to the next instruction
            instrD   <= instrF;
            pcplus4D <= pcplus4F;
            validD   <= 1'b1;
        end

        // If stalled, retain all existing values

    end

    // ========================================
    // DECODE STAGE
    // ========================================

    // Instruction fields
    logic [5:0] opD, functD;
    logic [4:0] rsD, rtD, rdD;
    logic [15:0] immD;

    // Sign-extended immediate for Decode

    // ========================================
    // Execute-stage registers
    // ========================================
    logic [31:0] instrE;
    logic [31:0] pcplus4E;
    logic [31:0] signimmE;
    logic [31:0] aluoutE;
    logic [4:0] rsE, rtE, rdE;
    logic validE;

    // ========================================
    // Memory-stage registers
    // ========================================
    logic [31:0] aluoutM;
    logic [31:0] writedataM;
    logic [4:0]  writeregM;

    logic regwriteM;
    logic memtoregM;
    logic validM;

    // ========================================
    // Writeback-stage registers
    // ========================================
    logic [31:0] aluoutW;
    logic [31:0] readdataW;
    logic [4:0]  writeregW;

    logic regwriteW;
    logic memtoregW;
    logic validW;

    logic [31:0] resultW;

    // Register operands for Execute
    logic [31:0] rd1E, rd2E;
    logic [31:0] srcbE;

    // Execute-stage forwarding signals
    logic [31:0] srcaE;
    logic [31:0] writedataE;

    logic [1:0] forwardAE;
    logic [1:0] forwardBE;

    // ========================================
    // Hazard detection signals
    // ========================================
    logic usesRsD, usesRtD;

    logic lwstallD;
    logic branchstallD;

    logic flushE;

    // Control signals for Execute and later stages
    logic regwriteE, memtoregE, memwriteE;
    logic alusrcE, regdstE;
    logic [2:0] alucontrolE;

    // Extract fields from the registered instruction
    assign opD    = instrD[31:26];
    assign rsD    = instrD[25:21];
    assign rtD    = instrD[20:16];
    assign rdD    = instrD[15:11];
    assign immD   = instrD[15:0];
    assign functD = instrD[5:0];

    // Sign extension for the Decode-stage instruction
    signext seD(
        immD,
        signimmD
    );

    // Read the source registers of the Decode-stage instruction
    regfile rf(
        .clk(clk),
        .we3(regwriteW),
        .ra1(rsD),
        .ra2(rtD),
        .wa3(writeregW),
        .wd3(resultW),
        .rd1(rd1RF),
        .rd2(rd2RF)
    );

    // ========================================
    // WRITEBACK TO DECODE BYPASS
    // ========================================

    // First source register
    assign srca =
        (validW && regwriteW &&
        (writeregW != 5'd0) &&
        (writeregW == rsD))
        ? resultW : rd1RF;

    // Second source register
    assign rd2D =
        (validW && regwriteW &&
        (writeregW != 5'd0) &&
        (writeregW == rtD))
        ? resultW : rd2RF;

    // Compare register operands for BEQ in Decode
    assign zero = (srca == rd2D);

    // ========================================
    // HAZARD DETECTION
    // ========================================

    // Determine which source registers the
    // Decode-stage instruction actually uses.
    always_comb begin
        usesRsD = 1'b1;
        usesRtD = 1'b1;

        case (opD)
            // LW and ADDI read rs, but not rt
            6'b100011, 6'b001000: begin
                usesRtD = 1'b0;
            end

            // Jump doesn't read either register
            6'b000010: begin
                usesRsD = 1'b0;
                usesRtD = 1'b0;
            end

            default: begin
                // R-type, SW and BEQ
            end
        endcase
    end


    // Detect when Decode needs the result
    // of a load currently in Execute.
    assign lwstallD =
        validD && validE &&
        memtoregE && regwriteE &&
        (rtE != 5'd0) &&
        (
            (usesRsD && (rsD == rtE)) ||
            (usesRtD && (rtD == rtE))
        );


    // BEQ compares operands in Decode.
    // Wait if an earlier instruction in
    // Execute or Memory will produce them.
    assign branchstallD =
        validD && (opD == 6'b000100) &&
        (
            (
                validE && regwriteE &&
                (writereg != 5'd0) &&
                ((writereg == rsD) ||
                (writereg == rtD))
            )
            ||
            (
                validM && regwriteM &&
                (writeregM != 5'd0) &&
                ((writeregM == rsD) ||
                (writeregM == rtD))
            )
        );


    // Combined hazard-control signals
    assign stallD = lwstallD || branchstallD;
    assign stallF = stallD;
    assign flushE = stallD;

    // Redirect the PC only when Decode is ready
    assign takeBranchD = validD && !stallD && pcsrc;
    assign takeJumpD   = validD && !stallD && jump;

    assign redirectD = takeBranchD || takeJumpD;

    // ========================================
    // DECODE TO EXECUTE PIPELINE REGISTERS
    // ========================================

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            // Instruction information
            instrE   <= 32'b0;
            pcplus4E <= 32'b0;
            signimmE <= 32'b0;

            rsE <= 5'b0;
            rtE <= 5'b0;
            rdE <= 5'b0;

            // Register operands
            rd1E <= 32'b0;
            rd2E <= 32'b0;

            // Control signals
            regwriteE   <= 1'b0;
            memtoregE   <= 1'b0;
            memwriteE   <= 1'b0;
            alusrcE     <= 1'b0;
            regdstE     <= 1'b0;
            alucontrolE <= 3'b010;

            validE <= 1'b0;
        end
        else if (flushE) begin

        // Insert an empty instruction into Execute
        instrE   <= 32'b0;
        pcplus4E <= 32'b0;
        signimmE <= 32'b0;

        rsE <= 5'b0;
        rtE <= 5'b0;
        rdE <= 5'b0;

        rd1E <= 32'b0;
        rd2E <= 32'b0;

        // Disable all state-changing operations
        regwriteE   <= 1'b0;
        memtoregE   <= 1'b0;
        memwriteE   <= 1'b0;
        alusrcE     <= 1'b0;
        regdstE     <= 1'b0;
        alucontrolE <= 3'b010;

        validE <= 1'b0;
    end
        else begin
            // Instruction information
            instrE   <= instrD;
            pcplus4E <= pcplus4D;
            signimmE <= signimmD;

            rsE <= rsD;
            rtE <= rtD;
            rdE <= rdD;

            // Capture the register operands
            rd1E <= srca;
            rd2E <= rd2D;

            // Transfer control signals with the instruction
            regwriteE   <= validD && regwrite;
            memtoregE   <= memtoreg;
            memwriteE   <= validD && memwriteD;
            alusrcE     <= alusrc;
            regdstE     <= regdst;
            alucontrolE <= validD ? alucontrol : 3'b010;

            validE <= validD;
        end
    end

        // register file logic
        signext se(instr[15:0], signimm);
        
    // ========================================
    // EXECUTE STAGE
    // ========================================

    // Select the instruction's destination register
    mux2 #(5) wrmux(
        rtE,
        rdE,
        regdstE,
        writereg
    );

    // ========================================
    // EXECUTE-STAGE FORWARDING
    // ========================================

    // Determine which pipeline stage supplies
    // each source register's most recent value.
    always_comb begin

        // Default: use operands captured in ID/EX
        forwardAE = 2'b00;
        forwardBE = 2'b00;

        // Forward first operand from Memory if possible
        if (validM && regwriteM && !memtoregM &&
            (writeregM != 5'd0) &&
            (writeregM == rsE)) begin

            forwardAE = 2'b10;

        end
        // Otherwise, forward from Writeback
        else if (validW && regwriteW &&
                (writeregW != 5'd0) &&
                (writeregW == rsE)) begin

            forwardAE = 2'b01;

        end

        // Forward second register operand from Memory
        if (validM && regwriteM && !memtoregM &&
            (writeregM != 5'd0) &&
            (writeregM == rtE)) begin

            forwardBE = 2'b10;

        end
        // Otherwise, forward from Writeback
        else if (validW && regwriteW &&
                (writeregW != 5'd0) &&
                (writeregW == rtE)) begin

            forwardBE = 2'b01;

        end

    end


    // Select the actual forwarded operand values
    always_comb begin

        case (forwardAE)
            2'b10:   srcaE = aluoutM;
            2'b01:   srcaE = resultW;
            default: srcaE = rd1E;
        endcase

        case (forwardBE)
            2'b10:   writedataE = aluoutM;
            2'b01:   writedataE = resultW;
            default: writedataE = rd2E;
        endcase

    end

    // Select the second ALU operand
    mux2 #(32) srcbmux(
        writedataE,
        signimmE,
        alusrcE,
        srcbE
    );

    // Execute the operation using registered operands
    alu aluE(
        srcaE,
        srcbE,
        alucontrolE,
        aluoutE,
        zeroE
    );

    // ========================================
    // EXECUTE TO MEMORY PIPELINE REGISTERS
    // ========================================

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            aluoutM    <= 32'b0;
            writedataM <= 32'b0;
            writeregM  <= 5'b0;

            regwriteM  <= 1'b0;
            memtoregM  <= 1'b0;
            memwriteM  <= 1'b0;
            validM     <= 1'b0;
        end
        else begin
            // Capture Execute-stage results
            aluoutM    <= aluoutE;
            writedataM <= writedataE;
            writeregM  <= writereg;

            // Transfer the corresponding control signals
            regwriteM  <= validE && regwriteE;
            memtoregM  <= memtoregE;
            memwriteM  <= validE && memwriteE;
            validM     <= validE;
        end
    end

    // ========================================
    // MEMORY STAGE
    // ========================================
    assign aluout    = aluoutM;
    assign writedata = writedataM;

    // ========================================
    // MEMORY TO WRITEBACK PIPELINE REGISTERS
    // ========================================

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            aluoutW    <= 32'b0;
            readdataW  <= 32'b0;
            writeregW  <= 5'b0;

            regwriteW  <= 1'b0;
            memtoregW  <= 1'b0;
            validW     <= 1'b0;
        end
        else begin
            aluoutW    <= aluoutM;
            readdataW  <= readdata;
            writeregW  <= writeregM;

            regwriteW  <= validM && regwriteM;
            memtoregW  <= memtoregM;
            validW     <= validM;
        end
    end

    // ========================================
    // WRITEBACK STAGE
    // ========================================

    // Select either the ALU result or memory data
    mux2 #(32) resmux(
        aluoutW,
        readdataW,
        memtoregW,
        resultW
    );
endmodule


//////////////////////////////////////////////////////////////////////
// Register File Module
//////////////////////////////////////////////////////////////////////
module regfile (
    input clk,
    input we3,
    input [4:0] ra1, ra2, wa3,
    input [31:0] wd3,
    output [31:0] rd1, rd2
);
    
    logic [31:0] rf[31:0];
    // three ported register file
    // read two ports combinationally
    // write third port on rising edge of clock
    // register 0 hardwired to 0
    always_ff @(posedge clk) begin
        if (we3) 
            rf[wa3] <= wd3;
    end
    assign rd1 = (ra1 != 0) ? rf[ra1] : 0;
    assign rd2 = (ra2 != 0) ? rf[ra2] : 0;
endmodule

//////////////////////////////////////////////////////////////////////
// ALU Module
////////////////////////////////////////////////////////////////////// 
module alu(
    input [31:0] a,          // First operand
    input [31:0] b,          // Second operand
    input [2:0] control,     // ALU control signal
    output logic [31:0] result, // ALU result
    output zero              // Zero flag
);

    // Define ALU operations based on control signal
    localparam ALU_AND = 3'b000;
    localparam ALU_OR  = 3'b001;
    localparam ALU_ADD = 3'b010;
    localparam ALU_SUB = 3'b110;
    localparam ALU_SLT = 3'b111;
    
    // Calculate result based on control input
    always_comb begin
        case(control)
            ALU_AND: result = a & b;                     // AND
            ALU_OR:  result = a | b;                     // OR
            ALU_ADD: result = a + b;                     // ADD
            ALU_SUB: result = a - b;                     // SUB
            ALU_SLT: result = ($signed(a) < $signed(b)); // Set Less Than (signed)
            default: result = 32'bx;                     // Undefined operation
        endcase
    end
    
    // Set zero flag when result is 0
    assign zero = (result == 32'b0);
    
endmodule


//////////////////////////////////////////////////////////////////////
// Adder Module
//////////////////////////////////////////////////////////////////////
module adder (
    input [31:0] a, b,
    output [31:0] y
);
    assign y = a + b;
endmodule


//////////////////////////////////////////////////////////////////////
// 2-to-1 Multiplexer Module
//////////////////////////////////////////////////////////////////////
module mux2 # (parameter WIDTH = 8) (
    input [WIDTH-1:0] d0, d1,
    input s,
    output [WIDTH-1:0] y
);
    assign y = s ? d1 : d0;
endmodule


//////////////////////////////////////////////////////////////////////
// Shift Left by 2 Module
//////////////////////////////////////////////////////////////////////
module sl2 (
    input [31:0] a,
    output [31:0] y
);
    // shift left by 2
    assign y = {a[29:0], 2'b00};
endmodule


//////////////////////////////////////////////////////////////////////
// Sign Extension Module
//////////////////////////////////////////////////////////////////////
module signext (
    input [15:0] a,
    output [31:0] y
);
    assign y = {{16{a[15]}}, a};
endmodule


//////////////////////////////////////////////////////////////////////
// Flop Register Module
//////////////////////////////////////////////////////////////////////
module flopr # (parameter WIDTH = 8)(
    input clk, reset,
    input [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);
    always_ff @(posedge clk or posedge reset) begin
        if (reset) 
            q <= '0;
        else 
            q <= d;
    end
endmodule
// ========================================
// Register with enable and asynchronous reset
// ========================================

module flopenr #(parameter WIDTH = 8)(
    input logic clk,
    input logic reset,
    input logic en,
    input logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);

    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            q <= '0;
        else if (en)
            q <= d;
    end
endmodule
