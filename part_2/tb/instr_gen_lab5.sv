// ============================================================================
// Constrained-Random MIPS Instruction Generator
//
// Supported instructions:
//   ADD, AND, LW, SW, BEQ
//
// Randomized GPR set:
//   $1, $2, $3, $4
//
// Data memory addresses:
//   0x00, 0x04, 0x08, 0x0C
//
// Dependency gaps:
//   1, 2, 3, 4
//
// BEQ offsets:
//   1, 2, 3, 4
// ============================================================================

import uvm_pkg::*;
`include "uvm_macros.svh"


// ============================================================================
// Instruction transaction
// ============================================================================

class instruction extends uvm_transaction;

    typedef enum bit [2:0] {
        I_ADD,
        I_AND,
        I_LW,
        I_SW,
        I_BEQ
    } instr_kind_e;


    // ------------------------------------------------------------------------
    // Randomizable instruction information
    // ------------------------------------------------------------------------

    rand instr_kind_e kind;

    rand bit [4:0] rs;
    rand bit [4:0] rt;
    rand bit [4:0] rd;

    // Byte address used by LW/SW
    rand bit [15:0] mem_addr;

    // BEQ offset in instructions
    rand bit [15:0] branch_offset;

    // Used when intentionally generating taken/not-taken branches
    rand bit branch_taken;

    // Number of instructions between a dependent pair
    rand int unsigned gap;


    // ------------------------------------------------------------------------
    // Constraints
    // ------------------------------------------------------------------------

    // Randomized general-purpose registers are limited to $1-$4.
    //
    // LW/SW use $0 only as a fixed base register so that the effective
    // address is exactly mem_addr. $0 is not randomized.
    constraint c_registers {

        if (kind inside {I_LW, I_SW})
            rs == 5'd0;
        else
            rs inside {5'd1, 5'd2, 5'd3, 5'd4};

        rt inside {5'd1, 5'd2, 5'd3, 5'd4};

        rd inside {5'd1, 5'd2, 5'd3, 5'd4};
    }


    // Restrict memory accesses to the four required addresses.
    //
    // Address 0x0C is reserved from RANDOM SW instructions because it will
    // later be used for the end-of-simulation trickbox. A final explicit SW
    // will still exercise address 0x0C.
    constraint c_memory_address {

        if (kind == I_LW)
            mem_addr inside {
                16'h0000,
                16'h0004,
                16'h0008,
                16'h000C
            };

        if (kind == I_SW)
            mem_addr inside {
                16'h0000,
                16'h0004,
                16'h0008
            };
    }


    // Only the four required dependency gaps.
    constraint c_gap {
        gap inside {1, 2, 3, 4};
    }


    // Only the four required BEQ offsets.
    constraint c_branch_offset {

        if (kind == I_BEQ)
            branch_offset inside {1, 2, 3, 4};
    }


    // For a taken branch, comparing a register with itself guarantees equality.
    //
    // For a not-taken branch, use two different registers. The generator
    // reloads known different values before creating the not-taken scenario.
    constraint c_branch_behavior {

        if ((kind == I_BEQ) && branch_taken)
            rs == rt;

        if ((kind == I_BEQ) && !branch_taken)
            rs != rt;
    }


    // ------------------------------------------------------------------------
    // UVM registration
    // ------------------------------------------------------------------------

    `uvm_object_utils(instruction)


    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------

    function new(string name = "instruction");
        super.new(name);
    endfunction


    // ------------------------------------------------------------------------
    // Convert instruction to 32-bit MIPS machine code
    // ------------------------------------------------------------------------

    function bit [31:0] encode();

        bit [31:0] code;

        case (kind)

            // ADD rd, rs, rt
            I_ADD: begin
                code = {
                    6'b000000,
                    rs,
                    rt,
                    rd,
                    5'b00000,
                    6'b100000
                };
            end


            // AND rd, rs, rt
            I_AND: begin
                code = {
                    6'b000000,
                    rs,
                    rt,
                    rd,
                    5'b00000,
                    6'b100100
                };
            end


            // LW rt, offset($0)
            I_LW: begin
                code = {
                    6'b100011,
                    5'd0,
                    rt,
                    mem_addr
                };
            end


            // SW rt, offset($0)
            I_SW: begin
                code = {
                    6'b101011,
                    5'd0,
                    rt,
                    mem_addr
                };
            end


            // BEQ rs, rt, offset
            I_BEQ: begin
                code = {
                    6'b000100,
                    rs,
                    rt,
                    branch_offset
                };
            end


            default: begin
                code = 32'h0000_0000;
            end

        endcase

        return code;

    endfunction


    // ------------------------------------------------------------------------
    // Return instruction name
    // ------------------------------------------------------------------------

    function string kind_name();

        case (kind)
            I_ADD: return "ADD";
            I_AND: return "AND";
            I_LW : return "LW";
            I_SW : return "SW";
            I_BEQ: return "BEQ";
            default: return "UNKNOWN";
        endcase

    endfunction


    // ------------------------------------------------------------------------
    // Print readable form of instruction
    // ------------------------------------------------------------------------

    function void print_me();

        case (kind)

            I_ADD:
                $display(
                    "ADD  $%0d, $%0d, $%0d",
                    rd, rs, rt
                );

            I_AND:
                $display(
                    "AND  $%0d, $%0d, $%0d",
                    rd, rs, rt
                );

            I_LW:
                $display(
                    "LW   $%0d, 0x%04h($0)",
                    rt, mem_addr
                );

            I_SW:
                $display(
                    "SW   $%0d, 0x%04h($0)",
                    rt, mem_addr
                );

            I_BEQ:
                $display(
                    "BEQ  $%0d, $%0d, offset=%0d",
                    rs, rt, branch_offset
                );

        endcase

    endfunction

