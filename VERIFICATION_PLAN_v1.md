# AXI4 2×2 Non-blocking Crossbar — 验证计划 (Verification Plan)

> **DUT**: `axi_crossbar_wrap_2x2`（源自 Alex Forencich verilog-axi）
> **方法学**: UVM 1.2 | **仿真器**: VCS
> **配置**: 2 Slave IF × 2 Master IF, DATA_WIDTH=32, ADDR_WIDTH=32
> **基线 Commit**: `6e3fced` (2026-04-18)

---

## A. 已完成基线 (Completed Baseline)

### A.1 Testbench 架构现状

```
                              axi_crossbar_tb
                        ┌───────────────────────────┐
                        │          axicb_base_test  │
                        │  ┌────────────────────┐   │
                        │  │  axi_crossbar_env  │   │
                        │  │                    │   │
   ┌────────────┐       │  │  ┌──────────────┐  │   │      ┌────────────┐
   │ mst_agent00├──s00──┤  │  │  virt_sqr    │  │   ├─m00──┤ slv_agent00│
   │ (sequencer │       │  │  │  (mst_sqr00, │  │   │      │ (responder │
   │  driver    │       │  │  │   mst_sqr01) │  │   │      │  monitor)  │
   │  monitor)  │       │  │  └──────────────┘  │   │      └────────────┘
   └────────────┘       │  │                    │   │
                        │  │  ┌──────┐ ┌─────┐  │   │
   ┌────────────┐       │  │  │ scb  │ │ cov │  │   │      ┌────────────┐
   │ mst_agent01├──s01──┤  │  └──────┘ └─────┘  │   ├─m01──┤ slv_agent01│
   │ (sequencer │       │  │                    │   │      │ (responder │
   │  driver    │       │  └────────────────────┘   │      │  monitor)  │
   │  monitor)  │       │      axi_crossbar_wrap_2x2│      └────────────┘
   └────────────┘       └───────────────────────────┘
```

**关键架构说明**：

| 组件 | 类名 | 结构 |
|---|---|---|
| Upstream Agent ×2 | `axi_master_agent` | `axi_master_sequencer` + `axi_master_driver`（分 write/read sub-driver）+ `axi_monitor#(ID_WIDTH=8, IS_DOWNSTREAM=0)` |
| Downstream Agent ×2 | `axi_slave_agent` | `axi_slave_responder`（含 `write_responder` + `read_responder` + `axi_slave_mem`）+ `axi_monitor#(M_ID_WIDTH=9, IS_DOWNSTREAM=1)` — **无 sequencer，纯被动响应** |
| Virtual Sequencer | `axicb_virtual_sequencer` | 持有 `axi_mst_sqr00` / `axi_mst_sqr01`；提供 `get_master_sqr(idx)` 索引方法 |
| Scoreboard | `axicb_scoreboard` | `uvm_subscriber#(axi_transaction)`，内含 `ref_mem` 关联数组；仅接收 **upstream monitor** 数据（downstream→scb 已注释掉） |
| Coverage | `axicb_coverage` | `uvm_subscriber#(axi_transaction)`，接收 upstream + downstream 四路 monitor 数据 |
| Base Test | `axicb_base_test` | 创建 env；`run_phase` 中设置 `drain_time = 1us` |

**Analysis Port 连接现状**（`axi_crossbar_env.connect_phase`）：

```
mst_agent00.item_collected_port → scb.analysis_export  ✅
mst_agent00.item_collected_port → cov.analysis_export  ✅
mst_agent01.item_collected_port → scb.analysis_export  ✅
mst_agent01.item_collected_port → cov.analysis_export  ✅
slv_agent00.item_collected_port → cov.analysis_export  ✅
slv_agent01.item_collected_port → cov.analysis_export  ✅
slv_agent00 → scb  ❌ (已注释，仅 upstream 喂入 scb)
slv_agent01 → scb  ❌ (已注释)
```

### A.2 Sequence 层级现状

```
axicb_base_virtual_sequence          (获取 vif, 提供 compare_single_data/compare_data 工具方法)
  └── axicb_smoke_virtual_sequence   (body: 遍历 4 路径, 每路径调 write_and_read_test + boundary_addr_test)

axicb_base_sequence                  (持有 src_master_idx, p_sequencer=axicb_virtual_sequencer)
  ├── axicb_single_write_sequence    (封装 axi_master_single_sequence WRITE, 上报 bresp)
  └── axicb_single_read_sequence     (封装 axi_master_single_sequence READ, 上报 rresp + data)

axi_base_sequence                    (VIP 层 base)
  └── axi_master_single_sequence     (VIP 层: do_write / do_read, 支持 wait_for_response 开关)
```

