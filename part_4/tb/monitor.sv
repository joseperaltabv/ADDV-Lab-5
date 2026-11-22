// Watches the instruction fetch interface and posts one instruction transaction
// for every instruction the processor executes. Lab 5 handout, Part 3, Monitor.
class instr_monitor extends uvm_monitor;
    `uvm_component_utils(instr_monitor)

    virtual fetch_if vif;
    uvm_analysis_port #(instruction) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_resource_db #(virtual fetch_if)::read_by_name("ifs", "fetch_if", vif))
            `uvm_fatal(get_name(), "fetch_if was not registered by the testbench")
    endfunction

    // REQ P3: observe the fetch interface, create a transaction, post it
    task run_phase(uvm_phase phase);
        bit [31:0]  fetched_pc, fetched_instr;   // the instruction sitting in fetch
        bit         flushed;                     // it will be discarded by a taken branch
        instruction in_decode;                   // left fetch; its branch outcome is not known yet

        forever begin
            // Mid-cycle, pc and instr have settled and belong to this cycle.
            @(negedge vif.clk);

            // A new pc means the fetched instruction moved on to decode.
            // A stalled instruction keeps its pc and is counted once.
            // During reset the pc rests on the first instruction, which is
            // remembered here so that it is not missed when reset is released.
            if (!vif.reset && vif.pc != fetched_pc) begin
                if (!flushed) begin
                    post(in_decode);
                    in_decode = decode(fetched_instr);
                end
                flushed = 0;
            end

            // REQ P3: branch taken / not taken is what the processor did, not what was generated
            if (!vif.reset && vif.branch_taken) begin
                in_decode.branch_taken = 1;
                flushed = 1;
            end

            fetched_pc    = vif.pc;
            fetched_instr = vif.instr;
        end
    endtask

    function void post(instruction tr);
        if (tr == null) return;
        `uvm_info(get_name(), $sformatf("%s rs=%0d rt=%0d rd=%0d imm=0x%04h taken=%0b",
                  tr.kind_name(), tr.rs, tr.rt, tr.rd, tr.mem_addr, tr.branch_taken), UVM_MEDIUM)
        ap.write(tr);
    endfunction

    // The reverse of instruction::encode. Anything outside the five instructions
    // (the empty words after the program) gives null and is not posted.
    function instruction decode(bit [31:0] code);
        instruction tr = instruction::type_id::create("tr");

        tr.rs            = code[25:21];
        tr.rt            = code[20:16];
        tr.rd            = code[15:11];
        tr.mem_addr      = code[15:0];
        tr.branch_offset = code[15:0];
        tr.branch_taken  = 0;

        case (code[31:26])
            6'b100011: tr.kind = instruction::I_LW;
            6'b101011: tr.kind = instruction::I_SW;
            6'b000100: tr.kind = instruction::I_BEQ;
            6'b000000:
                case (code[5:0])
                    6'b100000: tr.kind = instruction::I_ADD;
                    6'b100100: tr.kind = instruction::I_AND;
                    default:   return null;
                endcase
            default: return null;
        endcase

        return tr;
    endfunction
endclass
