# AXI4 2x2 Non-blocking Crossbar 验证计划

## vPlan_54xhigh_v1

> DUT: `axi_crossbar_wrap_2x2`
> 
> 验证方法学: UVM 1.2
> 
> 当前平台状态: 已具备 smoke、DECERR、decode 三类基础能力；element sequence 已支持 `master 选择 + addr/len/size/burst/id + expect_decerr + wait_for_response + per-beat wstrb`；env 已具备双 master agent、双 slave agent、scoreboard、coverage、virtual sequencer。
> 
> 本计划目标: 用少量高价值 vseq family 覆盖当前平台真正可落地的关键风险点，把“单点拆碎”的测试组织方式收敛为“能力簇驱动”的验证组织方式。

## 计划原则

1. 一个 vseq family 必须覆盖一个完整能力簇，而不是只覆盖一个零散测试点。
2. 只有当前 testbench 能驱动、能观测、能判错的特性才进入 v1 signoff 主范围。
3. 每完成一类 vseq family，就同步补齐该类场景真正需要的 coverage 和 scoreboard 能力，不提前铺摊子。
4. 不再为单个微小场景单独派生一个 vseq；推荐在一个 family 内部用 scenario enum、task 列表或 case 表驱动多个子场景。
5. WRAP、reset/backpressure 这类当前平台尚不具备闭环判定能力的特性，必须明确列为 gated scope，而不是混入主回归后把计划做虚。

## 命名约定

本文统一采用验证视角命名：

- 上游 master: m0 / m1，对应 DUT 的 `s00/s01` 接口
- 下游 slave: s0 / s1，对应 DUT 的 `m00/m01` 接口

---

## 一、验证特性提取

### 1.1 DUT 关键可验证特性

| 类别 | DUT 事实 | RTL 侧关键依据 | 当前 TB 是否有抓手 | v1 策略 |
|---|---|---|---|---|
| 基础路由 | 2x2 全互连，4 条合法路径均存在 | wrapper 参数 `M00/M01_CONNECT_READ/WRITE = 2'b11` | 有，`axicb_smoke_vseq` 已跑通 | 纳入主范围 |
| 地址解码 | 合法空间仅有 `0x0000_0000~0x0000_FFFF` 和 `0x0001_0000~0x0001_FFFF` | `axi_crossbar_addr` 以 base/width 比较做 decode | 有，已有 decode/decerr 场景和 downstream VIF 观察点 | 纳入主范围 |
| 读写物理分离 | `axi_crossbar_rd` 与 `axi_crossbar_wr` 独立 | 读写路径独立实例化 | 有，双 master/diff slave 并发可直接构造 | 纳入主范围 |
| ID 扩展与还原 | 上游 8-bit ID 在下游扩成 9-bit，最高位表示源 master；返回时还原为上游 ID | `decode_base_vseq` 已按 `{master_idx, upstream_id}` 检查下游 ID；RTL 用返回 ID 路由 | 有，当前 element seq 和 downstream VIF 都支持 | 纳入主范围 |
| DECERR 写路径 | 非法地址写不会向下游发真实写，W 通道会被 `w_drop_reg` 吞掉，且 `BRESP` 要等到 `WLAST` 被接收后才返回 | `axi_crossbar_wr` 中 `w_drop_reg`、`decerr_m_axi_pending_reg`、`decerr_wlast_accept` | 有，当前 decerr 基类已能监视泄漏和响应 | 纳入主范围 |
| DECERR 读路径 | 非法地址读由 `decerr_len_reg` 生成 `len+1` 拍 `RRESP=DECERR`，最后一拍 `RLAST=1` | `axi_crossbar_rd` 中 `decerr_len_reg` 和 DECERR 虚端口仲裁 | 有，当前 decerr 基类已支持 beat 级检查 | 纳入主范围 |
| Thread 保序保护 | 同一 ID 只能保持到同一目标；`S_THREADS=2`，每个上游口最多同时保持 2 个活跃唯一 ID | `axi_crossbar_addr` 的 `thread_match_dest || (!(&thread_active) && !thread_match)` 准入条件 | 部分有，当前没有统一 family，但已有 ID 可控、wait_for_response 可控、downstream VIF 可见 | 纳入主范围 |
| Outstanding 限制 | 上游 accept 限制 `S_ACCEPT=16`，下游 issue 限制 `M_ISSUE=4` | `axi_crossbar_addr` / `axi_crossbar_rd` / `axi_crossbar_wr` 中 `trans_count_reg` | 部分有，`wait_for_response=0` 已支持非阻塞；但还没有专门 family | 纳入主范围 |
| 同 slave 仲裁 | 共享同一目标 slave 时由 round-robin arbiter 仲裁，`ARB_BLOCK=1`，`ARB_BLOCK_ACK=1` | 读写通道中的 arbiter 实例 | 有，双 master 同目标可直接构造 | 纳入主范围 |
| FIXED / INCR / 窄传输 / 非对齐 / 部分 WSTRB | DUT 做路由透传，scoreboard 已支持 FIXED/INCR 地址计算和 byte merge | 当前 scoreboard 的 `calculate_beat_addr` 支持 FIXED/INCR，`merge_data_with_strb` 支持 byte merge | 有，现有 element seq 能逐 beat 指定 `wstrb` 和 data | 纳入主范围 |
| WRAP | DUT 本身支持透传，但当前 `axi_slave_mem` 和 scoreboard 都没有完整 WRAP 地址模型 | 现有 RAM sequence 也未接入 crossbar regression | 没有闭环判错能力 | 明确 gated，不进入 v1 signoff |
| Reset / backpressure | DUT 有 reset，且 pipeline register 行为受 ready/valid 影响 | 当前 VIP/scoreboard 缺少系统化 delay knob 和 reset hook | 没有完整闭环 | 明确 gated，不进入 v1 signoff |

