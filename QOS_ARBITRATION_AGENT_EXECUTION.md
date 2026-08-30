# AXI Crossbar QoS 仲裁 Agent 执行文档

## 1. 任务目标

在当前 AXI Crossbar RTL 中新增**可参数化开启的 AW/AR QoS-aware arbitration**，同时对现有 UVM 环境做最小适配和定向验证。

最终行为必须满足：

1. `QOS_ARB_ENABLE=0`：保持当前 blocking Round-Robin 行为，现有 9 个 testcase 不受影响。
2. `QOS_ARB_ENABLE=1`：同一目标端口上的有效 AW/AR 请求先比较 QoS，数值最大的请求优先。
3. 最高 QoS 相同：继续使用当前 Round-Robin 选择。
4. 已发出的 grant 保持到 `acknowledge`，后来到达的更高 QoS 请求不得抢占。
5. AW 和 AR 独立仲裁，互不影响。
6. W 不做 QoS 仲裁，继续跟随 AW 选择并保持到 `WLAST`。
7. B/R response arbitration 保持当前 Round-Robin，不引入 QoS。
8. 现有地址译码、ID 扩展、outstanding、same-ID ordering、DECERR 和 register slice 行为不得改变。

本文是 coding agent 的执行规范。除非源代码事实证明本文存在错误，否则不得自行扩展功能或重写架构。

## 2. 当前源码事实

执行前必须重新读取并确认以下文件，不得只依据本文修改：

- `dut/arbiter.v`
- `dut/axi_crossbar_wr.v`
- `dut/axi_crossbar_rd.v`
- `dut/axi_crossbar.v`
- `dut/axi_crossbar_wrap_2x2.v`
- `uvm/testbench/axi_crossbar_tb.sv`
- `uvm/vip/seq_lib/axi_master_single_sequence.sv`
- `uvm/seq_lib/element_seq/axicb_single_write_sequence.sv`
- `uvm/seq_lib/element_seq/axicb_single_read_sequence.sv`
- `uvm/seq_lib/axicb_conc_base_vseq.sv`
- `uvm/seq_lib/axicb_conc_arb_vseq.sv`
- `uvm/vip/axi_if.sv`
- `uvm/env/axicb_predictor.sv`
- `uvm/env/axicb_scoreboard.sv`
- `uvm/env/axicb_coverage.sv`
- `uvm/sim/Makefile`

当前已确认的事实：

- `AWQOS`、`ARQOS` 均为 4 bit，并已从上游接口透传到下游接口。
- `axi_crossbar_addr.s_axi_aqos` 当前不参与译码或 admission control。
- 每个下游端口分别有一个 AW address arbiter 和一个 AR address arbiter。
- 当前 AW/AR arbiter 参数为：

```verilog
.ARB_TYPE_ROUND_ROBIN(1)
.ARB_BLOCK(1)
.ARB_BLOCK_ACK(1)
.ARB_LSB_HIGH_PRIORITY(1)
```

- B/R response arbiter 同样使用 Round-Robin，但 AXI B/R 通道没有 QoS 字段。
- 当前 W source 由 AW grant 决定，并保持到 `WLAST`。
- `axi_master_single_sequence.tr_qos` 已存在，默认值为 0。
- 上层 `axicb_single_write_sequence` 和 `axicb_single_read_sequence` 尚未暴露或传递 QoS。
- monitor event、predictor expected event 和 scoreboard 已携带并比较 QoS；不需要为本任务重写 predictor/scoreboard。
- 当前 `conc_arb` 的 Round-Robin fairness 检查只适用于所有竞争请求 QoS 相同的情况。

## 3. 明确的功能规格

### 3.1 QoS 数值语义

本项目规定：

```text
QoS 数值越大，优先级越高。
4'hF 为最高优先级。
4'h0 为最低/默认优先级。
```

这是本项目的实现策略，不应描述为 AXI 协议强制规定的唯一策略。

### 3.2 两级选择策略

每次出现新的可仲裁窗口时：

```text
原始 request
    → 找出所有有效 request 中的 max_qos
    → eligible_request[m] = request[m] && qos[m] == max_qos
    → 现有 blocking Round-Robin arbiter
    → grant
```

选择规则：

1. 只有当前 `request[m] == 1` 的端口参与 QoS 比较。
2. 不允许无效 request 的 QoS 影响 `max_qos`。
3. 若所有有效 request 的 QoS 都为 0，则 `eligible_request == request`。
4. 若只有一个有效 request，则该请求正常获得 grant。
5. 若多个请求具有相同最大 QoS，则由现有 Round-Robin arbiter打破平局。