**`src_master_idx` 流转**: `virtual_seq` 设置 `element_seq.src_master_idx` → element_seq 在 `body()` 中调用 `p_sequencer.get_master_sqr(src_master_idx)` 获取对应 master 的 sequencer → 将 VIP 层 sequence start 到该 sequencer。

### A.3 Scoreboard 现状

`axicb_scoreboard` (Layer 1 — Data Integrity):
- 数据结构: `bit [31:0] ref_mem[bit [31:0]]`（word 级关联数组）
- `process_write`: 按 burst 参数计算每拍 word_addr，用 `merge_data_with_strb` 合并写入 ref_mem
- `process_read`: 按 burst 参数计算每拍 word_addr，与 ref_mem 预期值逐拍比对
- `calculate_beat_addr`: 支持 FIXED / INCR（含 unaligned 首拍），**WRAP 尚未实现**
- `report_phase`: 打印 check_count / error_count

### A.4 Coverage 现状

`axicb_coverage`:
- `cg_trans_type`: WRITE / READ bins — ✅ 已 sample
- `cg_burst`: BURST_TYPE(FIXED/INCR) × BURST_LEN(single/2/4/8/16) × BURST_SIZE(1B/2B/4B) — ✅ 已 sample，**WRAP 未加入 bins**
- `cg_comprehensive`: TYPE × BURST × LEN 三维交叉 — 已定义但 **未在 `new()` 中创建、未 sample**

### A.5 VIP 能力现状

| 能力 | 状态 | 说明 |
|---|---|---|
| 非零 ID | ✅ 已支持 | `axi_master_single_sequence.tr_id` 是 rand 字段，默认 `'0` |
| 多拍 burst | ✅ 已支持 | `every_beat_data[]` / `every_beat_wstrb[]` 动态数组 |
| Pipeline (non-blocking) | ✅ 已支持 | `wait_for_response = 0` 跳过 `get_response` |
| BRESP/RRESP 回传 | ✅ 已支持 | `write_bresp` / `read_rresp` 字段 |
| Slave memory | ✅ 已支持 | `axi_slave_mem` 关联数组 + `write_word_with_strb` + `calc_beat_addr`(INCR/FIXED)，**WRAP 未实现** |
| Slave backpressure | ⚠️ 部分 | responder 无可配延迟旋钮，需手动添加 |
| Downstream ID 区分 | ✅ 已支持 | `axi_monitor` IS_DOWNSTREAM 参数化，采集 `m_awid`/`m_arid` 9-bit |

### A.6 Smoke Test 覆盖事实 (commit `6e3fced`)

| 已覆盖项 | 细节 |
|---|---|
| 4 条基本路径 | m0→s0, m0→s1, m1→s0, m1→s1 串行遍历 |
| Single-beat write/read compare | 序列内 `compare_single_data` + scoreboard `ref_mem` 双重验证 |
| Boundary address test | 每条路径测试 `base_addr` 和 `base_addr + 0xFFFC` |
| 随机化地址/数据 | `std::randomize` 控制 `rand_addr`(4B aligned, within slave range) / `wr_data` / `txn_per_path`(2~10) |
| BRESP/RRESP 检查 | sequence 层显式检查 `!= OKAY` 则 `uvm_error` |
| Test report_phase | 检查 `scb.check_count > 0`，汇总 `UVM_ERROR` 数，打印 PASS/FAIL |
| src_master_idx 参数化 | element sequence 通过 idx 索引到正确 master sequencer |

| 未覆盖 / 已知缺陷 |
|---|
| 所有事务 `tr_id = 0`，未测试非零 ID |
| 仅 INCR / single-beat / 4B-aligned / WSTRB=4'hF |
| 无并发（4 路径串行执行） |
| 无 DECERR 测试 |
| Coverage `cg_comprehensive` 未实例化 |
| Scoreboard 不支持 WRAP |

---

## B. 下一阶段直接执行项 (Next Phase — Immediate Execution)

### B.1 执行优先级排序

按照 **crossbar 核心功能优先** 和 **前置依赖优先** 原则：

```
B.1.1  DECERR directed tests           ← crossbar 独有错误路径，必须尽早验证
B.1.2  Address decode / region tests    ← crossbar 路由核心
B.1.3  Response routing / ID tests      ← crossbar 路由核心
B.1.4  Basic outstanding / OOO tests    ← crossbar 并发核心
B.1.5  Scoreboard / ref_model 强化      ← 贯穿全过程的基础设施
```

### B.1.1 DECERR Directed Tests