### 1.2 当前 testbench 已具备的直接驱动力

| 能力 | 当前代码现状 | 对新计划的意义 |
|---|---|---|
| `src_master_idx` 可控 | 现有单事务序列已可选 m0 / m1 | 所有 family 都能在一个 vseq 内并行组织双 master 子场景 |
| `addr/len/size/burst` 可控 | 当前 element seq 已完整暴露 | 不需要为基础 burst 场景再派生大量小序列 |
| `awid/arid` 可控 | 当前 element seq 已暴露上游 ID | ID family、thread family、ordering family 都可直接搭建 |
| `expect_decerr` 可控 | VIP 已允许“预期的 DECERR 不报错” | DECERR family 可以统一收敛到一个大 vseq |
| `wait_for_response` 可控 | VIP 已支持 blocking / non-blocking | outstanding、非阻塞、仲裁 family 可直接设计 |
| `every_beat_data/wstrb` 可控 | element seq 已支持动态数组逐 beat 驱动 | burst/byte-enable family 可直接实现 |
| downstream VIF 可见 | base vseq 已拿到两个下游 VIF | decode/ID/DECERR 泄漏检查不必依赖额外 monitor 改造 |

### 1.3 v1 signoff 范围与暂缓范围

#### v1 主范围

- 4 路基础路由
- decode 边界与 ID 扩展/还原
- DECERR 生成、隔离、恢复
- 非阻塞并发、同目标仲裁、issue/thread 限制
- FIXED / INCR / narrow / unaligned / partial strobe

#### v1 暂缓范围

- WRAP burst
- reset 中断恢复
- 可控 backpressure 与 skid/simple buffer 定量验证
- `M_SECURE`、部分连接矩阵、USER/QOS/REGION 非默认配置

原则很简单：暂缓不是放弃，而是不把当前平台还不能判死错的东西假装写进 signoff。

---

## 二、测试用例矩阵

本计划不再使用“一个微小点一个 vseq”的方式。回归主集只保留 5 个主动 test family，每个 family 内部打包多个互相关联的子场景。test 层仍可保留当前“一 test 启一个 vseq”的骨架，但不再为每个小点再加新文件。