### 3.3 非抢占规则

当 arbiter 已经产生 grant 且尚未收到对应 `acknowledge` 时：

- 必须保持 `grant`、`grant_valid` 和 `grant_encoded`。
- 新到达的高 QoS 请求不得改变当前 grant。
- QoS 只在当前 grant 完成后参与下一次选择。

不得实现 preemptive arbitration。

### 3.4 公平性边界

第一版采用：

```text
严格最高 QoS 优先 + 同 QoS Round-Robin
```

第一版**不实现**：

- aging；
- weighted Round-Robin；
- token/credit-based priority；
- bounded starvation protection；
- 动态 QoS remap；
- B/R response QoS。

因此，持续不断的高 QoS 流量可能使低 QoS 请求长期等待。该边界必须写入注释、README 和验证结论，不得暗示已提供跨 QoS 防饥饿保证。

## 4. RTL 实施方案

### 4.1 新增 `dut/qos_arbiter.v`

新增一个参数化 wrapper，职责只有：

1. 根据 QoS 产生 `eligible_request`；
2. 复用现有 `arbiter` 完成 blocking、acknowledge 和 Round-Robin。

推荐接口：

```verilog
module qos_arbiter #(
    parameter PORTS = 4,
    parameter QOS_WIDTH = 4
) (
    input  wire                         clk,
    input  wire                         rst,
    input  wire [PORTS-1:0]             request,
    input  wire [PORTS*QOS_WIDTH-1:0]   request_qos,
    input  wire [PORTS-1:0]             acknowledge,
    output wire [PORTS-1:0]             grant,
    output wire                         grant_valid,
    output wire [$clog2(PORTS)-1:0]     grant_encoded
);
```

`qos_arbiter` 只实现启用后的 QoS 过滤，不包含 enable/bypass 分支。`QOS_ARB_ENABLE=0` 的兼容路径在 `axi_crossbar_wr/rd` 外层 generate 中直接实例化原始 `arbiter`。

后级必须实例化当前 `arbiter`：

```verilog
arbiter #(
    .PORTS(PORTS),
    .ARB_TYPE_ROUND_ROBIN(1),
    .ARB_BLOCK(1),
    .ARB_BLOCK_ACK(1),
    .ARB_LSB_HIGH_PRIORITY(1)
) arbiter_inst (...);
```

不得向 `qos_arbiter` 公开固定优先级、non-blocking 或其他当前 Crossbar 不需要的仲裁配置；不得复制 `arbiter.v` 中的 grant/mask 状态机。

### 4.2 QoS 过滤组合逻辑要求

组合逻辑必须有完整默认赋值，避免 latch：

```verilog
max_qos = {QOS_WIDTH{1'b0}};
qos_request = {PORTS{1'b0}};
```

第一遍循环只计算有效请求中的最大 QoS；第二遍循环生成同最大 QoS 的请求集合。

必须支持参数化 `PORTS`，不得写死 master0/master1 或 2-bit request。

切片必须采用：

```verilog
request_qos[i*QOS_WIDTH +: QOS_WIDTH]
```

不得误用 `M_COUNT` 或 `M_COUNT_P1` 作为 source request 数量；AW/AR QoS 仲裁输入数量是 `S_COUNT`。

### 4.3 参数传播

统一增加：

```verilog
parameter QOS_ARB_ENABLE = 0
```

参数必须沿以下路径完整传递：

```text
axi_crossbar_wrap_2x2
    → axi_crossbar
        → axi_crossbar_wr
        → axi_crossbar_rd
```

每一级默认值都必须为 0，且实例化时显式传递。`axi_crossbar_wr/rd` 使用该参数选择原始 `arbiter` 或 `qos_arbiter`；参数不传入 `axi_crossbar_addr`，也不传入 `qos_arbiter`。

### 4.4 修改 `dut/axi_crossbar_wr.v`

只修改每个 `m_ifaces[n]` 内的 AW address arbitration。

新增：

```verilog
wire [S_COUNT*4-1:0] a_request_qos;
```

对每个 source `m`：

```verilog
assign a_request_qos[m*4 +: 4] = int_s_axi_awqos[m*4 +: 4];
```

使用 generate 创建互斥分支：

