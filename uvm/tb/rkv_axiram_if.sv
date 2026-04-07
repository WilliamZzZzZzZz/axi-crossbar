`ifndef RKV_AXIRAM_IF_SV
`define RKV_AXIRAM_IF_SV

interface rkv_axiram_if;
  logic clk;
  logic rst;
  
  // Clock generation (for TB control)
  initial begin
    clk = 0;
    forever #5ns clk = ~clk; // 100MHz clock
  end
  
  // Reset generation task
  task automatic do_reset(int cycles = 10);
    rst = 1'b1;
    repeat(cycles) @(posedge clk);
    rst = 1'b0;
  endtask

endinterface

`endif // RKV_AXIRAM_IF_SV
