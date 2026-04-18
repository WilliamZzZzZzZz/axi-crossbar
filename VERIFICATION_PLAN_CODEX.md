# AXI4 2x2 Crossbar 验证计划（CodeX 重构版）

> 基于 `VERIFICATION_PLAN_v1.md` 重构，`v1` 原文件保留不改
>
> DUT: `axi_crossbar_wrap_2x2`
>
> 方法学: UVM 1.2 + VCS
>
> 基线 Commit: `6e3fced`（2026-04-18）

---

## 0. 本版重构结论

本版不再按“功能清单”平铺所有 testcase，而是按下面 3 个现实约束重新编排：

1. 先尊重当前 Testbench 的真实基线，再扩展能力。
2. 先完成低改动、强确定性的 directed 闭环，再进入需要新观测能力的新场景。
3. 每推进 2~3 个 testcase，就同步升级一轮 `Test + Scoreboard + Coverage`，禁止把基础设施拖到最后。

因此，近期路线被重排为：

`基线门禁 -> 合法路由/边界 -> 单拍 DECERR -> ID/响应归属 -> 合法 burst -> 非阻塞写流水 -> lane 级语义 -> WRAP/长 burst 解锁 -> 延迟控制下的竞争/限流 -> reset/随机收敛`

这个顺序的原因不是“哪个功能更酷”，而是三者叠加后的最短闭环：

- 当前真实可用基线只有 `axicb_smoke_test`。
- 当前 `scoreboard` 还不是端到端路由模型，只是 upstream 数据完整性模型。
- 当前 `coverage` 只采样基础 type/burst，`cg_comprehensive` 未激活。
- 当前 `element sequence` 还没有把 `tr_id`、`expected DECERR` 这类关键信息透传出来。
- 当前 `axi_slave_mem` 和 `axicb_scoreboard` 都不支持 `WRAP`。
- 当前 responder 没有可配置延迟旋钮，很多“并发 / limit / fairness / backpressure”场景无法做成严格可证伪的 test。

---

## 1. 真实基线与排序依据

### 1.1 真实基线（以源码为准）

当前主线基线能力如下：

- 已接入回归的 test 只有 `axicb_smoke_test`。
- `axicb_smoke_test` 覆盖 4 条基本路径：
  `m0 -> s0`、`m0 -> s1`、`m1 -> s0`、`m1 -> s1`
- 当前 smoke 只覆盖：
  单拍、4B 对齐、`INCR`、`WSTRB=4'hF`、串行执行、`ID=0`
- `scoreboard` 当前只接收 upstream monitor 事务，不对 downstream 端口做路由/ID 比对。
- `coverage` 当前只激活 `cg_trans_type` 和 `cg_burst`；`cg_comprehensive` 已定义但未 `new()`、未 sample。
- `axi_master_single_sequence` 支持 `wait_for_response=0`，所以“发起非阻塞事务”已经有基础，但“回收并逐笔核对非阻塞 response”还没有完整基础设施。
- 仓库里虽然有 `axiram_fixed/unaligned/narrow/pipeline/reset` 原型 sequence/test，但它们：
  1. 没有进入 `axicb_tests_lib.svh` / `axicb_virt_seq_lib.svh`
  2. 继承链仍是 `axiram_*`
  3. 不能视为当前 crossbar 主线已具备能力

### 1.2 当前隐藏风险

以下几点会直接影响验证计划的优先级：

- `axi_transaction` 当前把 `awlen/arlen` 约束在 `[0:15]`，所以 `len=255` 的长 burst 现阶段不成立。
- `burst_len_enum` 只定义了少数枚举值，而且 `BURST_LEN_16BEATS` 当前编码为 `8'h11`，不适合作为可靠的 16-beat 闭环依据。
- `axi_slave_mem.calc_beat_addr()` 未实现 `WRAP`。
- `axicb_scoreboard.calculate_beat_addr()` 未实现 `WRAP`。
- DECERR 目前会被 VIP sequence 视为错误打印，缺少“预期错误响应”的显式表达。
- responder 只有 timeout 配置，没有 `aw/w/ar/b/r` 各通道的延迟控制，所以很多“并发窗口”不可控。

### 1.3 Code Churn 分级

| 验证主题 | 当前基础 | 主要缺口 | 代码改动量 | 排位 |
|---|---|---|---|---|
| 合法地址译码 / 路由 | smoke 已有单拍路径 | 缺少 route-aware SCB/COV | 低 | 最先 |
| 单拍 DECERR / 恢复 | DUT 已有 DECERR 逻辑 | 缺少 expect-error 与 SCB 过滤 | 低~中 | 第二批 |
| ID 扩展 / 响应归属 | monitor 已采集 upstream/downstream ID | sequence 未暴露 `tr_id`，SCB 未做 ID compare | 中 | 第三批 |
| INCR/FIXED burst | VIP 与 SCB 基本支持 | 缺少 beat 级响应/覆盖增强 | 中 | 第四批 |
| 非阻塞写流水 | `wait_for_response=0` 已支持 | 缺少 outstanding collector | 中 | 第五批 |
| Narrow / partial / unaligned | 有旧原型可复用 | 未接入 crossbar 主线，SCB 非 byte-accurate | 中~高 | 中后期 |
| WRAP | DUT 支持，TB 模型不支持 | SCB/Slave mem/coverage 都要补 | 高 | 后期 |
| Limit / fairness / backpressure | DUT 有逻辑 | 缺少 delay knob、统计与时序观测 | 高 | 后期 |
| Max burst / full random closure | 协议上重要 | VIP 长 burst 能力未解锁 | 很高 | 最后 |

---

## 2. Milestone 总览