```verilog
if (QOS_ARB_ENABLE) begin : g_aw_qos_arb
    qos_arbiter ...
end else begin : g_aw_rr_arb
    arbiter ... // 原 a_arb_inst 的参数和端口保持不变
end
```

QoS 分支连接：

- 原 `a_request`；
- `a_request_qos`；
- 原 `a_acknowledge`；
- 原 `a_grant`、`a_grant_valid`、`a_grant_encoded`。

关闭分支必须保留当前原始 `arbiter` 参数和输入，不得经过 QoS过滤器。这是 `QOS_ARB_ENABLE=0` 向后兼容的核心。

以下逻辑不得修改：

- `a_request[m]` 的 eligibility 条件；
- `trans_limit`；
- AW mux；
- `s_axi_awqos_mux`；
- `w_select_reg/w_select_valid_reg`；
- W mux 和 WLAST 释放逻辑；
- B response arbiter；
- DECERR write path；
- ID 扩展和返回逻辑。

### 4.5 修改 `dut/axi_crossbar_rd.v`

只修改每个 `m_ifaces[n]` 内的 AR address arbitration。

新增：

```verilog
wire [S_COUNT*4-1:0] a_request_qos;
```

对每个 source `m`：

```verilog
assign a_request_qos[m*4 +: 4] = int_s_axi_arqos[m*4 +: 4];
```

使用与 AW 对称的 generate：开启分支实例化 `qos_arbiter`，关闭分支直接保留当前原始 `arbiter`。

以下逻辑不得修改：

- `a_request[m]` 的 eligibility 条件；
- `trans_limit`；
- AR mux；
- `s_axi_arqos_mux`；
- R response forwarding；
- R response arbiter；
- RLAST completion；
- DECERR read path；
- ID 扩展和返回逻辑。

### 4.6 Testbench 与 Makefile 参数控制

将 testbench top 改为可参数化：

```systemverilog
module axi_crossbar_tb #(
    parameter bit QOS_ARB_ENABLE = 0
);
```

在 DUT 实例显式传递该参数。

在 `uvm/sim/Makefile` 增加：

```makefile
QOS_ARB_ENABLE ?= 0
```

在 elaboration 参数中加入：

```makefile
-pvalue+$(TB).QOS_ARB_ENABLE=$(QOS_ARB_ENABLE)
```

`make help` 的 Common variables 必须增加 `QOS_ARB_ENABLE=0|1` 说明。本文后续命令中的 `QOS_ARB_ENABLE` 表示 RTL功能开关；“事务 QoS=0”专指 `AWQOS/ARQOS=4'h0`，两者不得混称。

新增 QoS testcase target：

```makefile
qos_arb: TESTNAME = axicb_qos_arb_test
qos_arb: QOS_ARB_ENABLE = 1
qos_arb: run
```

现有 target 不设置 `QOS_ARB_ENABLE`，继续使用默认 0。

覆盖率名称建议包含模式，避免不同配置覆盖同名数据：

```makefile
CM_NAME ?= $(TESTNAME)_$(SEED)_qos$(QOS_ARB_ENABLE)
```

## 5. UVM 最小适配方案

### 5.1 Element sequence 暴露 QoS

只在以下类增加一个默认 0 的字段：

- `axicb_single_write_sequence`
- `axicb_single_read_sequence`

字段：

```systemverilog
bit [QOS_WIDTH-1:0] qos = '0;
```

写 sequence 传递：

```systemverilog
axi_single.tr_qos = qos;
```

读 sequence 同样传递。

默认必须为 0，保证所有现有调用无需修改并保持原激励。

不得修改 `axi_transaction` 的 QoS 字段、driver pin-level 驱动、monitor event 或 predictor/scoreboard QoS 透传逻辑，除非编译或测试证明存在缺失。

### 5.2 新增专用 QoS virtual sequence

新增：

```text
uvm/seq_lib/axicb_qos_arb_vseq.sv
```

建议继承：

```systemverilog
class axicb_qos_arb_vseq extends axicb_conc_base_vseq;
```

原因：复用现有上游/下游 VIF 和同目标 contention/Round-Robin 辅助检查，不新增 UVM component。

新增本地 helper 即可，不要扩大 `axicb_base_vseq` 的全部 API：

- `do_qos_write(mst_idx, addr, qos, id)`；
- `do_qos_read(mst_idx, addr, qos, id)`；
- `expect_high_qos_aw_first(...)`；
- `expect_high_qos_ar_first(...)`。

