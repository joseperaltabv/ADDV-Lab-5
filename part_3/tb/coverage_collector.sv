// Receives the instruction transactions from the monitor and samples the
// functional coverage model. Lab 5 handout, Part 3, Coverage Collector.
class coverage_collector extends uvm_subscriber #(instruction);
    `uvm_component_utils(coverage_collector)

    instruction tr;              // the instruction being sampled
    instruction history[$];      // the five instructions before it, newest first

    // One observed dependency, filled in before its covergroup is sampled.
    instruction::instr_kind_e producer_kind, consumer_kind;
    bit [4:0]  dependency_register;
    bit [15:0] dependency_address;
    int        gap;              // instructions between the producer and the consumer

    // REQ P3: specific fields of individual instructions
    covergroup instr_fields_cg;
        kind: coverpoint tr.kind;
        rs:   coverpoint tr.rs iff (tr.kind inside {instruction::I_ADD, instruction::I_AND, instruction::I_BEQ}) {
            bins r[] = {[1:4]};
        }
        rt:   coverpoint tr.rt {
            bins r[] = {[1:4]};
        }
        rd:   coverpoint tr.rd iff (tr.kind inside {instruction::I_ADD, instruction::I_AND}) {
            bins r[] = {[1:4]};
        }

        memory_kind: coverpoint tr.kind iff (tr.kind inside {instruction::I_LW, instruction::I_SW}) {
            bins load  = {instruction::I_LW};
            bins store = {instruction::I_SW};
        }
        memory_address: coverpoint tr.mem_addr iff (tr.kind inside {instruction::I_LW, instruction::I_SW}) {
            bins addr_0 = {16'h0000};
            bins addr_4 = {16'h0004};
            bins addr_8 = {16'h0008};
            bins addr_C = {16'h000C};
        }
        memory_kind_x_address: cross memory_kind, memory_address;

        branch_offset: coverpoint tr.branch_offset iff (tr.kind == instruction::I_BEQ) {
            bins offset[] = {[1:4]};
        }
        // REQ P3: branch taken, not taken
        branch: coverpoint tr.branch_taken iff (tr.kind == instruction::I_BEQ) {
            bins not_taken = {0};
            bins taken     = {1};
        }
        branch_x_offset: cross branch, branch_offset;
    endgroup

    // An arithmetic instruction reads a register that an earlier arithmetic
    // instruction wrote, with 1 to 4 instructions between them.
    covergroup register_dependency_cg;
        // REQ P3: specific orders of instructions
        producer: coverpoint producer_kind {
            bins kind[] = {instruction::I_ADD, instruction::I_AND};
        }
        consumer: coverpoint consumer_kind {
            bins kind[] = {instruction::I_ADD, instruction::I_AND};
        }
        order: cross producer, consumer;
        // REQ P3: dependencies in register names
        register: coverpoint dependency_register {
            bins r[] = {[1:4]};
        }
        // REQ P3: specific gaps between instructions
        register_gap: coverpoint gap {
            bins gap[] = {[1:4]};
        }
    endgroup

    // A load reads an address that an earlier store wrote, with 1 to 4
    // instructions between them.
    covergroup memory_dependency_cg;
        // REQ P3: dependencies in memory addresses
        // 0x0C is left out: only the last instruction of a program stores there.
        address: coverpoint dependency_address {
            bins addr_0 = {16'h0000};
            bins addr_4 = {16'h0004};
            bins addr_8 = {16'h0008};
        }
        // REQ P3: specific gaps between instructions
        memory_gap: coverpoint gap {
            bins gap[] = {[1:4]};
        }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        instr_fields_cg        = new();
        register_dependency_cg = new();
        memory_dependency_cg   = new();
    endfunction

    // REQ P3: sample as instruction transactions come in through the port.
    // uvm_subscriber already has the uvm_analysis_imp (analysis_export) that calls this.
    function void write(instruction t);
        tr = t;
        instr_fields_cg.sample();
        sample_register_dependencies();
        sample_memory_dependency();

        history.push_front(tr);
        if (history.size() > 5) void'(history.pop_back());
    endfunction

    function void sample_register_dependencies();
        if (!(tr.kind inside {instruction::I_ADD, instruction::I_AND})) return;

        sample_register_dependency(tr.rs);
        if (tr.rt != tr.rs) sample_register_dependency(tr.rt);
    endfunction

    // The producer is the most recent instruction that wrote the register.
    // history[n] has n instructions between it and tr.
    function void sample_register_dependency(bit [4:0] source);
        foreach (history[n]) begin
            if (destination(history[n]) != source) continue;

            if (n >= 1 && history[n].kind inside {instruction::I_ADD, instruction::I_AND}) begin
                producer_kind       = history[n].kind;
                consumer_kind       = tr.kind;
                dependency_register = source;
                gap                 = n;
                register_dependency_cg.sample();
            end
            return;
        end
    endfunction

    function void sample_memory_dependency();
        if (tr.kind != instruction::I_LW) return;

        foreach (history[n]) begin
            if (history[n].kind != instruction::I_SW || history[n].mem_addr != tr.mem_addr) continue;

            if (n >= 1) begin
                dependency_address = tr.mem_addr;
                gap                = n;
                memory_dependency_cg.sample();
            end
            return;
        end
    endfunction

    // The register an instruction writes, or 0 when it writes none.
    function bit [4:0] destination(instruction i);
        case (i.kind)
            instruction::I_ADD, instruction::I_AND: return i.rd;
            instruction::I_LW:                      return i.rt;
            default:                                return 5'd0;
        endcase
    endfunction
endclass