| Milestone | 主题 | 代表测试 | 进入条件 | 退出条件 |
|---|---|---|---|---|
| M0 | 基线门禁与观测引导 | `axicb_smoke_test` | 当前工程可编译 | smoke 稳定，基础 coverage/路由观测被激活 |
| M1 | 合法译码与边界路由 | `decode_full_range` / `decode_cross_boundary` / `decode_random_addr` | M0 完成 | 8 个 routing bins 与边界 bins 100% |
| M2 | 单拍 DECERR 与恢复 | `decerr_write` / `decerr_read` / `decerr_then_legal` | M1 完成 | DECERR 读写 bins 100%，SCB 不污染合法模型 |
| M3 | ID 扩展与响应归属 | `id_boundary` / `same_id_diff_master` / `response_route` | M2 完成 | upstream/downstream ID 端到端闭环 |
| M4 | 合法 burst 首轮闭环 | `incr_burst` / `fixed_burst` / `decerr_burst` | M3 完成 | INCR/FIXED 2/4/8 beat 完整闭环 |
| M5 | 非阻塞写流水 | `pipeline_write_basic` / `dual_master_dual_slave` / `post_pipeline_recovery` | M4 完成 | write issue depth 命中，collector 就绪 |
| M6 | Lane 级语义闭环 | `narrow_transfer` / `partial_strobe` / `unaligned` | M5 完成 | byte-lane bins 100% |
| M7 | WRAP 与长 burst 解锁 | `wrap_burst` / `max_burst_unlock` | M6 完成 | WRAP bins 100%，长 burst 能力解锁 |
| M8 | 竞争、限流、backpressure | `parallel_diff_slave` / `same_slave_arb` / `thread_issue_limit` | M7 完成 | contention/block bins 100%，无 starvation |
| M9 | Reset 与回归收敛 | `reset_mid_write` / `reset_mid_read` / `random_full_feature` | M8 完成 | 功能覆盖收敛，随机回归稳定 |

术语约定：

- `m0/m1`: 上游 AXI master，连接 DUT `s00/s01`
- `s0/s1`: 下游 AXI slave memory，连接 DUT `m00/m01`

地址空间约定：

- `s0`: `0x0000_0000 ~ 0x0000_FFFF`
- `s1`: `0x0001_0000 ~ 0x0001_FFFF`
- 非法地址示例：`0x0002_0000+`

---

## 3. Progressive Milestones

## M0. 基线门禁与观测引导

**进入条件**

- 当前分支可正常 `compile/elab`
- `axicb_smoke_test` 可运行

### Test Pack

| Testcase | 设计/激励 | 期望结果 | 验证平台捕获点 |
|---|---|---|---|
| `axicb_smoke_test` | 保持现有 4 路径单拍 write-read。每笔事务固定 `awlen/arlen=0`、`awsize/arsize=2`、`awburst/arburst=INCR`、`wstrb=4'hF`。 | 4 条路径全部返回 `BRESP/RRESP=OKAY`，readback 与 write data 一致。 | 继续使用 sequence compare + 当前 `ref_mem` compare，作为后续全部里程碑的入口门禁。 |

### 【基础设施同步升级】

为支撑后续所有里程碑，M0 必须先补以下“观测引导层”：

**Scoreboard**

- 在现有 `ref_mem` 之外新增一套请求预测结构，例如 `route_expect_q[$]`：
  `'{dir, src_port, dst_port_pred, up_id, addr, len, size, burst, expect_resp}`
- 这层暂不做复杂比对，只负责把 upstream 请求预测成：
  `dst = s0 / s1 / DECERR`
- 后续各里程碑都基于这层结构继续演进，而不是推翻重写。

**Coverage**

- 立刻激活 `cg_comprehensive`，避免“定义了但从未采样”。
- 先预留以下 coverpoint/covergroup 的框架：
  `cp_src_port`、`cp_dst_port_pred`、`cp_addr_legality`、`cp_resp_kind`
- M0 不要求这些 bins 全部命中，但要求编译/采样路径打通。

### 退出条件

- `axicb_smoke_test` 稳定通过
- `cg_comprehensive` 已经真正实例化并 sample
- scoreboard 已具备“请求预测为 s0/s1/DECERR”的基础能力

---

## M1. 合法译码与边界路由

**进入条件**

- M0 退出条件满足
- route prediction skeleton 已经能区分合法地址与非法地址

### Test Pack

| Testcase | 设计/激励 | 期望结果 | 验证平台捕获点 |
|---|---|---|---|
| `axicb_decode_full_range_test` | 对 4 条路径 `m0->s0`、`m0->s1`、`m1->s0`、`m1->s1` 分别执行单拍 write-read。每个 slave 选 3 个地址点：起始地址、区间中点、末尾地址，例如 `s0:{0x0000_0000,0x0000_8000,0x0000_FFFC}`，`s1:{0x0001_0000,0x0001_8000,0x0001_FFFC}`。所有事务固定 `len=0,size=2,burst=INCR,wstrb=4'hF`。 | 地址落在 `s0` 区间时，只有 `m00_axi_if` 观察到 AW/AR/W/R；地址落在 `s1` 区间时，只有 `m01_axi_if` 观察到对应事务。upstream `BRESP/RRESP=OKAY`，readback 与 write data 一致。 | route predictor 比对 `pred_dst` 与 downstream 实际观测端口；coverage 命中 `src x dst x rw` 的 8 个基本路由 bins。 |
| `axicb_decode_cross_boundary_test` | 围绕临界边界连续发起两笔事务：`0x0000_FFFC` 和 `0x0001_0000`。建议 `m0` 先对两个地址各写一笔，再由 `m1` 按相反顺序读回。两笔事务之间不插入长 idle，只保留最小必要握手间隔。 | `0x0000_FFFC` 必须命中 `s0`，`0x0001_0000` 必须命中 `s1`，且两笔事务不能在 downstream 端口上串线。数据读回不能互串。 | `cp_addr_bucket` 命中 `boundary_last_s0` 与 `boundary_first_s1`；SCB 检查两笔事务的 `dst_port_pred` 与实际 `slv_agent` 端口一致。 |
| `axicb_decode_random_addr_test` | 在“合法地址”约束下做 directed-random 单拍事务。每个 master 至少发 100 笔，地址随机分配到 `s0`/`s1` 区间，仍保持 `len=0,size=2,burst=INCR,wstrb=4'hF`，数据随机。 | 所有事务都被路由到预测目标端口，`BRESP/RRESP` 全部为 `OKAY`，`ref_mem` 数据完全匹配。 | 用大量样本灌满 `src x dst x rw` bins，并验证 route-aware SCB 没有误报或漏报。 |