QoS winner checker 必须：

1. 确认两个上游请求在同一仲裁窗口同时 `VALID`；
2. 确认两个地址译码到同一个目标 slave；
3. 记录两者 QoS 和 source master；
4. 在下游 AW/AR handshake 时通过扩展 ID 的 source bit 判断 winner；
5. 检查下游 `AWQOS/ARQOS` 等于 winner 的 QoS；
6. 不依赖固定周期延迟；
7. 设置 timeout，并在前置条件未发生时明确报错，不能静默 PASS。

不同 QoS 场景不得调用“两个 master grant 数量相等”的旧 fairness 结论。

同 QoS 场景可以复用：

```systemverilog
expect_downstream_rr_grant_fairness(...)
```

### 5.3 新增 QoS test

新增：

```text
uvm/test/axicb_qos_arb_test.sv
```

测试结构保持现有 test 风格：

- 继承 `axicb_base_test`；
- build phase 不增加新组件；
- run phase 创建并启动 `axicb_qos_arb_vseq`；
- 正确 raise/drop objection；
- report phase 检查 UVM error 数和 scoreboard `check_count`；
- PASS/FAIL marker 使用与现有测试一致的格式。

更新：

- `uvm/seq_lib/axicb_virt_seq_lib.svh`
- `uvm/test/axicb_tests_lib.svh`

只增加必要 include，不改变原 include 顺序。

### 5.4 QoS directed 场景

新 testcase 至少覆盖：

1. AW：master0 QoS低、master1 QoS高，访问 slave0，高 QoS先到下游。
2. AW：反转高 QoS所属 master，访问 slave1，高 QoS仍先到下游。
3. AR：两种 source 方向重复上述检查。
4. 同 QoS AW：退化为 Round-Robin。
5. 同 QoS AR：退化为 Round-Robin。
6. QoS 全为 0：行为与现有 `conc_arb` 一致。
7. 两个 master 访问不同目标：各自独立完成，不发生跨目标 QoS比较。
8. 非法地址：继续走 DECERR，不因高 QoS 泄漏到下游。
9. QoS值边界：至少覆盖 `4'h0`、一个中间值和 `4'hF`。
10. AW 高 QoS获胜后，整个 W burst source 保持到 `WLAST`。

不得通过大量随机事务替代这些定向场景。

### 5.5 Assertion 最小修改

在 `uvm/vip/axi_if.sv` 现有地址稳定性 property 中加入：

```systemverilog
$stable(awqos)
$stable(arqos)
```

建议同时确保当前 property 已覆盖 VALID 下使用的地址 sideband，但本任务至少必须补 QoS。

在 `qos_arbiter.v` 中可在 `ifndef SYNTHESIS` 下增加最小内部 assertion：

- `grant` 为 one-hot 或全零；
- blocked grant 在 acknowledge 前保持稳定。

不要把复杂 fairness 或 starvation assertion 塞入 RTL。

### 5.6 Functional coverage 最小修改

在 `axicb_coverage` 中复用 upstream complete transaction：

- WRITE 采样 `t.awqos`；
- READ 采样 `t.arqos`；
- 增加 QoS bins：0、低、中、高、15；
- 至少 cross `QoS × transaction type × source master × destination slave`。

若 cross 数量过大，可保留：

- `QoS × transaction type`；
- `QoS × source master`；
- `QoS × destination slave`。

“不同 QoS竞争时高 QoS获胜”必须由 directed checker 验证，不能只用 coverage 代替。

### 5.7 Predictor 与 scoreboard 边界

当前 predictor/scoreboard 已经检查获胜事务的 QoS 透传。

本任务不得让 predictor 复制 QoS arbiter 的 grant/mask 状态机，也不得要求 predictor 预测精确 winner 周期。

职责保持：

```text
predictor + scoreboard：获胜事务的 route/ID/payload/QoS 透传正确
QoS vseq checker：竞争窗口内最高 QoS winner 正确
existing conc checker：同 QoS Round-Robin、公平性、burst完整性
assertion：VALID stall 下 QoS 稳定、grant不抢占
```

## 6. 编译与回归要求

### 6.0 修改前 baseline

开始编辑前必须：

```bash
git status --short --branch
```

保留用户已有修改，不得清理或覆盖 dirty worktree。

若 EDA 环境可用，在修改前至少运行当前版本：

