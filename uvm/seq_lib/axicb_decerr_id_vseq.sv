`ifndef AXICB_DECERR_ID_VSEQ_SV
`define AXICB_DECERR_ID_VSEQ_SV

class axicb_decerr_id_vseq extends axicb_decerr_base_vseq;
    `uvm_object_utils(axicb_decerr_id_vseq)

    function new(string name = "axicb_decerr_id_vseq");
        super.new(name);
    endfunction

    virtual task body();
        super.body();
        `uvm_info(get_type_name(), "========== decerr_id_test_start ==========", UVM_LOW)

        decerr_id_thread(0, BURST_LEN_SINGLE);
        decerr_id_thread(0, BURST_LEN_4BEATS);
        decerr_id_thread(0, BURST_LEN_8BEATS);
        decerr_id_thread(1, BURST_LEN_SINGLE);
        decerr_id_thread(1, BURST_LEN_4BEATS);
        decerr_id_thread(1, BURST_LEN_8BEATS);

        `uvm_info(get_type_name(), "========== decerr_id_test_start ==========", UVM_LOW)
    endtask

    virtual task decerr_id_thread(int unsigned mst_idx, burst_len_enum burst_len);
        do_decerr_write(
                        .mst_idx(mst_idx),
                        .addr(32'hDEAD_0000),
                        .burst_len(burst_len),
                        .burst_type(INCR),
                        .burst_size(BURST_SIZE_4BYTES),
                        .tr_id(8'h10)
        );
        do_decerr_read(
                        .mst_idx(mst_idx),
                        .addr(32'hBEEF_0000),
                        .burst_len(burst_len),
                        .burst_type(INCR),
                        .burst_size(BURST_SIZE_4BYTES),
                        .tr_id(8'h10)            
        );
        do_legal_write(
                        .mst_idx(mst_idx),
                        .addr(32'h0000_2000),        //slave00
                        .burst_len(burst_len),
                        .burst_type(INCR),
                        .burst_size(BURST_SIZE_4BYTES),
                        .tr_id(8'h10)                         
        );
        do_legal_read(
                        .mst_idx(mst_idx),
                        .addr(32'h0000_2000),        //slave00
                        .burst_len(burst_len),
                        .burst_type(INCR),
                        .burst_size(BURST_SIZE_4BYTES),
                        .tr_id(8'h10)                         
        );
        do_legal_write(
                        .mst_idx(mst_idx),
                        .addr(32'h0001_2000),        //slave01
                        .burst_len(burst_len),
                        .burst_type(INCR),
                        .burst_size(BURST_SIZE_4BYTES),
                        .tr_id(8'h10)                         
        );
        do_legal_read(
                        .mst_idx(mst_idx),
                        .addr(32'h0001_2000),        //slave01
                        .burst_len(burst_len),
                        .burst_type(INCR),
                        .burst_size(BURST_SIZE_4BYTES),
                        .tr_id(8'h10)                         
        );
    endtask

endclass

`endif 