### 【基础设施同步升级】

**Scoreboard**

- 将 M0 的 `route_expect_q[$]` 扩成真正的“请求-观测闭环”：
  `route_expect_q[$] = '{dir, src_port, dst_port_pred, up_id, addr, len, size, burst, issue_seq}`
- downstream monitor 采样到 AW/AR 时，必须按 `{dir, src_port, addr, issue_seq}` 找到对应预测项，并校验：
  1. 只在预测的那个 downstream port 看到事务
  2. 非预测端口上不能出现同一请求
- 仍不要求在这一阶段引入复杂 response compare，但必须把“路由是否正确”独立成 SCB 的第二层检查。

**Coverage**

- 新增 `cg_routing`
  - `cp_src_port = {m0,m1}`
  - `cp_dst_port = {s0,s1}`
  - `cp_dir = {WRITE,READ}`
  - `cx_route = cp_src_port x cp_dst_port x cp_dir`
- 新增 `cg_addr_bucket`
  - `cp_addr_bucket = {base, mid, end, boundary_last_s0, boundary_first_s1}`
  - 与 `cp_dst_port` 交叉，确保边界点不是只跑到一边

### 退出条件

- `axicb_decode_full_range_test`
- `axicb_decode_cross_boundary_test`
- `axicb_decode_random_addr_test`

全部通过，且：

- `cx_route = 8/8`
- `boundary_last_s0` 与 `boundary_first_s1` bins 命中
- route-aware SCB 对 downstream 端口无误报、无漏报

---

## M2. 单拍 DECERR 与恢复

**进入条件**

- M1 完成
- 合法路由的 route-aware SCB 已稳定

### Test Pack

| Testcase | 设计/激励 | 期望结果 | 验证平台捕获点 |
|---|---|---|---|
| `axicb_decerr_write_test` | `m0` 对非法地址 `0x0002_0000` 发单拍 write：`awlen=0`、`awsize=2`、`awburst=INCR`、`wstrb=4'hF`、`id=8'h21`。要求完整走完 `AW -> W -> B` 握手。 | upstream 收到 `BRESP=DECERR`，`BID=8'h21`；downstream `s0/s1` 端都不能看到该笔 AW/W；事务不能挂死。 | coverage 命中 `WRITE x DECERR x illegal_addr`；SCB 标记此事务为 `expect_resp=DECERR`，不得写入 `ref_mem`。 |
| `axicb_decerr_read_test` | `m1` 对非法地址 `0x0002_0040` 发单拍 read：`arlen=0`、`arsize=2`、`arburst=INCR`、`id=8'h4E`。 | upstream 只收到 1 拍 `R`，其中 `RRESP=DECERR`、`RID=8'h4E`、`RLAST=1`；downstream `s0/s1` 均不得出现对应 AR。 | coverage 命中 `READ x DECERR x illegal_addr`；SCB 对 read 只做响应合法性检查，不做 `ref_mem` compare。 |
| `axicb_decerr_then_legal_test` | 同一 master 先发非法单拍 write 到 `0x0002_0080`，2 个周期后立刻对 `s1` 合法地址 `0x0001_0020` 发 `write -> readback`，数据固定为 `0xA5A5_5A5A`。 | 第一笔返回 `DECERR`，第二笔必须恢复为正常 `OKAY` 路径，且 readback 正确。非法事务不能污染后续合法事务状态。 | `cp_recovery_after_error` 命中；SCB 证明 `ref_mem` 只被第二笔合法写更新。 |

### 【基础设施同步升级】

**Scoreboard**

- 在预测项里补充 `is_illegal` 与 `expect_resp`
- `process_write()` / `process_read()` 遇到 `DECERR` 时：
  1. 允许计入 check_count
  2. 禁止更新 `ref_mem`
  3. 禁止把该事务当成“正常 slave 返回的数据完整性事务”
- route-aware SCB 需要把 `DECERR` 视作“虚拟目标端口”，即：
  合法目标是 `s0/s1`，非法目标是 `DECERR`

**Coverage**

- 新增 `cg_resp`
  - `cp_dir = {WRITE,READ}`
  - `cp_resp = {OKAY,DECERR}`
  - `cp_addr_legality = {legal,illegal}`
  - `cx_resp = cp_dir x cp_resp x cp_addr_legality`
- 新增 `cp_recovery_after_error`
  - `illegal_then_legal_ok`

**Sequence / VIP**

- `axi_master_single_sequence` 增加显式的期望响应机制，例如：
  `expect_bresp`, `expect_rresp_first`, `allow_non_okay`
- `axicb_single_write_sequence` / `axicb_single_read_sequence` 透传这些开关，禁止 DECERR 测试靠 report catcher “消音”。

### 退出条件

- 单拍 write/read DECERR 均可被准确识别
- 所有非法事务都不会污染 `ref_mem`
- `illegal_then_legal` 稳定通过
- `cx_resp` 中 `WRITE/READ x DECERR x illegal` 命中 100%

---

## M3. ID 扩展与响应归属

**进入条件**

- M2 完成
- sequence/VIP 已能显式表达期望响应类型

### Test Pack