### 2.1 主回归 family

| Family / 建议 test 名 | 复用基础 | family 内部应打包的子场景 | 核心检查点 | 同步需要补的 TB 能力 | 退出标准 |
|---|---|---|---|---|---|
| `axicb_smoke_vseq` / `axicb_smoke_test` | 直接沿用现有 smoke | 1. 四条路径 m0->s0, m0->s1, m1->s0, m1->s1；2. 每条路径至少包含基址或边界点；3. 每条路径加入少量随机 aligned 地址 spot-check | `BRESP/RRESP=OKAY`；scoreboard 数据一致；4 条路由都被命中 | 只需清理 coverage 采样，不需结构性改动 | 作为入门门禁，必须稳定通过且路由 coverage 8 个 active bin 全命中 |
| `axicb_decode_id_vseq` / `axicb_decode_id_test` | 以现有 `axicb_decode_full_range_vseq` 为核心重组 | 1. s0/s1 的 base/mid/end 地址 decode；2. 上游 ID 取极值 `0x00/0xFF` 和代表值；3. 两个 master 使用相同 upstream ID 访问同/不同 slave；4. 下游 9-bit ID 检查与上游返回 ID 检查 | 地址进入正确 slave；下游 ID 为 `{src_master, upstream_id}`；上游 `bid/rid` 必须与发起 ID 一致；decode 边界无串口 | 在 scoreboard 内加入 `bid==awid`、`rid==arid` 检查；coverage 增加 ID bucket | decode 与 ID 不分家，作为一个 family 一次打透；不再拆成 full_range / nonzero / extreme / same-id 多个 vseq |
| `axicb_decerr_isolation_vseq` / `axicb_decerr_isolation_test` | 合并现有 `decerr_single`、`decerr_burst`、`decerr_id`、`decerr_dual_mst` | 1. 单拍非法写/读；2. 多拍非法写/读，长度覆盖 1/4/8 beats；3. 下游零泄漏检查；4. DECERR 后同 ID 合法事务恢复；5. 双 master 并行 illegal+illegal、illegal+legal；6. 读通道检查 `len+1` 拍 DECERR，写通道检查 `BRESP` 只在 `WLAST` 后返回 | 非法事务不泄漏到任何下游 slave；写返回 `DECERR` 且不提前；读返回拍数准确；恢复后合法事务 OK；并行场景互不污染 | scoreboard 增加 `decerr_count` 与 DECERR 过滤；coverage 增加 legality x resp x type | 这是 crossbar 最具辨识度的 family，必须用一个大 family 统一收敛，不再拆 4 个以上派生 vseq |
| `axicb_concurrency_control_vseq` / `axicb_concurrency_control_test` | 新增 family，但完全基于现有 `wait_for_response=0`、ID 可控、downstream VIF 可见能力 | 1. m0->s0 与 m1->s1 并行，验证非阻塞；2. m0/m1 同时打 s0，验证同目标竞争可完成；3. 单 master 对单 slave 打满 `M_ISSUE=4`；4. 同一上游口连续送 3 个不同 ID，观察 `S_THREADS=2` 下第 3 个 ID 受阻；5. 同一 ID 先去 s0，再立刻去 s1，验证 destination lock | 无死锁；双 master diff-slave 场景应同时推进；same-slave 场景所有事务完成且数据不串；outstanding 深度至少观察到 4；同 ID 不可跨目标并行放行 | 增加 timeout/进度辅助检查；coverage 增加 concurrency / outstanding / thread_blocked；必要时从 slave monitor 再接一条 analysis path 做 route check | 该 family 是主范围中唯一负责“非阻塞 + 仲裁 + 限制”整体闭环的 family，不能再拆碎 |
| `axicb_burst_byteen_vseq` / `axicb_burst_byteen_test` | 参考现有 RAM 序列思路，但在 crossbar TB 内重写为统一 family | 1. FIXED burst，检查最后写覆盖；2. INCR narrow 1B/2B，覆盖 lane 内和跨 word；3. unaligned INCR，起始地址取 `+1/+2/+3`；4. partial `WSTRB` 随机更新；5. 单 master / 双 path 小规模混合 | scoreboard 对 FIXED/INCR/byte merge 必须稳定；所有子场景最终读回正确；不同 slave 的数据互不污染 | coverage 增加 `size x alignment x wstrb_class`；若发现地址模型边界问题，优先修正 scoreboard 而不是继续加新 case | v1 只做到 FIXED/INCR；WRAP 不混入本 family |

