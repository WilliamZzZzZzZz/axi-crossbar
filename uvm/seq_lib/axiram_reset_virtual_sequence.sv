`ifndef AXIRAM_RESET_VIRTUAL_SEQUENCE_SV
`define AXIRAM_RESET_VIRTUAL_SEQUENCE_SV

class axiram_reset_virtual_sequence extends axiram_base_virtual_sequence;
    `uvm_object_utils(axiram_reset_virtual_sequence)

    function new(string name = "axiram_reset_virtual_sequence");
        super.new(name);
    endfunction

    virtual task body();
        super.body();
        write_mid_reset_test();
        read_mid_reset_test();
    endtask

    virtual task write_mid_reset_test();
        bit [31:0] every_beat_data[];
        every_beat_data = new[8];
        foreach (every_beat_data[i]) every_beat_data[i] = 32'hf0f0_0000 + i;
        
        `uvm_info(get_type_name(), "--- write_mid_reset_test START ---", UVM_LOW)
        fork
            begin:WRITE_ACTION
                single_write = axiram_single_write_sequence::type_id::create("single_write");
                single_write.addr               = 16'h0300;
                single_write.data               = every_beat_data[0];
                single_write.every_beat_data    = every_beat_data;
                single_write.burst_len          = BURST_LEN_8BEATS;
                single_write.burst_size         = BURST_SIZE_4BYTES;
                single_write.burst_type         = INCR;
                single_write.start(p_sequencer);
            end
            begin:RESET_CONTROL
                //wait AW handshake
                @(posedge vif.aclk iff(vif.awvalid && vif.awready));
                //let W 3 beats transfer complete
                repeat(3) @(posedge vif.aclk iff(vif.wvalid && vif.wready));
                //force reset
                vif.assert_reset();
                //wait 2 posedge for DUT registers to update(doubt!)
                repeat(2) @(posedge vif.aclk);
                //check DUT signals
                check_write_reset_signals();
                //hold reset for some cycles, then release
                repeat(3) @(posedge vif.aclk);
                vif.deassert_reset();
                wait_cycles(5);
            end
        join_any
        disable fork;

        begin:POST_MID_RESET_TEST
            do_single_read(16'h0300);
            `uvm_info(get_type_name(), "--- post_mid_reset_write_test DONE ---", UVM_LOW)
        end
        `uvm_info(get_type_name(), "--- write_mid_reset_test END ---", UVM_LOW)

    endtask

    virtual task read_mid_reset_test();
        `uvm_info(get_type_name(), "--- read_mid_reset_test START ---", UVM_LOW)
        fork
            begin:READ_ACTION
                single_read = axiram_single_read_sequence::type_id::create("single_read");
                single_read.addr        = 16'h0300;
                single_read.burst_len   = BURST_LEN_8BEATS;
                single_read.burst_size  = BURST_SIZE_4BYTES;
                single_read.burst_type  = INCR;
                single_read.start(p_sequencer);
            end
            begin:RESET_CONTROL
                //wait AR handshake
                @(posedge vif.aclk iff(vif.arvalid && vif.arready));
                //let R 3 transfer complete
                repeat(3) @(posedge vif.aclk iff(vif.rvalid && vif.rready));
                //force reset
                vif.assert_reset();
                //wait 2 cycles
                repeat(2) @(posedge vif.aclk);
                //check DUT signals
                check_read_reset_signals();
                //hold reset for some cycles, then release
                repeat(3) @(posedge vif.aclk);
                vif.deassert_reset();
                wait_cycles(5);
            end
        join_any
        disable fork;

        begin:POST_MID_RESET_TEST
            do_single_write(16'h0400, 32'hABCD_ABCD);
            do_single_read(16'h0400);
            `uvm_info(get_type_name(), "--- post_mid_reset_read_test DONE ---", UVM_LOW)
        end
        `uvm_info(get_type_name(), "--- read_mid_reset_test END ---", UVM_LOW)
    endtask

    //DUT as a slave, only check DUT's output signals
    local task check_write_reset_signals();
        if(vif.awready !== 1'b0)
            `uvm_error(get_type_name(), $sformatf("RESET FAIL: awready=%b, exp=0", vif.awready))
        if(vif.wready !== 1'b0)
            `uvm_error(get_type_name(), $sformatf("RESET FAIL: wready=%b, exp=0", vif.wready))
        if(vif.bvalid !== 1'b0)
            `uvm_error(get_type_name(), $sformatf("RESET FAIL: bvalid=%b, exp=0", vif.bvalid))
        `uvm_info(get_type_name(), "Write reset signals checked OK", UVM_MEDIUM)
    endtask

    //DUT as a slave, only check DUT's output signals
    local task check_read_reset_signals();
        if(vif.arready !== 1'b0)
            `uvm_error(get_type_name(), $sformatf("RESET FAIL: arready=%b, exp=0", vif.arready))
        if(vif.rvalid !== 1'b0)
            `uvm_error(get_type_name(), $sformatf("RESET FAIL: rvalid=%b, exp=0", vif.rvalid))
        `uvm_info(get_type_name(), "Read reset signals checked OK", UVM_MEDIUM)
    endtask

    local task do_single_write(bit [15:0] addr, bit [31:0] data);
        bit [31:0] wdata_arr[] = '{data};
        single_write = axiram_single_write_sequence::type_id::create("single_write");
        single_write.addr = addr;
        single_write.data = data;
        single_write.every_beat_data = wdata_arr;
        single_write.burst_len = BURST_LEN_SINGLE;
        single_write.burst_size = BURST_SIZE_4BYTES;
        single_write.burst_type = INCR;
        single_write.start(p_sequencer);
    endtask

    local task do_single_read(bit [15:0] addr);
        single_read = axiram_single_read_sequence::type_id::create("single_read");
        single_read.addr = addr;
        single_read.burst_len = BURST_LEN_SINGLE;
        single_read.burst_size = BURST_SIZE_4BYTES;
        single_read.burst_type = INCR;
        single_read.start(p_sequencer);
    endtask


endclass

`endif 