| Testcase | 设计/激励 | 期望结果 | 验证平台捕获点 |
|---|---|---|---|
| `axicb_id_boundary_test` | 并行发两条合法路径：`m0 -> s0` 使用 `ID=8'h00`，`m1 -> s1` 使用 `ID=8'hFF`，均做单拍 write-read。 | downstream 看到的扩展 ID 必须分别为 `{1'b0,8'h00}` 和 `{1'b1,8'hFF}`；upstream `BID/RID` 必须还原回原始 8-bit ID。 | 命中 `id_low_boundary` / `id_high_boundary` bins；SCB 校验 `m_awid/m_arid` 与 `{src_port, up_id}` 一致。 |
| `axicb_same_id_diff_master_test` | `m0` 和 `m1` 同时使用相同 upstream ID `8'h3C`，并同时访问同一目标 `s0`，地址不同，采用 fork 并发。 | downstream 必须看到两个不同的 9-bit ID：`9'h03C` 和 `9'h13C`；两个 master 都只能收到属于自己的 response，不能串 master。 | coverage 命中 `same_id_diff_master`；SCB 按 `{src_port, up_id, issue_seq}` 做唯一匹配。 |
| `axicb_response_route_test` | `m0 -> s1` 与 `m1 -> s0` 并行运行 write-read，分别用 `ID=8'h11` 和 `ID=8'h22`。允许 response 相互穿插，但不允许归属错误。 | 即使两边返回时序交错，`m0` 只能收到 `ID=8'h11` 的 response，`m1` 只能收到 `ID=8'h22` 的 response。 | coverage 命中 `src x dst x id_class x rw`；SCB 检查 upstream bid/rid 归属。 |

### 【基础设施同步升级】

**Scoreboard**

- 在请求数据库中引入严格唯一键，例如：
  `req_db[key]`, `key = {dir, src_port, up_id, issue_seq}`
- 每个请求项必须记录：
  `dst_port_pred`, `exp_down_id={src_port,up_id}`, `addr`, `len`, `size`, `burst`
- downstream monitor 看到事务时检查：
  1. `m_awid/m_arid == exp_down_id`
  2. 端口 == `dst_port_pred`
- upstream monitor 看到 response 时检查：
  1. `bid/rid == up_id`
  2. response 回到正确 `src_port`

**Coverage**

- 新增 `cg_id`
  - `cp_src_port = {m0,m1}`
  - `cp_up_id_class = {id_00, id_mid, id_ff}`
  - `cp_down_id_msb = {0,1}`
  - `cp_dst_port = {s0,s1}`
  - `cp_collision_kind = {same_id_diff_master, diff_id_diff_master, none}`
- 核心交叉：
  `cp_src_port x cp_up_id_class x cp_dst_port`
  `cp_down_id_msb x cp_src_port`

**Sequence**

- `axicb_single_write_sequence` / `axicb_single_read_sequence` 必须暴露 `tr_id`
- virtual sequence 需能显式指定 `ID`，不能再依赖默认 `0`

### 退出条件

- upstream/downstream ID 扩展与还原端到端闭环
- `same_id_diff_master` 场景无误路由
- `cg_id` 的边界 ID bins 命中 100%

---

## M4. 合法 Burst 首轮闭环

**进入条件**

- M3 完成
- route/ID checker 已稳定

说明：

- 本阶段只闭环 `INCR/FIXED` 的 2/4/8-beat 场景
- 16-beat 与 256-beat 不在本阶段签收，因为当前 VIP 的 length 表达尚未解锁

### Test Pack

| Testcase | 设计/激励 | 期望结果 | 验证平台捕获点 |
|---|---|---|---|
| `axicb_incr_burst_test` | 4 条路径都覆盖。对每条路径分别发 2/4/8-beat aligned `INCR` burst，固定 `size=4B`，例如 `m0->s0 @ 0x0000_0100`、`m1->s1 @ 0x0001_0200`。每 beat 数据不同，`WSTRB=4'hF`。写完后读回同一 burst。 | 第 0 beat 地址等于 `base_addr`，后续每 beat 地址按 4B 递增；`WLAST/RLAST` 只在最后一拍有效；所有 beat 数据逐拍匹配。 | SCB 按 beat 地址表逐拍 compare；coverage 命中 `INCR x len x route`。 |
| `axicb_fixed_burst_test` | 选择 `s0`、`s1` 各一个 aligned word，分别发 4-beat 和 8-beat `FIXED` burst。每 beat 写入不同数据，再按同样的 `FIXED` 方式读回。 | 所有 beat 都落在同一个 word address。对 full-strobe 写而言，memory 最终值等于最后一个写 beat；读 burst 的每拍都应读到该最终 word。 | SCB 需要识别“每 beat 地址相同”的预期；coverage 命中 `FIXED x len x route`。 |
| `axicb_decerr_burst_test` | 非法地址发 4-beat `INCR` burst：一组 write，一组 read。例：`awaddr/araddr=0x0002_0100`，`len=3`，`size=4B`。 | 非法 write：W 4 拍都被 DUT 内部消费，但不下发到任何 slave，最终只回 1 个 `BRESP=DECERR`。非法 read：上游收到 4 拍 `RRESP=DECERR`，只有最后一拍 `RLAST=1`。 | coverage 命中 `burst x DECERR`；SCB 校验 read 的 `rresp[]` 长度和最后一拍 `rlast`。 |

### 【基础设施同步升级】

**Scoreboard**

- 将请求数据库中的 burst 事务扩成 beat 级信息：
  `beat_addr[$]`, `exp_rresp[$]`, `exp_last_idx`
- 对 `READ` 不再只看 `rdata[0]`，而是逐 beat 检查：
  1. 地址序列
  2. `rresp[i]`
  3. `rlast` 位置
- 对 `WRITE` 引入 `exp_wlast_idx`，确保 monitor 观察到的最后一拍位置正确

**Coverage**

- `cg_burst` 改为基于“原始 `len` 数值”采样，而不是仅依赖有限枚举名
- 新增 `cg_burst_resp`
  - `cp_burst_type = {INCR,FIXED}`
  - `cp_len_value = {0,1,3,7}`
  - `cp_resp_kind = {OKAY,DECERR}`
  - `cp_dst_port = {s0,s1,DECERR}`
