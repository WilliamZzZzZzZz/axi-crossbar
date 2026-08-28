**简体中文** | [English](README.md)

# AXI Crossbar RTL 与 UVM 验证

这是一个面向 AXI4 Crossbar 的 RTL 与 UVM 模块级验证项目。当前验证目标为 **2 个上游 Master × 2 个下游 Slave** 的 Crossbar 实例，重点验证地址译码、五通道路由、ID 扩展与返回、burst、DECERR、outstanding、ordering 和 Round-Robin 仲裁。

项目包含参数化 Crossbar RTL、自研 AXI UVM VIP、channel-level predictor、reference memory、scoreboard、functional coverage、定向 testcase，以及基于 Makefile 和 Python 的回归基础设施。

> **项目状态：开发中。** Predictor 已接入源码和编译边界，但当前仓库没有提交生成的 VCS 日志、波形或覆盖率数据库。请在配置好的 EDA 环境中完成编译与回归后，再依据日志判断 PASS/FAIL。

## 当前 DUT 配置

| 项目 | 当前 2×2 Testbench 配置 |
| --- | --- |
| AXI 数据宽度 | 32 bit |
| AXI 地址宽度 | 32 bit |
| 上游 ID 宽度 | 8 bit |
| 下游 ID 宽度 | 9 bit，`{source_master, original_id}` |
| 上游接口 | `s00_axi`、`s01_axi` |
| 下游接口 | `m00_axi`、`m01_axi` |
| Slave 0 地址空间 | `0x0000_0000`–`0x0000_FFFF` |
| Slave 1 地址空间 | `0x0001_0000`–`0x0001_FFFF` |
| 非法地址 | Crossbar 内部产生 `DECERR` |
| Burst | FIXED、INCR、WRAP；8-bit AxLEN |
| 每个上游不同 ID thread | 2 |
| 每个上游 accepted transactions | 16 |
| 每个下游 issue depth | 4 |
| 仲裁 | Blocking Round-Robin |
| QoS | `AWQOS/ARQOS` 透传，不参与优先级仲裁 |
| USER signals | 当前 testbench 配置为 disabled |

通用 `axi_crossbar` RTL 支持参数化端口数量和地址区域；本仓库当前 UVM 环境及 predictor 针对上述 2×2 实例配置。

## RTL 架构

```text
Upstream AXI Masters                     Downstream AXI Slaves

  s00_axi ──┐                         ┌── m00_axi  [0x0000_0000 / 64 KiB]
            ├── decode + arbitration ─┤
  s01_axi ──┘                         └── m01_axi  [0x0001_0000 / 64 KiB]

             AW/W/B and AR/R are implemented as independent paths
```

主要 RTL：

- `dut/axi_crossbar_wrap_2x2.v`：2×2 标量端口封装。
- `dut/axi_crossbar.v`：参数化 Crossbar 顶层，分离 read/write 数据路径。
- `dut/axi_crossbar_addr.v`：地址译码、connect/secure 过滤、thread 和 acceptance 管理。
- `dut/axi_crossbar_wr.v`：AW/W/B 路由、写请求仲裁、B 返回仲裁和写 DECERR。
- `dut/axi_crossbar_rd.v`：AR/R 路由、读请求仲裁、R 返回仲裁和读 DECERR。
- `dut/axi_register_wr.v`、`dut/axi_register_rd.v`：bypass、simple 和 skid channel registers。
- `dut/arbiter.v`、`dut/priority_encoder.v`：Round-Robin/固定优先级基础模块；当前 Crossbar 实例选择 Round-Robin。

写数据通道没有独立 ID。Crossbar 在 AW 获得仲裁后锁定对应 W 数据源，直到该 burst 的 `WLAST` 完成。R 返回仲裁同样保持到 `RLAST`。

## UVM 验证架构

```text
                         ┌──────────────────────────┐
 virtual sequence ──────▶│ master sequencer/driver  │
                         └────────────┬─────────────┘
                                      │ upstream AW/W/AR
                                      ▼
                                ┌──────────┐
                                │   DUT    │
                                └────┬─────┘
                                     │ downstream AW/W/AR
                                     ▼
                         ┌──────────────────────────┐
                         │ slave responder + memory │
                         └──────────────────────────┘

upstream complete-transaction monitors ────────────────▶ functional coverage

upstream/downstream channel handshake events ──▶ predictor ──▶ expected
                    │                                      │
                    └──────────── actual ──────────────────┴──▶ scoreboard
```

