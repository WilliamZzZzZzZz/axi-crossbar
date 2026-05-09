`ifndef AXICB_ORDER_RESP_VSEQ_SV
`define AXICB_ORDER_RESP_VSEQ_SV

class axicb_order_resp_vseq extends axicb_conc_base_vseq;
    `uvm_object_utils(axicb_order_resp_vseq)      

    function new(string name = "axicb_order_resp_vseq");
        super.new(name);
    endfunction

    virtual task body();
        super.body();
        `uvm_info(get_type_name(), "========== order_resp_test_start ==========", UVM_LOW)


        `uvm_info(get_type_name(), "========== order_resp_test_end ==========", UVM_LOW)
    endtask

    local task same_id_same_slave_allow();
        
    endtask

endclass

`endif 