- 新增 `cp_last_beat_ok`

**长度模型治理**

- 在计划层面明确：
  1. 当前 `burst_len_enum` 不能作为长 burst 闭环依据
  2. `BURST_LEN_16BEATS` 编码需修正
  3. `len=255` 的 testcase 延后到 M7

### 退出条件

- `INCR/FIXED` 的 2/4/8-beat 场景全部通过
- burst DECERR 行为通过
- `WLAST/RLAST` 的最后一拍检查稳定

---

## M5. 非阻塞写流水

**进入条件**

- M4 完成
- beat-level burst compare 已稳定

### Test Pack

| Testcase | 设计/激励 | 期望结果 | 验证平台捕获点 |
|---|---|---|---|
| `axicb_pipeline_write_basic_test` | `m0 -> s0` 连续发 4 笔单拍 write，`wait_for_response=0`，`ID={8'h10,8'h11,8'h12,8'h13}`，地址为 `0x0000_1000 + 4*i`。发完后等待固定窗口，再用 blocking read 逐笔回读。 | 4 笔 write 最终全部生效，无超时、无死锁；回读数据全部正确。 | coverage 命中 `issue_depth=4`；SCB 的 outstanding 表在事务结束后必须完全清空。 |
| `axicb_pipeline_dual_master_dual_slave_test` | fork 两个线程：`m0` 对 `s0` 连发 4 笔 non-blocking write，`m1` 对 `s1` 连发 4 笔 non-blocking write。地址空间互不重叠。 | 两个方向都能持续前进，downstream 两个端口都能观察到事务，不得互相卡死。 | 命中 `concurrent_active_paths={m0->s0,m1->s1}`；SCB 证明两个 port 的 outstanding 独立存在并最终回收。 |
| `axicb_post_pipeline_recovery_test` | 紧跟在 pipeline flood 之后，立即对 4 条基本路径各发 1 笔 blocking write-read。 | pipeline 结束后 DUT 与 TB 都恢复到干净状态，后续阻塞式事务全部正常。 | 命中 `recovery_after_pipeline`；SCB 不允许残留 pending 项。 |

### 【基础设施同步升级】

**Scoreboard**

- 新增 outstanding 数据结构，例如：
  `pending_rsp_q[$]` 或 `pending_req_by_token[token]`
- 每个未完成请求记录：
  `src_port`, `dst_port_pred`, `id`, `dir`, `issue_ts`, `complete_ts`, `addr`, `len`
- 这一阶段先把 write-side non-blocking 完整闭环，read-side collector 放到后续并发阶段继续演进

**Coverage**

- 新增 `cg_issue_depth`
  - `cp_issue_depth = {1,2,3,4}`
  - `cp_src_port = {m0,m1}`
  - `cp_dst_port = {s0,s1}`
- 新增 `cp_recovery_after_pipeline`

**Sequence**

- sequence library 需要支持“发完再回收”的模式，而不是每笔都同步等 response
- 建议引入 token 或 request handle 的概念，为后续 read-side non-blocking collector 铺路

### 退出条件

- write-side `issue_depth=4` 命中
- pipeline 后无 SCB 残留项
- dual-master dual-slave 并发路径稳定

---

## M6. Lane 级语义闭环

**进入条件**

- M5 完成
- outstanding 结构已具备基本可扩展性

说明：

- 本阶段可以复用现有 `axiram_narrow/unaligned` 原型里的算法思想
- 但必须正式迁移到 `axicb_*` 主线，且同时覆盖 `s0/s1`

### Test Pack

| Testcase | 设计/激励 | 期望结果 | 验证平台捕获点 |
|---|---|---|---|
| `axicb_narrow_transfer_test` | 系统化扫描 `size=1B/2B` 的 `INCR` burst。对 32-bit 数据总线：`1B` 覆盖 offset `0/1/2/3`，`2B` 覆盖 offset `0/2`，beats 覆盖 `1..8`。每个 case 先预写初始化 word，再按 lane 生成 `wdata/wstrb`。 | 只有目标 byte lane 被更新，其他 lane 保持初始值；跨 word 边界时，更新的 word 范围与 AXI 地址步进完全一致。 | coverage 命中 `size x offset x beats x dst`；SCB 必须逐 byte compare。 |
| `axicb_partial_strobe_test` | aligned write，覆盖典型 `WSTRB` 模式：`1hot/2hot/3hot/4hot`，单拍和 4-beat 都要有。写后用 full-word readback 检查。 | 只有 `WSTRB=1` 的 lane 发生变化；未使能 lane 维持旧值。 | 命中 `wstrb_class x rw x dst`；SCB 的 byte-lane 模型必须和 readback 完全一致。 |
| `axicb_unaligned_test` | 迁移现有原型中的三类场景：单拍 unaligned、`INCR` unaligned、`FIXED` unaligned。典型地址如 `0x...01/02/03`，覆盖 `m0->s1` 与 `m1->s0`。 | `INCR` 下第 1 拍允许非对齐，后续拍地址按协议对齐后递增；`FIXED` 下所有 beat 始终停在同一非对齐地址语义上，lane mask 重复使用。 | coverage 命中 `unaligned_kind x offset x dst`；SCB 必须按协议规则计算第 0 拍与后续拍的不同地址语义。 |

### 【基础设施同步升级】

**Scoreboard**

- 把单纯 `word -> 32bit` 的数据模型升级为 byte-lane 精度，例如：
  `ref_byte_mem[word_addr][lane]`
- `merge_data_with_strb()` 不再只输出整字，而是显式更新每个有效 byte lane
- read compare 时按 lane 恢复预期 word，再与实际 `rdata` 比较

**Coverage**

- 新增 `cg_lane_mask`
  - `cp_transfer_size = {1B,2B,4B}`
  - `cp_lane_offset = {0,1,2,3}`
  - `cp_wstrb_class = {1hot,2hot,3hot,4hot}`