环境包含：

- 两个 active AXI master agents。
- 两个带 sparse memory 的 AXI slave responders。
- 一个 virtual sequencer。
- 一个 channel-event predictor。
- 一个 expected/actual scoreboard。
- 一个 upstream functional coverage collector。

### Predictor

`uvm/env/axicb_predictor.sv` 根据 monitor 实际观察到的 AXI handshake 建立期望结果：

- 根据地址预测目标 slave。
- 将上游 ID 扩展为下游 ID，并在 B/R 返回时还原。
- 预测 AW、W、AR payload 的透明传递。
- 预测下游 B/R 到正确上游端口的透明返回。
- 非法写不产生下游 AW/W，并在 WLAST 后预测 B/DECERR。
- 非法读不产生下游 AR，并预测 `ARLEN+1` 个零数据 R/DECERR。
- 使用 transaction key、同 ID FIFO 和 reset epoch 管理 outstanding。
- 维护 reference memory，按 burst 地址和 WSTRB 更新期望数据。

Predictor **不复制** DUT 的 READY 时序、pipeline registers 或 Round-Robin 状态机。精确仲裁、公平性和 contention 由专用 checker/testcase 验证。

### Scoreboard

`uvm/env/axicb_scoreboard.sv` 比较 predictor 产生的 expected event 与 DUT 输出端 monitor 观察到的 actual event：

- 检查下游 AW/AR 的目标端口、扩展 ID 和全部属性。
- 使用已匹配 AW 的 transaction key 检查 WDATA、WSTRB、WLAST 和 burst 归属。
- 检查上游 BID/RID、BRESP/RRESP、RDATA 和 RLAST。
- 检测非法地址向下游泄漏。
- 在 report phase 检查 expected events 和 outstanding ownership 是否排空。

## 目录结构

```text
.
├── dut/                    # AXI Crossbar RTL
├── uvm/
│   ├── vip/                # AXI transaction、interface、agents、drivers、monitors、responders
│   ├── env/                # predictor、scoreboard、coverage、virtual sequencer、environment
│   ├── seq_lib/            # active virtual sequences 和 element sequences
│   ├── test/               # active UVM tests
│   ├── testbench/          # 2×2 DUT top、clock/reset、config_db VIF bindings
│   └── sim/                # Makefile、VCS environment wrapper、DVE scripts
├── regress/                # smoke/daily regression JSON 配置
├── tools/                  # Python regression runner 和 log triage
└── reports/                # 自动生成的 Markdown/CSV 回归报告
```

`uvm/seq_lib/ram_virt_seq/` 和 `uvm/test/ram_test/` 当前未进入 active package include 链，不属于现役 testcase 集合。

## Testcase

| Make target | UVM test | 验证重点 |
| --- | --- | --- |
| `smoke` | `axicb_smoke_test` | 四条 master→slave 路径、地址边界、单拍写后读 |
| `decode_full_range` | `axicb_decode_full_range_test` | base/mid/end 地址、相邻边界、route 和 ID 扩展 |
| `decerr_single` | `axicb_decerr_single_test` | 单拍非法读写和 downstream isolation |
| `decerr_burst` | `axicb_decerr_burst_test` | 多拍 DECERR、WLAST/RLAST、错误后恢复 |
| `decerr_id` | `axicb_decerr_id_test` | 不同 burst 长度下的 DECERR ID 保持 |
| `decerr_dual_mst` | `axicb_decerr_dual_mst_test` | 双 master 合法/非法并发与读写交叉 |
| `burst_type` | `axicb_burst_type_test` | 1/2/4-byte；FIXED/INCR 1–16 beats、WRAP 2/4/8/16 beats、INCR 长 burst 32–256 beats |
| `conc_arb` | `axicb_conc_arb_test` | 同目标竞争、burst integrity、Round-Robin fairness |
| `order_resp` | `axicb_order_resp_test` | thread/issue depth、same-ID ordering、B/R response contention |

查看 Makefile 当前注册的测试：