endclass



// ============================================================================
// Instruction stream generator
// ============================================================================

class instruction_generator;

    instruction instr_list[];

    bit [31:0] machine_code_list[];


    // Number of additional random individual instructions
    int unsigned num_random_instr = 10;


    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------

    function new();
    endfunction


    // ------------------------------------------------------------------------
    // Add instruction to dynamic array
    // ------------------------------------------------------------------------

    function void append_instruction(instruction instr);

        int old_size;

        old_size = instr_list.size();

        instr_list = new[old_size + 1](instr_list);

        instr_list[old_size] = instr;

    endfunction


    // ------------------------------------------------------------------------
    // Create a manually specified LW instruction
    // ------------------------------------------------------------------------

    function instruction make_lw(
        bit [4:0] rt,
        bit [15:0] address
    );

        instruction instr;

        instr = new();

        instr.kind     = instruction::I_LW;
        instr.rs       = 5'd0;
        instr.rt       = rt;
        instr.rd       = 5'd1;
        instr.mem_addr = address;

        return instr;

    endfunction


    // ------------------------------------------------------------------------
    // Create a manually specified SW instruction
    // ------------------------------------------------------------------------

    function instruction make_sw(
        bit [4:0] rt,
        bit [15:0] address
    );

        instruction instr;

        instr = new();

        instr.kind     = instruction::I_SW;
        instr.rs       = 5'd0;
        instr.rt       = rt;
        instr.rd       = 5'd1;
        instr.mem_addr = address;

        return instr;

    endfunction


    // ------------------------------------------------------------------------
    // Basic setup instructions
    //
    // The testbench will initialize the first four data-memory words.
    // These LW instructions load known values into $1-$4.
    // ------------------------------------------------------------------------

    function void generate_setup();

        append_instruction(
            make_lw(5'd1, 16'h0000)
        );

        append_instruction(
            make_lw(5'd2, 16'h0004)
        );

        append_instruction(
            make_lw(5'd3, 16'h0008)
        );

        append_instruction(
            make_lw(5'd4, 16'h000C)
        );

    endfunction


    // ------------------------------------------------------------------------
    // Generate individual constrained-random instructions
    //
    // First guarantee one ADD, AND, LW and SW.
    // Additional instructions are then randomized.
    //
    // BEQ is generated separately so that taken/not-taken behavior can
    // be controlled safely.
    // ------------------------------------------------------------------------

    function void generate_individual();

        instruction instr;


        // Guarantee ADD
        instr = new();

        assert(
            instr.randomize() with {
                kind == instruction::I_ADD;
            }
        )
        else
            $fatal(1, "Failed to randomize ADD instruction");

        append_instruction(instr);


        // Guarantee AND
        instr = new();

        assert(
            instr.randomize() with {
                kind == instruction::I_AND;
            }
        )
        else
            $fatal(1, "Failed to randomize AND instruction");

        append_instruction(instr);


        // Guarantee LW
        instr = new();

        assert(
            instr.randomize() with {
                kind == instruction::I_LW;
            }
        )
        else
            $fatal(1, "Failed to randomize LW instruction");

        append_instruction(instr);


        // Guarantee SW
        instr = new();

        assert(
            instr.randomize() with {
                kind == instruction::I_SW;
            }
        )
        else
            $fatal(1, "Failed to randomize SW instruction");

        append_instruction(instr);


        // Additional random non-branch instructions
        repeat (num_random_instr) begin

            instr = new();

            assert(
                instr.randomize() with {
                    kind inside {
                        instruction::I_ADD,
                        instruction::I_AND,
                        instruction::I_LW,
                        instruction::I_SW
                    };
                }
            )
            else
                $fatal(1, "Failed to randomize instruction");

            append_instruction(instr);

        end

    endfunction


    // ------------------------------------------------------------------------
    // Register dependency pair
    //
    // ADD produces a value.
    // AND later consumes that same register.
    //
    // Gap is randomized to 1, 2, 3 or 4 instructions.
    // SW instructions are used as fillers because they do not overwrite
    // the producer register.
    // ------------------------------------------------------------------------

    function void generate_register_dependency();

        instruction producer;
        instruction consumer;
        instruction filler;

        int unsigned selected_gap;


        producer = new();

        assert(
            producer.randomize() with {
                kind == instruction::I_ADD;
            }
        )
        else
            $fatal(1, "Failed to randomize dependency producer");


        selected_gap = producer.gap;

        append_instruction(producer);


        // Insert randomized gap
        repeat (selected_gap) begin

            filler = new();

            assert(
                filler.randomize() with {
                    kind == instruction::I_SW;
                }
            )
            else
                $fatal(1, "Failed to randomize dependency filler");

            append_instruction(filler);

        end


        // AND consumes the ADD destination register
        consumer = new();

        assert(
            consumer.randomize() with {
                kind == instruction::I_AND;

                rs == producer.rd;
            }
        )
        else
            $fatal(1, "Failed to randomize dependency consumer");

        append_instruction(consumer);


        $display(
            "[GEN] Register dependency: ADD -> gap %0d -> AND using $%0d",
            selected_gap,
            producer.rd
        );

    endfunction


    // ------------------------------------------------------------------------
    // Memory dependency pair
    //
    // SW writes an address.
    // LW later reads the same address.
    //
    // Gap is randomized to 1, 2, 3 or 4 instructions.
    // ------------------------------------------------------------------------

    function void generate_memory_dependency();

        instruction store_instr;
        instruction load_instr;
        instruction filler;

        int unsigned selected_gap;


        store_instr = new();

        assert(
            store_instr.randomize() with {
                kind == instruction::I_SW;
            }
        )
        else
            $fatal(1, "Failed to randomize SW dependency");


        selected_gap = store_instr.gap;

        append_instruction(store_instr);


        // Fill the required gap with arithmetic instructions.
        repeat (selected_gap) begin

            filler = new();

            assert(
                filler.randomize() with {
                    kind inside {
                        instruction::I_ADD,
                        instruction::I_AND
                    };
                }
            )
            else
                $fatal(1, "Failed to randomize memory dependency filler");

            append_instruction(filler);

        end


        load_instr = new();

        assert(
            load_instr.randomize() with {
                kind == instruction::I_LW;

                mem_addr == store_instr.mem_addr;
            }
        )
        else
            $fatal(1, "Failed to randomize LW dependency");


        append_instruction(load_instr);


        $display(
            "[GEN] Memory dependency: SW -> gap %0d -> LW at address 0x%04h",
            selected_gap,
            store_instr.mem_addr
        );

    endfunction


    // ------------------------------------------------------------------------
    // Generate controlled BEQ scenarios
    //
    // Reload $1 and $2 before branches so that their values are known.
    //
    // $1 and $2 will contain different values from testbench initialization.
    // ------------------------------------------------------------------------

    function void generate_branches();

        instruction branch_instr;
        instruction filler;

        int unsigned selected_offset;


        // Reload known different values.
        append_instruction(
            make_lw(5'd1, 16'h0000)
        );

        append_instruction(
            make_lw(5'd2, 16'h0004)
        );


        // ------------------------------------------------------------
        // Taken branch
        // ------------------------------------------------------------

        branch_instr = new();

        assert(
            branch_instr.randomize() with {
                kind == instruction::I_BEQ;

                branch_taken == 1'b1;

                rs == 5'd1;
                rt == 5'd1;
            }
        )
        else
            $fatal(1, "Failed to randomize taken BEQ");


        selected_offset = branch_instr.branch_offset;

        append_instruction(branch_instr);


        // These instructions should be skipped by the taken branch.
        repeat (selected_offset) begin

            filler = new();

            assert(
                filler.randomize() with {
                    kind inside {
                        instruction::I_ADD,
                        instruction::I_AND
                    };
                }
            )
            else
                $fatal(1, "Failed to randomize branch filler");

            append_instruction(filler);

        end


        // Safe target instruction.
        filler = new();

        assert(
            filler.randomize() with {
                kind == instruction::I_AND;
            }
        )
        else
            $fatal(1, "Failed to randomize taken branch target");

        append_instruction(filler);


        // ------------------------------------------------------------
        // Load two values that are guaranteed to differ before the
        // not-taken branch.
        //
        // Random SW instructions can leave addresses 0x00 and 0x04 holding
        // the same value, which would turn this branch into a taken one.
        // Address 0x0C is never written by a random SW, so it still holds
        // 0xDEADBEEF. $2 = $1 + $1 then differs from $1.
        // ------------------------------------------------------------

        append_instruction(
            make_lw(5'd1, 16'h000C)
        );

        filler = new();

        assert(
            filler.randomize() with {
                kind == instruction::I_ADD;

                rd == 5'd2;
                rs == 5'd1;
                rt == 5'd1;
            }
        )
        else
            $fatal(1, "Failed to randomize not-taken branch operand");

        append_instruction(filler);


        // ------------------------------------------------------------
        // Not-taken branch
        // ------------------------------------------------------------

        branch_instr = new();

        assert(
            branch_instr.randomize() with {
                kind == instruction::I_BEQ;

                branch_taken == 1'b0;

                rs == 5'd1;
                rt == 5'd2;
            }
        )
        else
            $fatal(1, "Failed to randomize not-taken BEQ");


        selected_offset = branch_instr.branch_offset;

        append_instruction(branch_instr);


        // Since this branch is not taken, these instructions execute normally.
        repeat (selected_offset) begin

            filler = new();

            assert(
                filler.randomize() with {
                    kind inside {
                        instruction::I_ADD,
                        instruction::I_AND
                    };
                }
            )
            else
                $fatal(1, "Failed to randomize branch filler");

            append_instruction(filler);

        end


        filler = new();

        assert(
            filler.randomize() with {
                kind == instruction::I_ADD;
            }
        )
        else
            $fatal(1, "Failed to randomize branch target");

        append_instruction(filler);


        $display(
            "[GEN] Generated both taken and not-taken BEQ scenarios"
        );

    endfunction


    // ------------------------------------------------------------------------
    // End-of-simulation sequence
    //
    // Data memory address 0x0C will initially contain 0xDEADBEEF.
    //
    // Reload that value into $4, then store it back to address 0x0C.
    //
    // The testbench will detect:
    //
    //     address = 0x0000000C
    //     data    = 0xDEADBEEF
    //
    // and end simulation.
    // ------------------------------------------------------------------------

    function void generate_end_sequence();

        append_instruction(
            make_lw(5'd4, 16'h000C)
        );

        append_instruction(
            make_sw(5'd4, 16'h000C)
        );

    endfunction


    // ------------------------------------------------------------------------
    // Build complete instruction stream
    // ------------------------------------------------------------------------

    function void generate_sequence();

        instr_list = new[0];

        $display("");
        $display("==============================================");
        $display(" LAB 5 RANDOM INSTRUCTION GENERATOR");
        $display("==============================================");


        generate_setup();

        generate_individual();

        generate_register_dependency();

        generate_memory_dependency();

        generate_branches();

        generate_end_sequence();


        $display(
            "[GEN] Total generated instructions = %0d",
            instr_list.size()
        );

    endfunction


    // ------------------------------------------------------------------------
    // Generate machine-code dynamic array and write program to file
    // ------------------------------------------------------------------------

    function void generate_machine_code();

        generate_sequence();


        machine_code_list = new[instr_list.size()];


        foreach (instr_list[i]) begin

            machine_code_list[i] = instr_list[i].encode();

        end


        $writememh(
            "generated/generated_program.mem",
            machine_code_list
        );


        $display(
            "[GEN] Program written to generated/generated_program.mem"
        );

    endfunction


    // ------------------------------------------------------------------------
    // Display entire generated program
    // ------------------------------------------------------------------------

    function void display_all();

        $display("");
        $display("==============================================");
        $display(" GENERATED PROGRAM");
        $display("==============================================");


        foreach (instr_list[i]) begin

            $write(
                "[%0d] PC=0x%08h  MACHINE=0x%08h  ",
                i,
                i * 4,
                machine_code_list[i]
            );

            instr_list[i].print_me();

        end


        $display("==============================================");
        $display("");

    endfunction

endclass 