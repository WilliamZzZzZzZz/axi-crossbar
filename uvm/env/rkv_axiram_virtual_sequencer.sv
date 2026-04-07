`ifndef RKV_AXIRAM_VIRTUAL_SEQUENCER_SV
`define RKV_AXIRAM_VIRTUAL_SEQUENCER_SV

class rkv_axiram_virtual_sequencer extends uvm_sequencer;

  // Sub-sequencer handles for routing
  rkv_axiram_config cfg;
  lvc_axi_master_sequencer axi_mst_sqr;

  `uvm_component_utils(rkv_axiram_virtual_sequencer)

  function new(string name = "rkv_axiram_virtual_sequencer", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Get configuration from config DB
    if(!uvm_config_db#(rkv_axiram_config)::get(this, "", "cfg", cfg)) begin
      `uvm_fatal("GETCFG", "Cannot get config object from config DB")
    end
  endfunction

endclass

`endif // RKV_AXIRAM_VIRTUAL_SEQUENCER_SV
