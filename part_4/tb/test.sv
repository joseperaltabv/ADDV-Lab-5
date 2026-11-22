// Creates the environment. The stimulus does not come through UVM in this lab,
// so the test has nothing else to do. Lab 5 handout, Part 3, Test.
class instr_test extends uvm_test;
    `uvm_component_utils(instr_test)

    instr_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = instr_env::type_id::create("env", this);
    endfunction

    // Keeps the run phase open. The testbench trickbox ends the simulation with $finish.
    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
    endtask
endclass