```bash
uvm/sim/with_vcs_env.sh make -C uvm/sim smoke \
  SEED=1 OUT=out/baseline_smoke

uvm/sim/with_vcs_env.sh make -C uvm/sim conc_arb \
  SEED=1 OUT=out/baseline_conc_arb
```

记录 baseline 日志路径和 UVM error/fatal 统计。若 baseline 已失败，不得把原有失败归因于 QoS 修改。

### 6.1 静态检查

至少执行：

```bash
git diff --check
make -C uvm/sim -n elab QOS_ARB_ENABLE=0
make -C uvm/sim -n elab QOS_ARB_ENABLE=1
make -C uvm/sim show test
make -C uvm/sim show vseq
python3 tools/regress.py --config regress/smoke.json --dry-run
```

确认：

- `qos_arbiter.v` 被 `DFILES := $(wildcard ../../dut/*.v)` 自动纳入；
- 新 test/vseq 被 active package include；
- Makefile 中出现 `qos_arb` target；
- 无未引用类、重复宏、宽度错误或 latch。

### 6.2 RTL/UVM compile 与 elaboration

在有 VCS 的 EDA 环境中分别执行：

```bash
uvm/sim/with_vcs_env.sh make -C uvm/sim elab \
  QOS_ARB_ENABLE=0 OUT=out/qos_compile_off

uvm/sim/with_vcs_env.sh make -C uvm/sim elab \
  QOS_ARB_ENABLE=1 OUT=out/qos_compile_on
```

不得仅验证 QoS=1；关闭模式也必须完成 compile 和 elaboration。单独执行 `comp` 无法证明 elaboration parameter 已正确选择 generate 分支。

### 6.3 现有 9 个测试 A/B 回归

测试集合：

```text
smoke
decode_full_range
decerr_single
decerr_burst
decerr_id
decerr_dual_mst
burst_type
conc_arb
order_resp
```

顺序运行，避免当前共享 VCS analysis database 的并行 compile 风险：

```bash
for t in smoke decode_full_range decerr_single decerr_burst decerr_id \
         decerr_dual_mst burst_type conc_arb order_resp; do
  uvm/sim/with_vcs_env.sh make -C uvm/sim "$t" \
    QOS_ARB_ENABLE=0 SEED=1 OUT="out/qos_off/$t" || exit 1
done
```

然后开启 QoS，但现有测试仍使用全零 QoS：

```bash
for t in smoke decode_full_range decerr_single decerr_burst decerr_id \
         decerr_dual_mst burst_type conc_arb order_resp; do
  uvm/sim/with_vcs_env.sh make -C uvm/sim "$t" \
    QOS_ARB_ENABLE=1 SEED=1 OUT="out/qos_on_equal/$t" || exit 1
done
```

两组都必须满足：

- `UVM_ERROR : 0`；
- `UVM_FATAL : 0`；
- scoreboard PASS；
- predictor 无 undrained state；
- `conc_arb` 在全零 QoS下仍满足 Round-Robin fairness；
- `order_resp`、DECERR、burst 和 ID 检查无变化。

每个 case 必须使用日志分类工具或等价检查，不能只看 make 返回码：

```bash
python3 tools/triage_log.py \
  uvm/sim/out/qos_off/smoke/log/run.log
```

其他 case 使用各自实际 `OUT/log/run.log` 路径。

### 6.4 QoS 专用测试

```bash
uvm/sim/with_vcs_env.sh make -C uvm/sim qos_arb \
  QOS_ARB_ENABLE=1 SEED=1 OUT=out/qos_priority
```

至少使用多个 seed 验证测试同步不依赖调度偶然性：

```bash
for seed in 1 2 3 4 5; do
  uvm/sim/with_vcs_env.sh make -C uvm/sim qos_arb \
    QOS_ARB_ENABLE=1 SEED="$seed" OUT="out/qos_priority_seed_$seed" || exit 1
done
```

建议新增 `regress/qos.json`，只包含 `qos_arb`，且初始 `jobs=1`。

### 6.5 文档更新

只有在真实 EDA 回归完成后，才更新：

- `README.md`
- `README.zh-CN.md`
- 必要的 `uvm/sim/README.md` 命令说明

两版首页必须同步说明：

- QoS仲裁由 `QOS_ARB_ENABLE` 参数控制，默认关闭；
- 开启后是“最高 QoS优先、同 QoS Round-Robin”；
- QoS只影响AW/AR；
- B/R仍为Round-Robin；
- 第一版没有跨QoS防饥饿保证；
- 新的 `qos_arb` 运行命令和验证状态。

