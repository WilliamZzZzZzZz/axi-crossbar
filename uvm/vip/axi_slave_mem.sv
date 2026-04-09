`ifndef AXI_SLAVE_MEM_SV
`define AXI_SLAVE_MEM_SV

class axi_slave_mem #(
    parameter int ADDR_WIDTH = 32;
    parameter int DATA_WIDTH = 32;
    parameter int STRB_WIDTH = (DATA_WIDTH/8)
) extends uvm_object;

    `uvm_object_utils(axi_slave_mem#(ADDR_WIDTH, DATA_WIDTH, STRB_WIDTH))

    axi_configuration cfg;
    bit [DATA_WIDTH - 1:0] default_word_value;
    bit [DATA_WIDTH - 1:0] data [bit [ADDR_WIDTH - 1:0]];

    function new(string name = "axi_slave_mem");
        super.new(name);
    endfunction

    function bit [DATA_WIDTH -1:0] read_word(bit [ADDR_WIDTH - 1:0] word_addr);
        return data.exists(word_addr) ? data[word_addr] : default_word_value;
    endfunction

    function void write_word_with_strb(
        bit [ADDR_WIDTH - 1:0] word_addr;
        bit [DATA_WIDTH - 1:0] new_data;
        bit [STRB_WIDTH - 1:0] wstrb;
    );
        bit [DATA_WIDTH - 1:0] old_data;
        bit [DATA_WIDTH - 1:0] updated_word;

        old_data = data.exists(word_addr) ? data[word_addr] : default_word_value;
        updated_word = old_data;

        for (int lane = 0; lane < STRB_WIDTH; lane++) begin
            if(wstrb[lane])
                updated_word[lane*8 +: 8] = new_data[lane*8 +: 8];
        end

        data[word_addr] = updated_word;
    endfunction

    static function bit [ADDR_WIDTH - 1:0] calc_beat_addr(
        bit [ADDR_WIDTH - 1:0] base_addr,
        bit [1:0]              burst_type,
        bit [2:0]              burst_size,
        int                    beat_idx,
        int                    burst_len
    );
        int unsigned           stride;
        int unsigned           total_bytes;
        bit [ADDR_WIDTH - 1:0] aligned_start;
        bit [ADDR_WIDTH - 1:0] addr;

        stride = 1 << int'(burst_size);
        aligned_start = (base_addr / stride) * stride;

        case (burst_type)
            2'b00: begin    //FIXED
                addr = base_addr;
            end
            2'b01: begin    //INCR
                if(beat_idx == 0)
                    addr = base_addr;
                else
                    addr = aligned_addr + (beat_idx * stride);
            end
            //TODO:WRAP
            default: begin
                `uvm_error(get_type_name(), "the burst_type is illegal")
            end
        endcase
        return addr;
    endfunction

    function void clear();
        data.delete();
    endfunction

endclass

`endif 