### 2.2 暂缓 family

| Family / 建议 test 名 | 暂缓原因 | 准入条件 | 准入后验证重点 |
|---|---|---|---|
| `axicb_wrap_vseq` / `axicb_wrap_test` | 当前 `axi_slave_mem` 与 scoreboard 都没有 WRAP 完整地址模型，coverage 中 WRAP bin 现在属于伪目标 | 同时补齐 slave_mem 与 scoreboard 的 WRAP 地址计算，并完成一轮 directed 自检 | WRAP 2/4/8/16 beats，含不同起始 offset；同时验证 route、data 和 byte lane |
| `axicb_reset_backpressure_vseq` / `axicb_reset_backpressure_test` | 当前 VIP 无系统化 ready/valid delay knob，scoreboard 无 reset flush hook | 增加 responder/driver delay 控件、scoreboard reset 清空、partial transaction 过滤 | skid/simple buffer、mid-transaction reset、post-reset recovery |

### 2.3 推荐回归组织方式

#### 每个 family 内部都按“场景包”组织

推荐组织形式：

- `scenario_e scenarios[] = '{...};`
- `foreach (scenarios[i]) run_one_scenario(scenarios[i]);`
- 每个 `run_one_scenario()` 内部可复用已有 `do_legal_write/read()`、`do_decerr_write/read()` 或新建少量 helper

这样可以保留现有 test skeleton 的简洁性，同时把验证粒度提升到“能力簇”，避免 test/vseq 文件爆炸。

---

## 三、覆盖率收集计划

覆盖率规划不再先铺一大张表再找用例去填，而是和 family 同步增长。active scope 的 coverage 目标应是“所有 active bin 关闭”，而不是把当前无法执行的 WRAP/reset bin 也混在 signoff 指标里。

### 3.1 与 family 同步的 coverage / checker 增量

| Family | 需要同步补齐的 coverage / checker | 说明 |
|---|---|---|
| Smoke Route | `route_basic` | `src_master x dst_slave x txn_type`，作为所有后续 family 的地基 |
| Decode ID | `id_bucket`、`decode_class`、scoreboard `bid/rid` 一致性检查 | ID 与 decode 必须一起关，避免只测数据不测 route |
| DECERR Isolation | `resp_legality`、`decerr_len_bucket`、`decerr_count` | 把 DECERR 从“日志观察”升级到可统计、可收敛 |
| Concurrency Control | `concurrency_mode`、`outstanding_depth`、`thread_blocked` | 这类覆盖点不需要大而全，但必须能证明关键限制被真正触发 |
| Burst Byteen | `size_alignment`、`wstrb_class`、`burst_type_v1` | v1 的 `burst_type` 只统计 FIXED/INCR，WRAP bin 单独冻结 |

### 3.2 功能覆盖点设计