若真实回归未完成，README只能写“implemented, pending EDA validation”，不得写“supported and verified”。

### 6.6 首错处理

发生失败时：

1. 保留对应 `OUT` 目录和日志；
2. 从 compile/elab/run log 的第一个 actionable error 开始；
3. 不得通过弱化 scoreboard、关闭 assertion、删除 checker 或扩大 timeout 掩盖错误；
4. 若 `QOS_ARB_ENABLE=0` 失败，优先检查参数传播和关闭分支是否仍直接使用原始 `arbiter`；
5. 若 `QOS_ARB_ENABLE=1` 且事务 `AWQOS/ARQOS=0` 失败，优先检查最高 QoS 集合是否等于全部有效 request；
6. 若专用 QoS test失败，先确认两个上游请求是否真的形成同一目标、同一仲裁窗口的 contention，再判断 RTL winner；
7. 区分 DUT bug、test同步问题、monitor采样问题和 checker假设错误。

## 7. 验收标准

只有以下条件全部满足，任务才能标记完成：

### RTL

- 新增 `qos_arbiter.v`，无 latch、无写死 2-port、无复制现有 arbiter 状态机。
- `QOS_ARB_ENABLE` 默认 0，并完整传到 `axi_crossbar_wr/rd` 的 AW/AR generate。
- `QOS_ARB_ENABLE=0` 直接实例化原始 `arbiter`。
- `QOS_ARB_ENABLE=1` 选择最大 QoS 集合，同 QoS使用现有 RR。
- grant 在 acknowledge 前不被抢占。
- W/B/R/DECERR/ID/outstanding 逻辑未被重写。

### UVM

- element write/read sequence 新增默认 0 QoS 并正确传给低层 sequence。
- 新增 `axicb_qos_arb_vseq` 和 `axicb_qos_arb_test`。
- 非零 QoS contention 有独立 checker，不以 coverage 代替。
- 同 QoS继续复用 Round-Robin检查。
- QoS stability assertion 已补充。
- predictor/scoreboard 只保留已有 QoS透传检查，没有复制仲裁状态机。

### 验证结果

- `QOS_ARB_ENABLE=0` 完整现有 9-test 回归通过。
- `QOS_ARB_ENABLE=1`、现有事务 `AWQOS/ARQOS=0` 的9-test回归通过。
- `QOS_ARB_ENABLE=1` 专用 QoS test 至少5个 seed通过。
- 日志无 UVM_ERROR/UVM_FATAL。
- 无 unmatched expected、reference memory mismatch、undrained predictor state。
- 真实 VCS 日志路径和第一条/最终错误统计被记录到完成报告。

如果没有运行 EDA 仿真，只能报告“源码修改和静态检查完成，VCS验证未完成”，不得宣称功能通过。

## 8. 禁止事项

执行 agent 不得：

- 修改 B/R response arbitration 为 QoS-aware；
- 给 W beat 增加独立 QoS仲裁；
- 修改地址译码以根据 QoS选择不同 target；
- 改变 ID 扩展格式；
- 改变 same-ID ordering；
- 改变 outstanding/issue/accept depth；
- 修改 DECERR 产生时机或返回长度；
- 实现 preemption；
- 默认加入 aging 或 starvation protection；
- 重写 predictor、scoreboard、driver、monitor或UVM架构；
- 大范围重命名、格式化或删除原注释；
- 通过降低检查强度使测试通过；
- 在没有日志证据时声称 regression PASS。

## 9. Agent 最终交付格式

完成后必须报告：

1. 修改和新增的文件；
2. QoS仲裁算法及参数默认值；
3. `QOS_ARB_ENABLE=0` 为什么与原行为兼容；
4. `QOS_ARB_ENABLE=1` 时不同QoS和同QoS的选择规则；
5. 明确未修改的W/B/R/DECERR/ordering逻辑；
6. UVM最小适配内容；
7. 静态检查命令与结果；
8. `QOS_ARB_ENABLE=0` 九测试结果；
9. `QOS_ARB_ENABLE=1` 且事务QoS全零的九测试结果；
10. QoS专用test与seed结果；
11. coverage/assertion结果；
12. 未验证事项和剩余风险；
13. 所有生成日志的实际路径。

若任务受阻，应报告第一个可操作错误、对应文件/行号、已尝试的验证和下一步，不得用笼统的“环境问题”代替证据。
