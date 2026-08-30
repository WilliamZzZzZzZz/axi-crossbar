`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * QoS-aware blocking round-robin arbiter
 */
module qos_arbiter #
(
    parameter PORTS = 4,
    parameter QOS_WIDTH = 4
)
(
    input  wire                         clk,
    input  wire                         rst,

    input  wire [PORTS-1:0]             request,
    input  wire [PORTS*QOS_WIDTH-1:0]   request_qos,
    input  wire [PORTS-1:0]             acknowledge,

    output wire [PORTS-1:0]             grant,
    output wire                         grant_valid,
    output wire [$clog2(PORTS)-1:0]     grant_encoded
);

reg [QOS_WIDTH-1:0] max_qos;
reg [PORTS-1:0] qos_request;
integer i;

always @* begin
    max_qos = {QOS_WIDTH{1'b0}};
    qos_request = {PORTS{1'b0}};

    for (i = 0; i < PORTS; i = i + 1) begin
        if (request[i] && request_qos[i*QOS_WIDTH +: QOS_WIDTH] > max_qos) begin
            max_qos = request_qos[i*QOS_WIDTH +: QOS_WIDTH];
        end
    end

    for (i = 0; i < PORTS; i = i + 1) begin
        if (request[i] && request_qos[i*QOS_WIDTH +: QOS_WIDTH] == max_qos) begin
            qos_request[i] = 1'b1;
        end
    end
end

arbiter #(
    .PORTS(PORTS),
    .ARB_TYPE_ROUND_ROBIN(1),
    .ARB_BLOCK(1),
    .ARB_BLOCK_ACK(1),
    .ARB_LSB_HIGH_PRIORITY(1)
)
arbiter_inst (
    .clk(clk),
    .rst(rst),
    .request(qos_request),
    .acknowledge(acknowledge),
    .grant(grant),
    .grant_valid(grant_valid),
    .grant_encoded(grant_encoded)
);

`ifndef SYNTHESIS
assert property (@(posedge clk) disable iff (rst) $onehot0(grant))
    else $error("QoS arbiter grant must be one-hot or zero");

assert property (@(posedge clk) disable iff (rst)
    grant_valid && !(grant & acknowledge) |=>
        grant_valid && $stable(grant) && $stable(grant_encoded))
    else $error("QoS arbiter grant changed before acknowledge");
`endif

endmodule

`resetall