```bash
make -C uvm/sim show test
make -C uvm/sim show vseq
```

## 环境要求

- Linux x86-64 EDA 环境。
- Synopsys VCS，支持 UVM 1.2。
- 有效的 Synopsys license 配置。
- GNU Make 和 Bash。
- Python 3.10 或更高版本，用于 regression runner。
- DVE、Verdi、URG 为 GUI、波形和覆盖率查看的可选工具。

`uvm/sim/with_vcs_env.sh` 提供本项目默认的 VCS/Verdi 环境变量，可通过外部环境覆盖其中的安装路径和 license 设置。

## 快速开始

在仓库根目录执行：

```bash
# 查看全部命令
uvm/sim/with_vcs_env.sh make -C uvm/sim help

# 基础功能与 predictor 数据流
uvm/sim/with_vcs_env.sh make -C uvm/sim smoke SEED=1

# DECERR burst 与 downstream isolation
uvm/sim/with_vcs_env.sh make -C uvm/sim decerr_burst SEED=1

# Outstanding、ordering 和 response arbitration
uvm/sim/with_vcs_env.sh make -C uvm/sim order_resp SEED=1
```

也可以指定完整 UVM test class：

```bash
uvm/sim/with_vcs_env.sh make -C uvm/sim run \
  TESTNAME=axicb_conc_arb_test SEED=7 VERB=UVM_MEDIUM
```

生成文件默认位于 `uvm/sim/out/`。可以用独立 OUT 目录隔离一次运行：

```bash
uvm/sim/with_vcs_env.sh make -C uvm/sim smoke \
  SEED=1 OUT=out/predictor_smoke
```

## 回归

Regression runner 仍调用 `uvm/sim/Makefile`，并为每个 test×seed case 分配独立输出目录。

```bash
# 仅展开命令，不运行仿真
python3 tools/regress.py --config regress/smoke.json --dry-run

# 3 tests × 3 seeds
uvm/sim/with_vcs_env.sh python3 tools/regress.py \
  --config regress/smoke.json

# 9 tests × 5 seeds
uvm/sim/with_vcs_env.sh python3 tools/regress.py \
  --config regress/daily.json
```

回归报告写入：

- `reports/regress_summary_<timestamp>.md`
- `reports/regress_results_<timestamp>.csv`

PASS 判定同时考虑 make return code、timeout、`UVM_ERROR`、`UVM_FATAL` 以及 testcase PASS/FAIL marker。

每个 case 的 `OUT` 目录相互隔离，但当前 VCS analysis database 仍由 `uvm/sim` 工作目录共享。如果 EDA 环境不支持并行 compile，请使用 `--jobs 1` 运行回归。

## 日志、波形与覆盖率

```bash
cd uvm/sim

# 查看错误或特定组件日志
make check error
make check fatal
make checkinfo axicb_scoreboard

# GUI
make smoke GUI=1

# 运行全部 Makefile testcase 并合并覆盖率
make all_cov
make dvecov
make verdicov
```

推荐首先检查 `out/log/run.log` 中的：

```text
UVM_ERROR : 0
UVM_FATAL : 0
Scoreboard PASS: channel_checks=... decerr_transactions=...
```

还应确认不存在：

```text
reference memory mismatch
no predicted DUT output
downstream W has no matched AW
undrained predictor state
unmatched expected output
```

## 当前边界

- QoS 只做 sideband 透传，不提供 QoS-aware priority arbitration。
- USER signals 在当前 2×2 testbench 中关闭。
- 合法 slave responder 当前固定返回 OKAY；尚未提供 SLVERR/EXOKAY response injection。
- Predictor 针对当前两个 64 KiB 地址区域及当前 ID 扩展规则。
- Predictor 已实现 reset flush；现役 9 个 testcase 尚未包含独立的 mid-transaction reset 测试。
- 精确 READY latency、pipeline timing 和 Round-Robin grant 顺序不由 predictor 建模。
- 生成的 simulator artifacts、波形、coverage database 和 regression reports 默认不提交到 Git。
- 仓库当前未附带可证明最新源码已通过 VCS regression 的日志；请以本地 EDA 运行结果为准。

以 `make -C uvm/sim help` 输出作为仿真命令的权威列表。