- 新增 `cg_unaligned`
  - `cp_unaligned_kind = {single,incr,fixed}`
  - `cp_offset = {1,2,3}`

**Sequence**

- 将 `axiram_*` 原型逻辑迁移为 `axicb_*`，并使其支持：
  1. 指定 `src_master_idx`
  2. 指定目标 `dst_slave`
  3. 与 route-aware SCB / coverage 兼容

### 退出条件

- 所有 lane/offset bins 命中 100%
- narrow / partial / unaligned 均通过
- SCB 在 byte-lane compare 上无误报

---

## M7. WRAP 与长 Burst 解锁

**进入条件**

- M6 完成
- byte-lane 模型稳定

### Test Pack

| Testcase | 设计/激励 | 期望结果 | 验证平台捕获点 |
|---|---|---|---|
| `axicb_wrap_burst_test` | 覆盖合法 WRAP 长度 `2/4/8/16` beat。示例：4-beat、4B WRAP 从 `0x0000_0038` 发起，预期地址序列为 `0x38,0x3C,0x30,0x34`。需要在 `m0->s0` 与 `m1->s1` 都覆盖。 | beat 地址按 wrap boundary 回卷，所有数据/响应正确，`WLAST/RLAST` 只在最后一拍出现。 | coverage 命中 `WRAP x len x size x dst`；SCB 和 slave mem 的 beat 地址模型必须给出完全相同的 wrap 序列。 |
| `axicb_max_burst_unlock_test` | 仅在 VIP 长 burst 能力解锁后执行。选择一个合法地址区间，发 `len=255` 的 `INCR` burst，优先验证写通路，再验证读回或关键抽样读回。 | 256 拍事务不超时、不溢出，最后一拍 `WLAST/RLAST` 正确，SCB 与 monitor 不丢拍。 | coverage 命中 `len=255` 长 burst bin；回归日志无 timeout / array bound 问题。 |

### 【基础设施同步升级】

**Scoreboard**

- `calculate_beat_addr()` 补齐 `WRAP`
- 引入 wrap helper：
  `wrap_span = (len+1) * bytes_per_beat`
  `wrap_base = floor(base_addr / wrap_span) * wrap_span`
  `beat_addr = wrap_base + ((offset_within_wrap + beat_idx*stride) % wrap_span)`
- `axi_slave_mem.calc_beat_addr()` 同步补齐 `WRAP`，禁止 SCB 与 responder 使用两套不一致的算法

**Coverage**

- 新增 `cg_wrap`
  - `cp_wrap_len = {2,4,8,16}`
  - `cp_wrap_size = {1B,2B,4B}`
  - `cp_dst = {s0,s1}`
- 新增 `cg_long_len`
  - `cp_len_bucket = {16,32,64,128,256}`

**VIP / 类型系统**

- 将 burst length 表示从“少量枚举名”升级为“保留 8-bit 原始数值”
- 修正 `BURST_LEN_16BEATS` 编码问题
- 放宽 `axi_transaction.c_len`，支持 `0..255`

### 退出条件

- WRAP 全部合法长度 bins 命中 100%
- 长 burst 能力被真正解锁
- WRAP 与长 burst 都不再依赖 workaround

---

## M8. 竞争、限流与 Backpressure

**进入条件**

- M7 完成
- outstanding collector、WRAP、长 burst、byte-lane 模型都已稳定

### Test Pack

| Testcase | 设计/激励 | 期望结果 | 验证平台捕获点 |
|---|---|---|---|
| `axicb_parallel_diff_slave_test` | 给 `s0` 配置明显更长的 `R/B` 延迟，例如 8 cycles；`s1` 保持 0 延迟。两路 master 同时发起等长 burst：`m0 -> s0`，`m1 -> s1`。 | `s1` 的事务必须能在 `s0` 仍然阻塞时独立完成，证明 crossbar 对不同 destination 的 non-blocking 性。 | coverage 命中 `different_dst_concurrent`；SCB 记录两个路径的 accept/complete 时间戳并比较。 |
| `axicb_same_slave_arb_fairness_test` | `m0` 与 `m1` 反复在同周期竞争 `s0`，各发 32 笔单拍 write，地址不同、ID 不同。给 `s0` 增加适度响应延迟，确保竞争窗口持续存在。 | grant 次数长期统计应接近均衡；不能出现一侧长期饿死。数据写入全部正确。 | 命中 `same_dst_contention` 与 `grant_order` bins；统计 `grant_count[m0]` 与 `grant_count[m1]`。 |
| `axicb_thread_issue_limit_test` | 对同一 `src_port`、同一 `dst_port` 注入延迟，先发两个不同 ID 占满 `S_THREADS=2`，再发第三个新 ID；另起一个子场景发 5 笔到同一目的端口以命中 `M_ISSUE=4`。要求观测被阻塞请求在 `awvalid/arvalid` 拉高后，`awready/arready` 长时间不返回，直到前序 completion 释放 slot。 | 第三个新 ID 不能被过早接受；第 5 笔超 issue 请求也必须被阻塞。slot 释放后，请求恢复前进，且全流程无死锁。 | coverage 命中 `block_cause={THREAD,ISSUE}`；SCB/event logger 记录 block cycles 与 release 时刻。 |

### 【基础设施同步升级】

**Scoreboard / Event Logger**

- 在请求项中增加：
  `accept_ts`, `complete_ts`, `block_start_ts`, `block_end_ts`, `block_cause`
- 新增仲裁统计表，例如：
  `grant_count[src_port][dst_port]`
- 对 contention 测试不只做“最终数据正确”检查，还要做：
  1. 是否观察到真实阻塞窗口
  2. 是否观察到阻塞后释放
  3. 是否出现 starvation

**Coverage**

- 新增 `cg_block_cause`
  - `cp_block_cause = {THREAD,ISSUE,ACCEPT,BACKPRESSURE}`
