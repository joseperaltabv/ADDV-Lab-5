// Creates the monitor and the coverage collector and connects them. Lab 5 handout, Part 3, Environment.
class instr_env extends uvm_env;
    `uvm_component_utils(instr_env)

    instr_monitor      monitor;
    coverage_collector coverage;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor  = instr_monitor::type_id::create("monitor", this);
        coverage = coverage_collector::type_id::create("coverage", this);
    endfunction

    // REQ P3: monitor's analysis port -> coverage collector
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        monitor.ap.connect(coverage.analysis_export);
    endfunction
endclass
