`ifndef AXICB_SMOKE_VIRTUAL_SEQUENCE_SV
`define AXICB_SMOKE_VIRTUAL_SEQUENCE_SV

class axicb_smoke_virtual_sequence extends axicb_base_virtual_sequence;

    `uvm_object_utils(axicb_smoke_virtual_sequence)

    function new(string name = "axicb_smoke_virtual_sequence");
        super.new(name);
    endfunction

    virtual task body();
        super.body();
        `uvm_info(get_type_name(), "========== smoke_test_start ==========", UVM_LOW)
        write_and_read_test(0, 0);
        write_and_read_test(0, 1);
        // write_and_read_test(1, 0);
        // write_and_read_test(1, 1);
        `uvm_info(get_type_name(), "========== smoke_test_end ============", UVM_LOW)
    endtask

    virtual task write_and_read_test(int unsigned mst_idx, int unsigned slv_idx);
        bit [31:0] addr, base_addr;
        bit [31:0] wr_data;
        bit [31:0] wr_data_arr[];
        bit [3:0]  wr_strb_arr[];
        bit [31:0] addr_offset = 0, data_offset = 0;
        
        case(slv_idx)
            0: begin
                base_addr = 32'h0000_0000;
            end
            1: begin
                base_addr = 32'h0001_0000;
            end
            default: `uvm_fatal(get_type_name(), "undefined index of slave")
        endcase

        if(vif_mst00.arst === 1'b1) @(negedge vif_mst00.arst);
        wait_cycles(5);

        addr            = 32'h0000_0040;
        wr_data         = 32'hA7A7_A7A7;
        wr_data_arr     = new[1];
        wr_strb_arr     = new[1];
        wr_data_arr[0]  = wr_data;
        wr_strb_arr[0]  = 4'hF;

        single_write = axicb_single_write_sequence::type_id::create("single_write");
        single_write.src_master_idx     = mst_idx;
        single_write.addr               = base_addr;
        single_write.data               = wr_data;
        single_write.burst_len          = BURST_LEN_SINGLE;
        single_write.burst_type         = INCR;
        single_write.burst_size         = BURST_SIZE_4BYTES;
        single_write.every_beat_data    = wr_data_arr;
        single_write.every_beat_wstrb   = wr_strb_arr;
        single_write.wait_for_response  = 1;
        single_write.start(p_sequencer);

        single_read = axicb_single_read_sequence::type_id::create("single_read");
        single_read.src_master_idx      = mst_idx;
        single_read.addr                = base_addr;
        single_read.burst_len           = BURST_LEN_SINGLE;
        single_read.burst_type          = INCR;
        single_read.burst_size          = BURST_SIZE_4BYTES;
        single_read.wait_for_response   = 1;
        single_read.start(p_sequencer);

        if(compare_single_data(wr_data, single_read.data)) begin
            `uvm_info(get_type_name(), $sformatf("master %0d to slave %0d write and read PASSED!", mst_idx, slv_idx), UVM_MEDIUM)
        end else begin
            `uvm_error(get_type_name(), $sformatf("master %0d to slave %0d write and read FAILED!", mst_idx, slv_idx))
        end

    endtask

endclass

`endif 