- 新增 `cg_arb`
  - `cp_contention_kind = {same_dst_write, same_dst_read, same_dst_mixed, diff_dst_parallel}`
  - `cp_first_grant = {m0,m1}`
- 新增 `cg_latency_bucket`

**Responder / Driver**

- 给 `axi_slave_write_responder` / `axi_slave_read_responder` 增加 per-channel delay knob：
  `aw_ready_delay`, `w_ready_delay`, `ar_ready_delay`, `b_valid_delay`, `r_valid_delay`
- 如有需要，再给 master driver 增加 `bready/rready` 延迟旋钮，支撑更细粒度 backpressure 场景

**Assertions**

- 继续使用 `axi_if` 里已有的 valid/ready stability assertions 作为基本协议门禁
- 额外补 crossbar 专属断言可选项：
  `grant onehot`, `trans_count range`, `limit hit -> not accept`

### 退出条件

- 不同目的端口的 non-blocking 行为被观测并验证
- thread/issue limit 的“阻塞-释放”闭环稳定
- 仲裁无 starvation
- `block_cause`、`contention_kind`、`latency_bucket` 覆盖达到阶段目标

---

## M9. Reset 与最终回归收敛

**进入条件**

- M8 完成
- delay/backpressure/limit 观测已稳定

### Test Pack

| Testcase | 设计/激励 | 期望结果 | 验证平台捕获点 |
|---|---|---|---|
| `axicb_reset_mid_write_test` | 启动 8-beat `INCR` write（例如 `m0 -> s0`），在 `AW` 已握手且 `W` 已完成 3 拍后拉高 reset，保持 3 cycles，再释放。释放后对 4 条基本路径各执行 1 笔 blocking write-read。 | in-flight 写事务被干净中止；reset 期间不应出现异常悬挂握手；release 后 4 条路径全部恢复。 | monitor 观察 partial transaction 广播；SCB 必须按 reset epoch 清理 pending 项。 |
| `axicb_reset_mid_read_test` | 先预装数据，再启动 8-beat read（例如 `m1 -> s1`），在第 3 个 `R` beat 之后 assert reset。释放后执行合法恢复事务。 | in-flight read stream 被中止，post-reset 不允许残留旧 response；恢复事务全部正确。 | coverage 命中 `reset_during_read`；SCB 验证 reset 前旧 token 不会污染 reset 后事务。 |
| `axicb_random_full_feature_test` | 在所有基础设施都成熟后，随机化 `{src,dst,addr legality,id,len,size,burst,wstrb,delay profile}`，同时允许合法与非法、串行与并发混合。reset 可以只放在指定 seed 子集。 | 无协议断言失败，无 SCB mismatch，无死锁；剩余缺口要么形成新的 directed test，要么进入 waiver。 | 命中 `feature_mix`；回归统计用于最终 closure。 |

### 【基础设施同步升级】

**Scoreboard**

- 引入 reset epoch：
  `current_epoch`
- 每条 pending 项都带 `epoch` 字段
- monitor 捕捉 reset 或 partial transaction 广播后：
  1. 结束当前 epoch
  2. 清理旧 epoch 的 pending/outstanding 项
  3. 对 reset 中断的事务打上 `aborted_by_reset`，避免误算为 DUT 功能错误

**Coverage**

- 新增 `cg_reset_phase`
  - `cp_reset_phase = {idle, mid_aw, mid_w, mid_b, mid_ar, mid_r}`
- 新增 `cg_feature_mix`
  - `cp_addr_legality`
  - `cp_burst_type`
  - `cp_delay_profile`
  - `cp_reset_present`

**回归脚手架**

- 扩展 `Makefile TESTS`
- 将阶段性 directed tests 与最终 random tests 分层组织
- 加入 coverage merge 与 fail triage 的标准流程

### 退出条件

- 所有 reset/recovery testcase 稳定通过
- random regression 在目标 seed 数上稳定
- 功能覆盖达到最终 closure 标准

---

## 附录 A. v1 用例重新归类映射

下表用于回答一个很实际的问题：`v1` 里的 testcase 并没有消失，而是被重新排序、合并成更符合依赖关系的 Milestone。