> **目标**: 验证 crossbar 内部 DECERR 生成逻辑（`axi_crossbar_addr.match=0` 分支、`w_drop_reg`、`decerr_len_reg`）

| # | Testcase | Virtual Sequence | 设计思路 | 期望结果 |
|---|---|---|---|---|
| N-01 | `axicb_decerr_write_test` | `axicb_decerr_write_vseq` | m0 向非法地址 `32'h0002_0000` 发起单拍 write，检查 BRESP | BRESP = DECERR (2'b11)，W 数据被 `w_drop_reg` 吞掉，无挂死 |
| N-02 | `axicb_decerr_read_test` | `axicb_decerr_read_vseq` | m0 向非法地址发起单拍 read，检查 RRESP | RRESP = DECERR (2'b11)，RLAST=1 |
| N-03 | `axicb_decerr_burst_write_test` | `axicb_decerr_burst_write_vseq` | m0 向非法地址发起多拍 write (len=3)，之后发一笔合法写 | DECERR 返回，全部 W beats 被 drop，后续合法事务正常完成 |
| N-04 | `axicb_decerr_burst_read_test` | `axicb_decerr_burst_read_vseq` | m0 向非法地址发起多拍 read (len=3)，检查 DECERR 拍数 | 收到 4 拍 RRESP=DECERR，最后一拍 RLAST=1 |
| N-05 | `axicb_decerr_then_legal_test` | `axicb_decerr_then_legal_vseq` | 先非法再合法：非法 write → 合法 write → 合法 read-back | DECERR 后 crossbar 状态正常，合法事务数据正确 |
| N-06 | `axicb_decerr_both_masters_test` | `axicb_decerr_both_masters_vseq` | m0 和 m1 分别向非法地址发请求 | 两个 master 各自收到 DECERR，互不影响 |

**Scoreboard 适配**: DECERR 事务不应写入 `ref_mem`（地址非法，不对应真实 slave）。scoreboard 的 `process_write` / `process_read` 需加入 BRESP/RRESP 过滤。

**VIP 适配**: `axi_master_single_sequence.do_write` 目前在 `rsp.bresp != OKAY` 时打 `uvm_error`；DECERR 测试中这是**预期行为**，sequence 需新增旁路开关 `bit expect_decerr = 0`，或在 test 层使用 `uvm_report_catcher` 过滤。

### B.1.2 Address Decode / Region Tests

> **目标**: 验证 `axi_crossbar_addr` 地址匹配逻辑在正常范围内的完整性

| # | Testcase | Virtual Sequence | 设计思路 | 期望结果 |
|---|---|---|---|---|
| N-07 | `axicb_decode_full_range_test` | `axicb_decode_full_range_vseq` | 遍历 slave0 和 slave1 各自的 {起始, 中间, 末尾} 6 个地址点 write-read | 全部译码正确，数据完整 |
| N-08 | `axicb_decode_cross_boundary_test` | `axicb_decode_cross_boundary_vseq` | 在 slave0 末尾 (`0x0000_FFFC`) 和 slave1 起始 (`0x0001_0000`) 连续发请求 | 路由到正确 slave，无混淆 |
| N-09 | `axicb_decode_random_addr_test` | `axicb_decode_random_addr_vseq` | 单 master 随机地址（约束在合法范围），大量事务 | scoreboard 全部通过 |

### B.1.3 Response Routing / ID Tests

> **目标**: 验证 ID 扩展（upstream 8-bit → downstream 9-bit）、ID 还原、response 路由

| # | Testcase | Virtual Sequence | 设计思路 | 期望结果 |
|---|---|---|---|---|
| N-10 | `axicb_id_nonzero_test` | `axicb_id_nonzero_vseq` | m0 用 `tr_id=8'hAB`，m1 用 `tr_id=8'hAB`，分别向 s0 写读 | 各自 response 正确返回，upstream bid/rid == 原始 ID |
| N-11 | `axicb_id_boundary_test` | `axicb_id_boundary_vseq` | 使用 ID 极值 `8'h00` 和 `8'hFF` 分别测试 | ID 扩展/还原正确 |
| N-12 | `axicb_response_route_test` | `axicb_response_route_vseq` | m0→s0 和 m1→s1 同时发请求（fork-join），检查 response 不混淆 | 各 master 收到属于自己的 response |
| N-13 | `axicb_same_id_diff_master_test` | `axicb_same_id_diff_master_vseq` | m0 和 m1 用完全相同的 ID + 相同 slave，验证 downstream ID MSB 区分 | downstream 观察到不同 9-bit ID，response 不混淆 |

**实现要点**: 需在 element sequence 层将 `tr_id` 字段暴露到 virtual sequence 层。当前 `axicb_single_write_sequence` / `axicb_single_read_sequence` 未暴露 ID 字段，需新增。

### B.1.4 Basic Outstanding / OOO Tests

> **目标**: 验证 `M_ISSUE=4` / `S_THREADS=2` 限制下的多事务并发行为

| # | Testcase | Virtual Sequence | 设计思路 | 期望结果 |
|---|---|---|---|---|
| N-14 | `axicb_outstanding_basic_test` | `axicb_outstanding_basic_vseq` | 单 master 用 `wait_for_response=0` 连续发 4 笔 write 到 s0，最后统一等 response | 4 笔均成功，数据正确 |
| N-15 | `axicb_outstanding_read_test` | `axicb_outstanding_read_vseq` | 单 master 连发 4 笔 read（pipeline 模式） | 4 笔 read 数据均正确 |
| N-16 | `axicb_two_id_ordering_test` | `axicb_two_id_ordering_vseq` | 单 master 用 2 个不同 ID 各发 2 笔到 s0 | 同 ID 保序；不同 ID 之间无约束 |
| N-17 | `axicb_thread_limit_basic_test` | `axicb_thread_limit_basic_vseq` | 单 master 用 3 个不同 ID 依次发请求（超过 S_THREADS=2） | 第 3 个 ID 被阻塞直到前序完成释放 slot，无死锁 |

**实现要点**: Pipeline 模式测试需要使用 `wait_for_response=0`（已被 VIP 支持）。sequence 层需支持 "发多笔后统一回收" 的模式。

### B.1.5 Scoreboard / Ref-model 强化

> **贯穿全过程**，但需在 N-01~N-17 之前/期间完成

| # | 改进项 | 说明 |
|---|---|---|
| S-01 | DECERR 过滤 | `process_write` / `process_read` 检查 `bresp`/`rresp`，DECERR 事务跳过 ref_mem 操作 |
| S-02 | WRAP 地址计算 | `calculate_beat_addr` 补充 WRAP 分支（后续 burst 测试前置） |
| S-03 | Coverage `cg_comprehensive` 激活 | 在 `new()` 中创建、在 `write()` 中 sample |
| S-04 | Element sequence 暴露 `tr_id` | `axicb_single_write_sequence` / `axicb_single_read_sequence` 新增 `bit [7:0] tr_id = 0` 字段，传递到 VIP 层 |
| S-05 | `expect_decerr` 开关 | VIP 层 `axi_master_single_sequence` 新增 `bit expect_decerr = 0`，为 1 时不对 non-OKAY bresp/rresp 打 `uvm_error` |

---

## C. 后续 Roadmap (Future Phases)

以下阶段按依赖关系排列，在 B 阶段全部通过后依次推进。

### C.1 基础 Burst 功能

| Testcase | 设计思路 |
|---|---|
| `axicb_incr_burst_test` | INCR burst, len=1/2/4/8/16, 4B aligned, 全路径 |
| `axicb_fixed_burst_test` | FIXED burst, 每拍同地址 |
| `axicb_max_burst_test` | `awlen=255`, 256 拍 INCR |
| `axicb_wrap_burst_test` | WRAP burst, 合法长度 (2/4/8/16) |

前置: Scoreboard WRAP 地址计算 (S-02)、Slave mem WRAP 支持

### C.2 Narrow / Partial Strobe / Unaligned

| Testcase | 设计思路 |
|---|---|
| `axicb_narrow_transfer_test` | `awsize` < 4B, 1B/2B narrow write-read |
| `axicb_partial_strobe_test` | 随机 WSTRB 模式 |
| `axicb_unaligned_test` | 非 4B 对齐起始地址 INCR burst |

### C.3 并发与仲裁

| Testcase | 设计思路 |
|---|---|
| `axicb_parallel_diff_slave_test` | m0→s0, m1→s1 同时 fork, 互不阻塞 |
| `axicb_same_slave_write_test` | m0, m1 同时向 s0 写 |
| `axicb_same_slave_read_test` | m0, m1 同时向 s0 读 |
| `axicb_same_slave_mixed_test` | m0 写 s0, m1 读 s0 同时 |
| `axicb_arb_fairness_test` | 统计 round-robin 公平性 |

### C.4 深度 Outstanding / Thread / Accept

| Testcase | 设计思路 |
|---|---|
| `axicb_issue_limit_test` | 超过 M_ISSUE=4 被阻塞 |
| `axicb_accept_limit_test` | 超过 S_ACCEPT=16 被阻塞 |
| `axicb_thread_dest_lock_test` | 同 ID 不同目的地被阻塞 |
| `axicb_ooo_response_test` | 不同 ID 乱序返回 |

### C.5 Reset / Recovery

| Testcase | 设计思路 |
|---|---|
| `axicb_reset_idle_test` | idle 时 reset |
| `axicb_reset_mid_write_test` | W 传输中 reset |
| `axicb_reset_mid_read_test` | R 传输中 reset |
| `axicb_post_reset_recovery_test` | reset 后立即发事务 |

### C.6 Backpressure

| Testcase | 设计思路 |
|---|---|
| `axicb_backpressure_aw_test` | slave 端延迟 awready |
| `axicb_backpressure_w_test` | slave 端延迟 wready |
| `axicb_backpressure_r_test` | master 端延迟 rready |

前置: VIP slave responder 需增加可配延迟旋钮

### C.7 Random Regression / Coverage Closure

| Testcase | 设计思路 |
|---|---|
| `axicb_random_basic_test` | 单 master 全随机参数 |
| `axicb_random_contention_test` | 双 master 随机竞争 |
| `axicb_random_full_feature_test` | 全维度随机 + backpressure + reset |

退出条件: Functional coverage ≥ 95%, Code coverage ≥ 90% (or waiver), 1000+ seeds 稳定

### C.8 长期 Roadmap（不进入近期执行）

| 类别 | 项目 |
|---|---|
| Pipeline register 全矩阵 | 改变 `*_REG_TYPE` 参数组合 (bypass/simple/skid) 进行参数化回归 |
| USER 信号透传 | 设置 `*USER_ENABLE=1`，验证 awuser/wuser/buser/aruser/ruser 端到端一致 |
| Protocol checker / SVA | 绑定 handshake stability / arbiter grant onehot / trans_count range / DECERR completeness 等断言 |
| Stress / performance | 大流量长时间运行，测量吞吐和延迟 |
| M_SECURE 安全过滤 | 设置 `M_SECURE=1`，验证基于 prot[1] 的访问过滤 |
| M_CONNECT 连接矩阵 | 设置非全连接配置，验证被禁止的路径返回 DECERR |

---

## 一、验证特性提取 (Feature Extraction)

### 1.1 DUT 参数实例化摘要

| 参数 | 值 | 含义 |
|---|---|---|
| `S_COUNT` | 2 | 上游 Slave 接口数量（连接 2 个 AXI Master） |
| `M_COUNT` | 2 | 下游 Master 接口数量（连接 2 个 AXI Slave） |
| `DATA_WIDTH` | 32 | 数据总线宽度 |
| `ADDR_WIDTH` | 32 | 地址总线宽度 |
| `S_ID_WIDTH` | 8 | 上游 ID 位宽 |
| `M_ID_WIDTH` | 9 | 下游 ID 位宽（= S_ID_WIDTH + $clog2(S_COUNT)） |
| `M00_BASE_ADDR` | `32'h0000_0000` | Slave0 基地址 |
| `M00_ADDR_WIDTH` | 16 | Slave0 地址空间 64KB (`0x0000_0000 ~ 0x0000_FFFF`) |
| `M01_BASE_ADDR` | `32'h0001_0000` | Slave1 基地址 |
| `M01_ADDR_WIDTH` | 16 | Slave1 地址空间 64KB (`0x0001_0000 ~ 0x0001_FFFF`) |
| `S00_THREADS` / `S01_THREADS` | 2 | 每个 Slave 接口同时跟踪的唯一 ID 数 |
| `S00_ACCEPT` / `S01_ACCEPT` | 16 | 每个 Slave 接口可接受的并发操作数 |
| `M00_ISSUE` / `M01_ISSUE` | 4 | 每个 Master 接口可发出的并发操作数 |
| `M00_CONNECT_READ/WRITE` | `2'b11` | 全连接 |
| `M00_SECURE` / `M01_SECURE` | 0 | 不启用安全保护 |

### 1.2 Pipeline Register 配置

| 通道 | S-side (输入侧) | M-side (输出侧) |
|---|---|---|
| AW | 0 (bypass) | 1 (simple buffer) |
| W | 0 (bypass) | 2 (skid buffer) |
| B | 1 (simple buffer) | 0 (bypass) |
| AR | 0 (bypass) | 1 (simple buffer) |
| R | 2 (skid buffer) | 0 (bypass) |

### 1.3 协议特性（AXI4 Protocol Features）

| 编号 | 特性 | 描述 | RTL 对应 |
|---|---|---|---|
| F-P01 | Burst 类型 | FIXED / INCR / WRAP 透传 | Crossbar 透传 `awburst`/`arburst`，不做 burst 转换 |
| F-P02 | Burst 长度 | `awlen`/`arlen` (0~255) 透传 | 不做 burst 分割/合并 |
| F-P03 | Burst 大小 | `awsize`/`arsize` (1/2/4B) 透传 | 支持 narrow transfer |
| F-P04 | WSTRB | 4-bit 写字节使能透传 | 支持 partial strobe |
| F-P05 | WLAST | 写突发末拍标记 | W 通道路由依赖 `wlast` 释放选路 |
| F-P06 | RLAST | 读突发末拍标记 | R 响应仲裁在 `rlast && rready` 时释放 grant |
| F-P07 | BRESP / RRESP | 2-bit 响应码 | crossbar 自身生成 DECERR(2'b11)；下游 slave 响应透传 |
| F-P08 | LOCK | Exclusive access 透传 | crossbar 不做 exclusive monitor |
| F-P09 | CACHE | 4-bit cache 属性透传 | — |
| F-P10 | PROT | 3-bit protection | `M_SECURE=0` 时不检查 |
| F-P11 | QOS | 4-bit QoS 透传 | 不参与仲裁 |
| F-P12 | REGION | 4-bit region | 由 `axi_crossbar_addr` 根据地址匹配生成 |
| F-P13 | USER 信号 | AWUSER/WUSER/BUSER/ARUSER/RUSER | `*USER_ENABLE=0`，物理透传 1-bit |

### 1.4 Crossbar 微架构特性（Micro-architectural Features）

| 编号 | 特性 | 描述 | RTL 对应 |
|---|---|---|---|
| F-M01 | 读写物理分离 | `axi_crossbar_rd` 与 `axi_crossbar_wr` 完全独立 | `axi_crossbar.v` 顶层 |
| F-M02 | 地址译码 | 按 `M_BASE_ADDR` + `M_ADDR_WIDTH` 区间匹配 | `axi_crossbar_addr.v` STATE_IDLE for 循环 |
| F-M03 | DECERR 生成 | 地址不匹配时生成 DECERR 并内部消费 W 数据 | `_addr.v` match=0; `_wr.v` w_drop_reg; `_rd.v` decerr_len_reg |
| F-M04 | ID 位宽扩展 | downstream ID = {source_port, upstream_ID} | `_wr.v`/`_rd.v` m_ifaces: `a_grant_encoded << S_ID_WIDTH` |
| F-M05 | ID 还原与响应路由 | 响应 ID MSB 提取源端口号 | `_wr.v`/`_rd.v` m_ifaces B/R 转发 |
| F-M06 | Thread Tracking | 同 ID 必须路由到同 destination | `_addr.v` thread_id_reg/thread_m_reg/thread_count_reg |
| F-M07 | Thread 限制 | `S_THREADS=2`：最多 2 个活跃 ID | `_addr.v` S_INT_THREADS, thread_active |
| F-M08 | Accept 限制 | `S_ACCEPT=16`：最多 16 并发 | `_addr.v` trans_count_reg, trans_limit |
| F-M09 | Issue 限制 | `M_ISSUE=4`：每 master 端口最多 4 并发 | `_wr.v`/`_rd.v` m_ifaces trans_count_reg |
| F-M10 | 地址仲裁 | Round-robin, ARB_BLOCK=1, ARB_BLOCK_ACK=1, LSB_HIGH_PRIORITY=1 | `_wr.v`/`_rd.v` m_ifaces a_arb_inst |
| F-M11 | 响应仲裁 | Round-robin, 端口数 = M_COUNT+1（含 DECERR 虚端口） | `_wr.v` b_arb_inst; `_rd.v` r_arb_inst |
| F-M12 | W 通道路由 | AW 先解码，wc 输出驱动 W mux；`wlast` 释放通道 | `_wr.v` s_ifaces w_select_reg/w_drop_reg |
| F-M13 | Pipeline Register | 每通道 bypass(0)/simple(1)/skid(2) | `axi_register_rd.v`, `axi_register_wr.v` |
| F-M14 | 非阻塞并行 | 访问不同 slave 时互不阻塞 | 独立 arbiter/mux |

---

## 二、测试用例矩阵 (Testcase Matrix)

> 仅列出全量计划。当前已完成标记 ✅，B 阶段执行标记 🔜，后续 roadmap 标记 📋。

### 2.1 基础路由测试 (Basic Routing)

| # | Testcase | 状态 | 设计思路 | 期望结果 |
|---|---|---|---|---|
| T-R01 | `axicb_smoke_test` | ✅ | 4 路径 single-beat write-read + boundary addr | 数据正确，BRESP/RRESP=OKAY |
| T-R02 | `axicb_decode_full_range_test` | 🔜 N-07 | 遍历 slave0/slave1 各 {起始,中间,末尾} 地址 write-read | 译码正确 |
| T-R03 | `axicb_decode_cross_boundary_test` | 🔜 N-08 | slave0 末尾 + slave1 起始连续发 | 路由无混淆 |
| T-R04 | `axicb_id_nonzero_test` | 🔜 N-10 | 两 master 用同一非零 ID | upstream ID 正确还原 |
| T-R05 | `axicb_id_boundary_test` | 🔜 N-11 | ID=0x00 和 ID=0xFF | 扩展/还原正确 |
| T-R06 | `axicb_response_route_test` | 🔜 N-12 | 双 master 并行，检查 response 不混淆 | 各 master 收到自己的 response |
| T-R07 | `axicb_same_id_diff_master_test` | 🔜 N-13 | m0,m1 用相同 ID 同时访问 | downstream 9-bit ID 不同 |

### 2.2 DECERR 异常路径

| # | Testcase | 状态 | 设计思路 | 期望结果 |
|---|---|---|---|---|
| T-D01 | `axicb_decerr_write_test` | 🔜 N-01 | 非法地址单拍 write | BRESP=DECERR |
| T-D02 | `axicb_decerr_read_test` | 🔜 N-02 | 非法地址单拍 read | RRESP=DECERR |
| T-D03 | `axicb_decerr_burst_write_test` | 🔜 N-03 | 非法地址多拍 write + 后续合法 | W 被 drop，后续正常 |
| T-D04 | `axicb_decerr_burst_read_test` | 🔜 N-04 | 非法地址多拍 read | (len+1) 拍 DECERR |
| T-D05 | `axicb_decerr_then_legal_test` | 🔜 N-05 | 非法后合法 | 状态恢复正常 |
| T-D06 | `axicb_decerr_both_masters_test` | 🔜 N-06 | 双 master 非法 | 各自 DECERR |

### 2.3 Outstanding / OOO

| # | Testcase | 状态 | 设计思路 | 期望结果 |
|---|---|---|---|---|
| T-O01 | `axicb_outstanding_basic_test` | 🔜 N-14 | pipeline 4 笔 write | 全部完成 |
| T-O02 | `axicb_outstanding_read_test` | 🔜 N-15 | pipeline 4 笔 read | 数据正确 |
| T-O03 | `axicb_two_id_ordering_test` | 🔜 N-16 | 2 ID 各 2 笔 | 同 ID 保序 |
| T-O04 | `axicb_thread_limit_basic_test` | 🔜 N-17 | 3 ID > S_THREADS=2 | 第 3 ID 阻塞 |

### 2.4 Burst 功能（后续 C.1）

| # | Testcase | 状态 | 设计思路 |
|---|---|---|---|
| T-B01 | `axicb_incr_burst_test` | 📋 | INCR 多种 len |
| T-B02 | `axicb_fixed_burst_test` | 📋 | FIXED 多种 len |
| T-B03 | `axicb_wrap_burst_test` | 📋 | WRAP (2/4/8/16) |
| T-B04 | `axicb_max_burst_test` | 📋 | len=255 |

### 2.5 Narrow / Strobe / Unaligned（后续 C.2）

| # | Testcase | 状态 | 设计思路 |
|---|---|---|---|
| T-N01 | `axicb_narrow_transfer_test` | 📋 | 1B/2B narrow |
| T-N02 | `axicb_partial_strobe_test` | 📋 | 随机 WSTRB |
| T-N03 | `axicb_unaligned_test` | 📋 | 非对齐 INCR |

### 2.6 并发与仲裁（后续 C.3）

| # | Testcase | 状态 | 设计思路 |
|---|---|---|---|
| T-C01 | `axicb_parallel_diff_slave_test` | 📋 | 非阻塞并行 |
| T-C02 | `axicb_same_slave_write_test` | 📋 | 双 master 竞争写 |
| T-C03 | `axicb_same_slave_mixed_test` | 📋 | 一写一读同 slave |
| T-C04 | `axicb_arb_fairness_test` | 📋 | round-robin 统计 |

### 2.7 Reset / Backpressure / Random（后续 C.4~C.7）

| # | Testcase | 状态 |
|---|---|---|
| T-RST01~05 | Reset 系列 | 📋 |
| T-BP01~03 | Backpressure 系列 | 📋 |
| T-RND01~03 | Random 回归系列 | 📋 |

---

## 三、覆盖率收集计划 (Coverage Plan)

### 3.1 功能覆盖率 (Functional Coverage)

#### CG1: 路由覆盖 (`cg_routing`) — 🔜 B 阶段新增

| Coverpoint | Bins |
|---|---|
| `cp_src_master` | {m0, m1} |
| `cp_dst_slave` | {s0, s1} |
| `cp_txn_type` | {WRITE, READ} |
| **Cross: `cx_routing`** | **2×2×2 = 8 bins** |

> 需要 monitor 中增加 master_port_id 字段或从地址推断 slave 索引。

#### CG2: Burst 参数覆盖 (`cg_burst`) — ✅ 已有，需补 WRAP

当前已有 BURST_TYPE(FIXED/INCR) × LEN × SIZE。B 阶段补入 `WRAP` bin。

#### CG3: Response 覆盖 (`cg_response`) — 🔜 B 阶段新增

| Coverpoint | Bins |
|---|---|
| `cp_bresp` | {OKAY, DECERR} |
| `cp_rresp` | {OKAY, DECERR} |

> DECERR 测试完成后此 covergroup 才能命中 DECERR bins。

#### CG4: ID 覆盖 (`cg_id`) — 📋 后续

| Coverpoint | Bins |
|---|---|
| `cp_upstream_id` | {8'h00, [8'h01:8'hFE], 8'hFF} |
| `cp_src_master` | {m0, m1} |

#### CG5~CG8 — 📋 后续

并发覆盖、Outstanding 深度、WSTRB 模式、地址对齐 — 随对应 test 阶段加入。

### 3.2 断言覆盖率 (SVA) — 📋 后续 Roadmap

| SVA | 绑定位置 | 描述 |
|---|---|---|
| SVA-1 | 所有 valid/ready 对 | `valid && !ready |=> valid` |
| SVA-2 | arbiter grant | `grant_valid \|-> $onehot(grant)` |
| SVA-3 | m_ifaces trans_count_reg | `trans_count >= 0 && trans_count <= M_ISSUE` |
| SVA-4 | DECERR 读响应 | `rc_valid && rc_ready \|-> ##[1:$] (rlast && rresp==DECERR)` |
| SVA-5 | Thread tracking | `trans_start && \|thread_match \|-> \|thread_match_dest` |

> SVA 开发作为 C.8 长期 roadmap，不进入 B 阶段。

---

## 四、记分板设计建议 (Scoreboard Architecture)

### 4.1 当前实现 (Layer 1 — Data Integrity)

```
axicb_scoreboard (uvm_subscriber#(axi_transaction))
  ├── ref_mem: bit[31:0] associative array [bit[31:0]]
  ├── process_write(): burst addr calc → wstrb merge → ref_mem store
  ├── process_read():  burst addr calc → ref_mem lookup → compare
  ├── calculate_beat_addr(): INCR ✅ / FIXED ✅ / WRAP ❌
  └── report_phase(): check_count / error_count
```

**数据流**: 仅 upstream monitor (mst_agent00/01) → scb。downstream monitor 不喂入 scb。

### 4.2 B 阶段改进

| 改进 | 说明 |
|---|---|
| DECERR 过滤 | `write()` 中检查 `bresp`/`rresp[0]`，DECERR 事务跳过 ref_mem 操作，仅计 check_count |
| WRAP 地址计算 | 补充 `calculate_beat_addr` WRAP 分支 |

### 4.3 未来 Layer 2: Route & ID Checker

**设计目标**: 验证 crossbar 路由正确性（地址译码 → downstream 端口选择 → ID 扩展 → response 回路由 → ID 还原）。

**架构**:
- Upstream monitor 捕获请求 → 预测目标 slave + 扩展 ID → 存入 expect queue
- Downstream monitor 捕获请求 → 与 expect queue 匹配
- 验证: downstream port 正确、`m_axi_id[8]` == source master、`m_axi_id[7:0]` == upstream ID

**时机**: B 阶段不实现完整 Layer 2。在 N-10~N-13 中通过 **sequence 层显式检查** (读回 ID 比对) 代替。完整 Layer 2 在 C.3 并发阶段前开发。

---

## 五、当前直接行动清单

按优先级执行：

```
1. [S-01] Scoreboard DECERR 过滤
2. [S-05] VIP expect_decerr 开关
3. [N-01~N-06] DECERR directed tests
4. [S-04] Element sequence 暴露 tr_id
5. [N-07~N-09] Address decode tests
6. [N-10~N-13] Response routing / ID tests
7. [N-14~N-17] Basic outstanding / OOO tests
8. [S-02] Scoreboard WRAP 地址计算
9. [S-03] Coverage cg_comprehensive 激活 + cg_response 新增
```
