`ifndef AXICB_DECODE_FULL_RANGE_VSEQ_SV
`define AXICB_DECODE_FULL_RANGE_VSEQ_SV

class axicb_decode_full_range_vseq extends axicb_decode_base_vseq;
    `uvm_object_utils(axicb_decode_full_range_vseq)

    function new(string name = "axicb_decode_full_range_vseq");
        super.new(name);
    endfunction

    virtual task body();
        super.body();
        `uvm_info(get_type_name(), "========== decode_full_range_test_start ==========", UVM_LOW)

        //master_X_slave_X_write_X_read
        mx_s0_decode_test(0, WRITE);
        mx_s0_decode_test(0, READ);
        mx_s0_decode_test(1, WRITE);
        mx_s0_decode_test(1, READ);
        mx_s1_decode_test(0, WRITE);
        mx_s1_decode_test(0, READ);
        mx_s1_decode_test(1, WRITE);
        mx_s1_decode_test(1, READ);

        boundary_adjacency_decode(WRITE);
        boundary_adjacency_decode(READ);

        `uvm_info(get_type_name(), "========== decode_full_range_test_end ==========", UVM_LOW)
    endtask

    local task mx_s0_decode_test(int unsigned mst_idx, trans_type_enum trans_type);
        begin: base_addr_decode_test
            bit ups_error = 0, downs_error = 0;
            fork
                case(trans_type)
                    WRITE: do_legal_write(mst_idx, s0_base_addr, BURST_LEN_SINGLE, INCR, BURST_SIZE_4BYTES, 8'b1111_1111);
                    READ:  do_legal_read (mst_idx, s0_base_addr, BURST_LEN_SINGLE, INCR, BURST_SIZE_4BYTES, 8'b1111_1111);
                    default: `uvm_fatal(get_type_name(), "UNDEFINED trans_type!")
                endcase
                upstream_decode_checker(mst_idx, trans_type, 8'b1111_1111, ups_error);
                downstream_decode_checker(mst_idx, trans_type, s0_base_addr, 8'b1111_1111, downs_error);
            join
            if(ups_error || downs_error)
                `uvm_error(get_type_name(), "s0_base_addr: DECODE FAILED!")
            else
                `uvm_info(get_type_name(), "s0_base_addr: DECODE PASSED!", UVM_LOW)
        end
        begin: mid_addr_decode_test
            bit ups_error = 0, downs_error = 0;
            fork
                case(trans_type)
                    WRITE: do_legal_write(mst_idx, s0_mid_addr, BURST_LEN_SINGLE, INCR, BURST_SIZE_4BYTES, 8'b1010_1010);
                    READ:  do_legal_read (mst_idx, s0_mid_addr, BURST_LEN_SINGLE, INCR, BURST_SIZE_4BYTES, 8'b1010_1010);
                endcase
                upstream_decode_checker(mst_idx, trans_type, 8'b1010_1010, ups_error);
                downstream_decode_checker(mst_idx, trans_type, s0_mid_addr, 8'b1010_1010, downs_error);
            join
            if(ups_error || downs_error)
                `uvm_error(get_type_name(), "s0_mid_addr: DECODE FAILED!")
            else
                `uvm_info(get_type_name(), "s0_mid_addr: DECODE PASSED!", UVM_LOW)                
        end
        begin: end_addr_decode_test
            bit ups_error = 0, downs_error = 0;
            fork
                case(trans_type)
                    WRITE: do_legal_write(mst_idx, s0_end_addr, BURST_LEN_SINGLE, INCR, BURST_SIZE_4BYTES, 8'b0101_0101);
                    READ:  do_legal_read (mst_idx, s0_end_addr, BURST_LEN_SINGLE, INCR, BURST_SIZE_4BYTES, 8'b0101_0101);
                endcase
                upstream_decode_checker(mst_idx, trans_type, 8'b0101_0101, ups_error);
                downstream_decode_checker(mst_idx, trans_type, s0_end_addr, 8'b0101_0101, downs_error);
            join
            if(ups_error || downs_error)
                `uvm_error(get_type_name(), "s0_end_addr: DECODE FAILED!")
            else
                `uvm_info(get_type_name(), "s0_end_addr: DECODE PASSED!", UVM_LOW)              
        end      
        
    endtask

    local task mx_s1_decode_test(int unsigned mst_idx, trans_type_enum trans_type);
        begin: base_addr_decode_test
            bit ups_error = 0, downs_error = 0;
            fork
                case(trans_type)
                    WRITE: do_legal_write(mst_idx, s1_base_addr, BURST_LEN_SINGLE, INCR, BURST_SIZE_4BYTES, 8'b1111_1111);
                    READ:  do_legal_read (mst_idx, s1_base_addr, BURST_LEN_SINGLE, INCR, BURST_SIZE_4BYTES, 8'b1111_1111);
                    default: `uvm_fatal(get_type_name(), "UNDEFINED trans_type!")
                endcase
                upstream_decode_checker(mst_idx, trans_type, 8'b1111_1111, ups_error);
                downstream_decode_checker(mst_idx, trans_type, s1_base_addr, 8'b1111_1111, downs_error);
            join
            if(ups_error || downs_error)
                `uvm_error(get_type_name(), "s1_base_addr: DECODE FAILED!")
            else
                `uvm_info(get_type_name(), "s1_base_addr: DECODE PASSED!", UVM_LOW)
        end
        begin: mid_addr_decode_test
            bit ups_error = 0, downs_error = 0;
            fork
                case(trans_type)
                    WRITE: do_legal_write(mst_idx, s1_mid_addr, BURST_LEN_SINGLE, INCR, BURST_SIZE_4BYTES, 8'b1010_1010);
                    READ:  do_legal_read (mst_idx, s1_mid_addr, BURST_LEN_SINGLE, INCR, BURST_SIZE_4BYTES, 8'b1010_1010);
                endcase
                upstream_decode_checker(mst_idx, trans_type, 8'b1010_1010, ups_error);
                downstream_decode_checker(mst_idx, trans_type, s1_mid_addr, 8'b1010_1010, downs_error);
            join
            if(ups_error || downs_error)
                `uvm_error(get_type_name(), "s1_mid_addr: DECODE FAILED!")
            else
                `uvm_info(get_type_name(), "s1_mid_addr: DECODE PASSED!", UVM_LOW)                
        end
        begin: end_addr_decode_test
            bit ups_error = 0, downs_error = 0;
            fork
                case(trans_type)
                    WRITE: do_legal_write(mst_idx, s1_end_addr, BURST_LEN_SINGLE, INCR, BURST_SIZE_4BYTES, 8'b0101_0101);
                    READ:  do_legal_read (mst_idx, s1_end_addr, BURST_LEN_SINGLE, INCR, BURST_SIZE_4BYTES, 8'b0101_0101);
                endcase
                upstream_decode_checker(mst_idx, trans_type, 8'b0101_0101, ups_error);
                downstream_decode_checker(mst_idx, trans_type, s1_end_addr, 8'b0101_0101, downs_error);
            join
            if(ups_error || downs_error)
                `uvm_error(get_type_name(), "s1_end_addr: DECODE FAILED!")
            else
                `uvm_info(get_type_name(), "s1_end_addr: DECODE PASSED!", UVM_LOW)              
        end      
        
    endtask

    local task boundary_adjacency_decode(trans_type_enum trans_type);
        if(trans_type == WRITE) begin
            begin: s0_end_write_txn
                bit ups_error = 0, downs_error = 0;
                fork
                    do_legal_write(0, s0_end_addr, BURST_LEN_SINGLE, INCR, BURST_SIZE_4BYTES, 8'b1100_1100);
                    upstream_decode_checker(0, trans_type, 8'b1100_1100, ups_error);
                    downstream_decode_checker(0, trans_type, s0_end_addr, 8'b1100_1100, downs_error);
                join
                if(ups_error || downs_error)
                    `uvm_error(get_type_name(), "boundary adjacency decode(WRITE): s0_end_addr DECODE FAILED!")
                else
                    `uvm_info(get_type_name(), "boundary adjacency decode(WRITE): s0_end_addr DECODE PASSED!", UVM_LOW)                    
            end
            begin: s1_base_write_txn
                bit ups_error = 0, downs_error = 0;
                fork
                    do_legal_write(0, s1_base_addr, BURST_LEN_SINGLE, INCR, BURST_SIZE_4BYTES, 8'b1100_1100);
                    upstream_decode_checker(0, trans_type, 8'b1100_1100, ups_error);
                    downstream_decode_checker(0, trans_type, s1_base_addr, 8'b1100_1100, downs_error);
                join
                if(ups_error || downs_error)
                    `uvm_error(get_type_name(), "boundary adjacency decode(WRITE): s1_base_addr DECODE FAILED!")
                else
                    `uvm_info(get_type_name(), "boundary adjacency decode(WRITE): s1_base_addr DECODE PASSED!", UVM_LOW)  
            end
        end
        else begin  //READ
            begin: s0_end_read_txn
                bit ups_error = 0, downs_error = 0;
                fork
                    do_legal_read(0, s0_end_addr, BURST_LEN_SINGLE, INCR, BURST_SIZE_4BYTES, 8'b0011_0011);
                    upstream_decode_checker(0, trans_type, 8'b0011_0011, ups_error);
                    downstream_decode_checker(0, trans_type, s0_end_addr, 8'b0011_0011, downs_error);
                join
                if(ups_error || downs_error)
                    `uvm_error(get_type_name(), "boundary adjacency decode(READ): s0_end_addr DECODE FAILED!")
                else
                    `uvm_info(get_type_name(), "boundary adjacency decode(READ): s0_end_addr DECODE PASSED!", UVM_LOW)                    
            end
            begin: s1_base_read_txn
                bit ups_error = 0, downs_error = 0;
                fork
                    do_legal_read(0, s1_base_addr, BURST_LEN_SINGLE, INCR, BURST_SIZE_4BYTES, 8'b0011_0011);
                    upstream_decode_checker(0, trans_type, 8'b0011_0011, ups_error);
                    downstream_decode_checker(0, trans_type, s1_base_addr, 8'b0011_0011, downs_error);
                join
                if(ups_error || downs_error)
                    `uvm_error(get_type_name(), "boundary adjacency decode(READ): s1_base_addr DECODE FAILED!")
                else
                    `uvm_info(get_type_name(), "boundary adjacency decode(READ): s1_base_addr DECODE PASSED!", UVM_LOW)  
            end
        end
    endtask

endclass

`endif 