| v1 / 旧命名 | 新归属 | 说明 |
|---|---|---|
| `axicb_smoke_test` | M0 | 保留为总门禁，不再被“后续功能点”替代。 |
| `axicb_decode_full_range_test` | M1 | 原样保留，前移为第一批 directed case。 |
| `axicb_decode_cross_boundary_test` | M1 | 原样保留，作为边界路由签收用例。 |
| `axicb_decode_random_addr_test` | M1 | 原样保留，但要求 route-aware SCB/COV 同步上线。 |
| `axicb_decerr_write_test` | M2 | 原样保留，放在单拍 DECERR 首轮闭环。 |
| `axicb_decerr_read_test` | M2 | 原样保留，放在单拍 DECERR 首轮闭环。 |
| `axicb_decerr_then_legal_test` | M2 | 原样保留，用于签收恢复能力。 |
| `axicb_decerr_both_masters_test` | M2 扩展回归 | 在 `cg_resp` 和 route-aware SCB 稳定后，作为 M2 的双 master 扩展 case。 |
| `axicb_id_nonzero_test` | M3 | 融入 `id_boundary_test` 与 `response_route_test`；M3 不只测边界 ID，也要求覆盖中间非零 ID。 |
| `axicb_id_boundary_test` | M3 | 原样保留。 |
| `axicb_response_route_test` | M3 | 原样保留。 |
| `axicb_same_id_diff_master_test` | M3 | 原样保留。 |
| `axicb_incr_burst_test` | M4 | 原样保留，但首轮只签收 2/4/8 beats。 |
| `axicb_fixed_burst_test` | M4 | 原样保留。 |
| `axicb_decerr_burst_write_test` | M4 | 与 burst read 合并为 `axicb_decerr_burst_test`。 |
| `axicb_decerr_burst_read_test` | M4 | 与 burst write 合并为 `axicb_decerr_burst_test`。 |
| `axicb_outstanding_basic_test` | M5 | 重命名为 `axicb_pipeline_write_basic_test`，强调当前先签收 write-side non-blocking。 |
| `axicb_outstanding_read_test` | M8 前置 bring-up | read-side non-blocking 依赖 collector 和延迟控制，晚于 write-side bring-up。 |
| `axicb_two_id_ordering_test` | M8 扩展回归 | 与 contention / collector 同步落地后，作为 same-master 多 ID 顺序性验证。 |
| `axicb_thread_limit_basic_test` | M8 | 并入 `axicb_thread_issue_limit_test`。 |
| `axicb_issue_limit_test` | M8 | 并入 `axicb_thread_issue_limit_test`。 |
| `axicb_accept_limit_test` | M8 扩展回归 | 与 delay knob 一起落地；若 coverage 显示 `ACCEPT` 未命中，则拆成 dedicated case。 |
| `axicb_thread_dest_lock_test` | M8 扩展回归 | 依赖相同的 outstanding/collector/延迟基础设施。 |
| `axicb_ooo_response_test` | M8 扩展回归 | 依赖 read-side collector 与延迟控制。 |
| `axicb_parallel_diff_slave_test` | M8 | 原样保留，且成为 non-blocking 竞争场景的主签收用例。 |
| `axicb_same_slave_write_test` | M8 | 融入 `axicb_same_slave_arb_fairness_test`。 |
| `axicb_same_slave_read_test` | M8 扩展回归 | 与 same-slave contention 基础设施共用。 |
| `axicb_same_slave_mixed_test` | M8 | 并入 same-slave contention 组。 |
| `axicb_arb_fairness_test` | M8 | 重命名为 `axicb_same_slave_arb_fairness_test`。 |
| `axicb_narrow_transfer_test` | M6 | 原样保留。 |
| `axicb_partial_strobe_test` | M6 | 原样保留。 |
| `axicb_unaligned_test` | M6 | 原样保留，但从旧 `axiram_*` 原型迁移到 `axicb_*` 主线。 |
| `axicb_wrap_burst_test` | M7 | 原样保留，但后移到 WRAP 模型解锁之后。 |
| `axicb_max_burst_test` | M7 | 原样保留，但明确要求先修 VIP length 能力。 |
| `axicb_backpressure_aw_test` | M8 扩展回归 | 与 responder `aw_ready_delay` knob 绑定。 |
| `axicb_backpressure_w_test` | M8 扩展回归 | 与 responder `w_ready_delay` knob 绑定。 |
| `axicb_backpressure_r_test` | M8 扩展回归 | 与 responder / master `rready` delay knob 绑定。 |
| `axicb_reset_idle_test` | M9 扩展回归 | 与 reset 套件共用 epoch-flush 逻辑。 |
| `axicb_reset_mid_write_test` | M9 | 原样保留。 |
| `axicb_reset_mid_read_test` | M9 | 原样保留。 |
| `axicb_post_reset_recovery_test` | M9 | 融入 `reset_mid_write` / `reset_mid_read` 的后半段恢复签收。 |
| `axicb_random_basic_test` | M9 分层回归 | 作为 `random_full_feature` 之前的轻量预热集。 |
| `axicb_random_contention_test` | M9 分层回归 | 作为 `random_full_feature` 之前的 contention 预热集。 |
| `axicb_random_full_feature_test` | M9 | 原样保留。 |

如果后续实现中发现某个“合并后的 umbrella test”覆盖不够清晰，就应把该子场景重新拆回 dedicated testcase，而不是降低覆盖要求。

---

## 4. 最终 Closure 标准

### 4.1 功能覆盖率

每个里程碑新增的 bins/cross 不允许“先欠着”，而必须在当阶段闭环：

- M1 关闭 routing / boundary
- M2 关闭 DECERR / legality / recovery-after-error
- M3 关闭 ID / collision / response ownership
- M4 关闭 INCR/FIXED burst + burst DECERR
- M5 关闭 write-side issue depth
- M6 关闭 byte-lane / offset / partial strobe
- M7 关闭 WRAP / long burst
- M8 关闭 contention / block cause / latency / fairness
- M9 关闭 reset phase / feature mix

### 4.2 最终项目级退出条件

- Functional coverage `>= 95%`
- 所有 milestone-local bins / crosses `= 100%`
- Code coverage `>= 90%` 或有明确 waiver
- 最终 random regression `>= 1000 seeds` 稳定
- 无未解释的协议断言失败
- 无未解释的 SCB mismatch

---

## 5. 本版计划与 v1 的关键差异

1. 不再把 DECERR、ID、burst、并发、coverage 视为彼此独立的清单，而是放进有前置依赖的渐进路线。
2. 不再默认“SCB/COV 最后补”，而是每 2~3 个 testcase 后强制同步升级一次基础设施。
3. 明确把“仓库里存在但未接入主线”的 `axiram_*` 原型和“当前已可用能力”区分开。
4. 把 `WRAP`、`max burst`、`thread/issue limit` 等高改动项后移，避免计划建立在当前 TB 实际不支持的前提上。
5. 把 `scoreboard` 从单纯 `ref_mem` 数据比对，演进成：
   `data integrity -> route prediction -> ID/response ownership -> outstanding/block timing -> reset epoch`

---

## 6. 延后到主线收敛之后的参数化 Roadmap

以下内容不进入当前主线 closure，但建议在主线稳定后再开分支做参数矩阵扩展：

- `M_CONNECT` 非全连接矩阵
- `M_SECURE=1` 的安全过滤
- `*_USER_ENABLE=1` 的 USER 信号透传
- pipeline register 组合矩阵（bypass/simple/skid）
- 性能/吞吐/长稳态压力
- 更完整的 crossbar 专属 SVA 套件
