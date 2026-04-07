`ifndef RKV_AXIRAM_SEQ_LIB_SVH
`define RKV_AXIRAM_SEQ_LIB_SVH

// Element sequences (AXI protocol level)
`include "elem_seqs/lvc_axi_master_single_write_seq.sv"
`include "elem_seqs/lvc_axi_master_single_read_seq.sv"
`include "elem_seqs/lvc_axi_master_burst_write_seq.sv"
`include "elem_seqs/lvc_axi_master_burst_read_seq.sv"

// Virtual sequences (test level)
`include "rkv_axiram_base_virtual_sequence.sv"
`include "rkv_axiram_smoke_virt_seq.sv"

`endif // RKV_AXIRAM_SEQ_LIB_SVH