| Covergroup | 采样源 | 关键 coverpoint / cross | v1 目标 |
|---|---|---|---|
| `cg_route_basic` | upstream monitor | `src_master x dst_slave x txn_type` | 8 个 active bin 全中 |
| `cg_decode_id` | upstream monitor + family 内部 checker 或 route checker | `decode_class(base/mid/end/illegal) x id_bucket(0x00/mid/0xFF) x src_master` | 所有 active bin 全中 |
| `cg_resp_legality` | upstream monitor | `txn_type x legal_or_illegal x resp_type(OKAY/DECERR)` | 所有 active bin 全中 |
| `cg_concurrency` | scoreboard / family tracker | `mode(single/dual_diff_slave/dual_same_slave) x rw_mix(WW/RR/WR)` | 关键模式全中 |
| `cg_outstanding` | lightweight tracker | `src_master x outstanding_depth(1/2/3/4)` | 至少命中到 depth=4 |
| `cg_thread_guard` | family tracker 或 checker | `same_id_same_dest`、`same_id_diff_dest_blocked`、`third_unique_id_blocked` | 三类事件都要命中 |
| `cg_burst_v1` | upstream monitor | `burst_type(FIXED/INCR) x len_bucket x size_bucket` | active bin 全中 |
| `cg_size_alignment` | upstream monitor | `size(1B/2B/4B) x alignment(aligned/+1/+2/+3)` | active bin 全中 |
| `cg_wstrb_class` | upstream monitor per beat | `all_ones / single_lane / half_word / sparse` | active bin 全中 |

### 3.3 覆盖率执行规则

1. v1 不把 WRAP bin 计入 signoff 指标。
2. v1 不把 reset/backpressure bin 计入 signoff 指标。
3. 当前 `axicb_coverage` 中已存在但当前平台无法收敛的 bin，必须拆分成 active scope 与 gated scope，不能继续混用。
4. coverage 的主目标不是“数量多”，而是“能证明 5 个 family 真的触发过关键硬件限制”。

### 3.4 断言覆盖率计划

建议优先绑定以下 5 条系统级 SVA：

| SVA | 绑定位置 | 断言目的 | 价值 |
|---|---|---|---|
| `arb_grant_onehot` | `axi_crossbar_rd` / `axi_crossbar_wr` 内各 arbiter 周边 | `grant_valid -> $onehot(grant)` | 防止仲裁器输出非法多授权 |
| `w_route_lock_until_last` | `axi_crossbar_wr` 的 `w_select_valid_reg` 周边 | 一旦 W 路由被锁定，直到 `WLAST` 被接受前不得释放或切换 | 直接验证写通道路由原子性 |
| `thread_dest_lock` | `axi_crossbar_addr` | 若 `thread_match` 但 `!thread_match_dest`，则本拍不得 `trans_start` | 直接验证同 ID 不可跨目标并发放行 |
| `decerr_read_completeness` | `axi_crossbar_rd` 的 `decerr_len_reg` / `decerr_m_axi_rvalid_reg` 周边 | DECERR 读必须持续输出 `len+1` 拍，且仅最后一拍 `RLAST=1` | 直接绑定读 DECERR 核心行为 |
| `trans_count_in_range` | `axi_crossbar_addr`、`axi_crossbar_rd`、`axi_crossbar_wr` 的 `trans_count_reg` 周边 | outstanding 计数器不得越界，且 reset 后归零 | 直接约束 issue/accept 逻辑 |

这些断言的意义不是替代 directed 测试，而是把 family 难以外部直接观察的内部约束变成可回归的硬约束。

---

## 四、记分板设计建议

这颗 2x2 crossbar 的难点不在“内存模型很复杂”，而在“路由预测、ID 扩展、并发限制、数据一致性”是四类不同问题。最不推荐的做法，是把所有东西都塞进一个越来越臃肿的单体 scoreboard。

### 4.1 推荐的分层结构

建议拆成 3 层：

| 层次 | 组件职责 | 是否属于 v1 主范围 |
|---|---|---|
| Layer A: Data Scoreboard | 维护 `ref_mem`，处理 FIXED/INCR、narrow、unaligned、partial `WSTRB`，完成数据比对和 `resp` 基础检查 | 是 |
| Layer B: Route / ID Checker | 在命令级预测目标 slave 和下游扩展 ID，并在下游观察点做 route/id 比对 | 是 |
| Layer C: Concurrency Tracker | 跟踪 `outstanding_depth`、同 ID destination lock、thread block 事件、issue 深度命中 | 是 |

