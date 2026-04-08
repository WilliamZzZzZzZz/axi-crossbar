`ifndef AXI_SLAVE_DRIVER_SV
`define AXI_SLAVE_DRIVER_SV

class axi_slave_driver extends uvm_component;
    `uvm_component_utils(axi_slave_driver)

    virtual axi_if vif;
    axi_configuration cfg;

    typedef struct {
        bit [31:0] id;
        bit [31:0] addr;
        bit [7:0]  len;
        bit [2:0]  size;
        bit [1:0]  burst;
        int        beat_idx;
    } write_cmd_t;

    typedef struct {
        bit [31:0] id;
        bit [31:0] addr;
        bit [7:0]  len;
        bit [2:0]  size;
        bit [1:0]  burst;
        int        beat_idx;
    } read_cmd_t;

    typedef struct {
        bit [31:0] id;
        bit [1:0]  resp;
    } b_rsp_t;

    write_cmd_t wr_cmd_q[$];
    read_cmd_t  rd_cmd_q[$];
    b_rsp_t     b_rsp_q[$];

    bit [31:0] mem[bit [31:0]];

    function new(string name = "axi_slave_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        reset_outputs();

        forever begin
            @(posedge vif.aclk);

            if (vif.arst) begin
                wr_cmd_q.delete();
                rd_cmd_q.delete();
                b_rsp_q.delete();
                mem.delete();
                reset_outputs();
                continue;
            end

            // Keep channels ready in phase-1 baseline model.
            vif.slave_cb.awready <= 1'b1;
            vif.slave_cb.wready  <= 1'b1;
            vif.slave_cb.arready <= 1'b1;

            // AW capture
            if (vif.slave_cb.awvalid && vif.slave_cb.awready) begin
                write_cmd_t cmd;
                cmd.id       = vif.slave_cb.awid;
                cmd.addr     = vif.slave_cb.awaddr;
                cmd.len      = vif.slave_cb.awlen;
                cmd.size     = vif.slave_cb.awsize;
                cmd.burst    = vif.slave_cb.awburst;
                cmd.beat_idx = 0;
                wr_cmd_q.push_back(cmd);
            end

            // W capture and memory update
            if (vif.slave_cb.wvalid && vif.slave_cb.wready) begin
                if (wr_cmd_q.size() == 0) begin
                    `uvm_error(get_type_name(), "W beat observed without pending AW")
                end else begin
                    write_cmd_t cmd;
                    b_rsp_t rsp;
                    bit [31:0] beat_addr;

                    cmd = wr_cmd_q[0];
                    beat_addr = calculate_beat_addr(cmd.addr, cmd.burst, cmd.size, cmd.beat_idx);
                    apply_write_beat(beat_addr, vif.slave_cb.wdata, vif.slave_cb.wstrb);

                    cmd.beat_idx++;
                    wr_cmd_q[0] = cmd;

                    if (vif.slave_cb.wlast || cmd.beat_idx > cmd.len) begin
                        rsp.id = cmd.id;
                        rsp.resp = OKAY;
                        b_rsp_q.push_back(rsp);
                        wr_cmd_q.pop_front();
                    end
                end
            end

            // B generation
            if (vif.slave_cb.bvalid && vif.slave_cb.bready) begin
                vif.slave_cb.bvalid <= 1'b0;
            end
            if (!vif.slave_cb.bvalid && b_rsp_q.size() > 0) begin
                b_rsp_t rsp;
                rsp = b_rsp_q.pop_front();
                vif.slave_cb.bid   <= rsp.id;
                vif.slave_cb.bresp <= rsp.resp;
                vif.slave_cb.buser <= '0;
                vif.slave_cb.bvalid <= 1'b1;
            end

            // AR capture
            if (vif.slave_cb.arvalid && vif.slave_cb.arready) begin
                read_cmd_t cmd;
                cmd.id       = vif.slave_cb.arid;
                cmd.addr     = vif.slave_cb.araddr;
                cmd.len      = vif.slave_cb.arlen;
                cmd.size     = vif.slave_cb.arsize;
                cmd.burst    = vif.slave_cb.arburst;
                cmd.beat_idx = 0;
                rd_cmd_q.push_back(cmd);
            end

            // R generation
            if (vif.slave_cb.rvalid && vif.slave_cb.rready) begin
                if (rd_cmd_q.size() > 0) begin
                    read_cmd_t cmd;
                    cmd = rd_cmd_q[0];
                    cmd.beat_idx++;

                    if (cmd.beat_idx > cmd.len) begin
                        rd_cmd_q.pop_front();
                        vif.slave_cb.rvalid <= 1'b0;
                        vif.slave_cb.rlast  <= 1'b0;
                    end else begin
                        rd_cmd_q[0] = cmd;
                        drive_r_from_cmd(cmd);
                    end
                end else begin
                    vif.slave_cb.rvalid <= 1'b0;
                    vif.slave_cb.rlast  <= 1'b0;
                end
            end else if (!vif.slave_cb.rvalid && rd_cmd_q.size() > 0) begin
                drive_r_from_cmd(rd_cmd_q[0]);
            end
        end
    endtask

    local task reset_outputs();
        vif.slave_cb.awready <= 1'b0;
        vif.slave_cb.wready  <= 1'b0;
        vif.slave_cb.arready <= 1'b0;

        vif.slave_cb.bid     <= '0;
        vif.slave_cb.bresp   <= '0;
        vif.slave_cb.buser   <= '0;
        vif.slave_cb.bvalid  <= 1'b0;

        vif.slave_cb.rid     <= '0;
        vif.slave_cb.rdata   <= '0;
        vif.slave_cb.rresp   <= '0;
        vif.slave_cb.rlast   <= 1'b0;
        vif.slave_cb.ruser   <= '0;
        vif.slave_cb.rvalid  <= 1'b0;
    endtask

    local task drive_r_from_cmd(read_cmd_t cmd);
        bit [31:0] beat_addr;
        bit [31:0] word_addr;

        beat_addr = calculate_beat_addr(cmd.addr, cmd.burst, cmd.size, cmd.beat_idx);
        word_addr = {beat_addr[31:2], 2'b00};

        vif.slave_cb.rid    <= cmd.id;
        vif.slave_cb.rdata  <= mem.exists(word_addr) ? mem[word_addr] : 32'h0;
        vif.slave_cb.rresp  <= OKAY;
        vif.slave_cb.rlast  <= (cmd.beat_idx == cmd.len);
        vif.slave_cb.ruser  <= '0;
        vif.slave_cb.rvalid <= 1'b1;
    endtask

    local function bit [31:0] calculate_beat_addr(
        bit [31:0]      base_addr,
        bit [1:0]       burst_type,
        bit [2:0]       burst_size,
        int             beat_idx
    );
        int unsigned stride;
        bit [31:0] aligned_start;
        bit [31:0] beat_addr;

        stride = 1 << burst_size;
        aligned_start = (base_addr >> burst_size) << burst_size;

        case (burst_type)
            FIXED: beat_addr = base_addr;
            default: begin
                if (beat_idx == 0)
                    beat_addr = base_addr;
                else
                    beat_addr = aligned_start + beat_idx * stride;
            end
        endcase

        return beat_addr;
    endfunction

    local function void apply_write_beat(
        bit [31:0] beat_addr,
        bit [31:0] wdata,
        bit [31:0] wstrb
    );
        bit [31:0] word_addr;
        bit [31:0] old_word;
        bit [31:0] new_word;

        word_addr = {beat_addr[31:2], 2'b00};
        old_word = mem.exists(word_addr) ? mem[word_addr] : 32'h0;
        new_word = old_word;

        for (int lane = 0; lane < 4; lane++) begin
            if (wstrb[lane]) begin
                new_word[lane*8 +: 8] = wdata[lane*8 +: 8];
            end
        end

        mem[word_addr] = new_word;
    endfunction

endclass

`endif