这种分层有两个优点：

- 不会把“数据内存模型”和“路由/仲裁逻辑”硬塞在一起。
- coverage 可以直接从对应层取样，结构更清晰。

### 4.2 推荐的数据结构

推荐核心数据结构如下：

```systemverilog
typedef struct {
  trans_type_enum              kind;
  int unsigned                 src_master;
  int unsigned                 dst_slave;
  bit                          illegal;
  bit [7:0]                    upstream_id;
  bit [8:0]                    expected_downstream_id;
  bit [31:0]                   addr;
  burst_len_enum               burst_len;
  burst_size_enum              burst_size;
  burst_type_enum              burst_type;
} cmd_desc_t;

typedef struct {
  int unsigned                 dst_slave;
  int unsigned                 active_count;
} thread_state_t;

bit [31:0] ref_mem[bit [31:0]];
cmd_desc_t pending_route_q[2][$];
cmd_desc_t inflight_by_id[2][bit [7:0]][$];
thread_state_t thread_state[2][bit [7:0]];
int unsigned outstanding_depth[2];
int unsigned decerr_count;
```

### 4.3 建议的工作流

#### Layer A: Data Scoreboard

- 输入: 上游 monitor 的完整事务
- 行为:
  - legal write: 更新 `ref_mem`
  - legal read: 从 `ref_mem` 比对
  - illegal write/read: 只做 `resp` 检查并累加 `decerr_count`
  - 同时检查 `bid==awid`、`rid==arid`

#### Layer B: Route / ID Checker

- 输入: 上游命令观察点 + 下游命令观察点
- 行为:
  - 上游 AW/AR 到来时，预测 `dst_slave` 与 `expected_downstream_id`
  - 推入 `pending_route_q[src_master]`
  - 下游 AW/AR 被观察到时，按预测项比对 `slave` 和 9-bit ID

说明：

- 当前 base vseq 已能直接观察 downstream VIF，因此 family 早期可以先用 directed checker 完成 route/id 验证。
- 若后续要让 route/id 也进入统一 scoreboard 统计，则 env 只需再把 slave monitor 的 analysis port 接给 checker，属于低风险增量。

#### Layer C: Concurrency Tracker

- 输入: 命令起始事件 + 响应完成事件
- 行为:
  - 维护 `outstanding_depth[src_master]`
  - 维护 `thread_state[src_master][id]`
  - 当同 ID 目标切换被阻塞时，命中 `thread_blocked`
  - 当 outstanding 深度达到 4 时，命中 `issue_depth=4`

### 4.4 为什么这套结构适合当前项目

原因不是抽象层次“看起来高级”，而是它正好对齐当前平台的真实能力边界：

1. 数据比对当前已经可做，应该继续保留为最稳定的一层。
2. route/id 当前既可以通过 downstream VIF 定向检查，也可以平滑升级到独立 checker。
3. 并发/限制类行为如果继续只靠日志观察，就无法形成可信的 coverage 闭环，因此必须有轻量 tracker。

### 4.5 v1 明确不进入 scoreboard 主范围的项

- WRAP 地址模型
- reset 中断下的 partial transaction flush
- ready/valid 人工延迟下的时序性能度量

这些项应在 gated family 准入后再加，不要先把接口埋进去再长期闲置。

---

## 结论

这份 vPlan 的核心不是“删测试点”，而是把测试点重新组织成 5 个高价值 family：

1. Smoke Route
2. Decode ID
3. DECERR Isolation
4. Concurrency Control
5. Burst Byteen

其中每个 family 都同时绑定了应补的 coverage / scoreboard 任务；WRAP 与 reset/backpressure 则被明确移出 v1 主 signoff 范围，等待准入条件满足后再开启。

这样做的结果是：

- 验证面不缩水，反而更聚焦 DUT 的真实风险点。
- vseq 数量显著减少，维护成本和重复设计成本都会下降。
- 每一个回归 test 都更像一个“能力闭环”而不是一个“动作清单”。
