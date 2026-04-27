# AXI Crossbar Decode Test 完善验证计划 - vPlan_codex_v1

> DUT: `axi_crossbar_wrap_2x2`
>
> 当前验证环境: `uvm/` 下已有 UVM testbench、AXI VIP、scoreboard、coverage、directed vseq
>
> 当前任务重点: 完善 decode 相关 test，先把 testbench 的可观测性和判错能力补齐，再重构 `decode_full_range` 为更完整的 route/decode/ID test pack。

---

## 1. 当前设计和验证的基本环境

### 1.1 DUT 基本设计配置

当前 DUT 是 2x2 AXI crossbar，验证计划必须围绕这个真实配置展开，而不是按理想化 crossbar 泛泛设计。

| 项目 | 当前值 | 对 decode 验证的含义 |
|---|---:|---|
| 上游端口 | 2 | testbench 中记为 `m0/m1`，连接 DUT `s00/s01` |
| 下游端口 | 2 | testbench 中记为 `s0/s1`，连接 DUT `m00/m01` |
| 数据宽度 | 32 bit | 每个 beat 4 byte，关键边界地址应使用 4B aligned 地址 |
| 上游 ID 宽度 | 8 bit | master 侧发送和接收 response 时可见的 ID |
| 下游 ID 宽度 | 9 bit | DUT 应扩展成 `{src_master_idx, upstream_id}` |
| `s0` 地址窗口 | `0x0000_0000 ~ 0x0000_FFFF` | `M00_ADDR_WIDTH=16`，高 16 bit 为 `16'h0000` |
| `s1` 地址窗口 | `0x0001_0000 ~ 0x0001_FFFF` | `M01_ADDR_WIDTH=16`，高 16 bit 为 `16'h0001` |
| 非法地址窗口 | `>= 0x0002_0000` 以及其他未映射区间 | DUT 应在 upstream 侧返回 DECERR，不能转发到 downstream |
| `S_THREADS` | 2 / upstream port | 同一 upstream 端口最多跟踪 2 个 active ID thread |
| `S_ACCEPT` | 16 / upstream port | upstream 接收 outstanding 限制 |
| `M_ISSUE` | 4 / downstream port | downstream issue outstanding 限制 |

当前 decode 的核心判断来自 DUT 地址译码逻辑：

```text
addr[31:16] == 16'h0000 -> s0
addr[31:16] == 16'h0001 -> s1
其他地址                -> DECERR
```

因此 decode test 的关键不是堆大量相似 vseq，而是精准验证：

- 每个 master 都能路由到每个 slave；
- 每个 slave 窗口的 base/mid/end 都能正确译码；
- `0x0000_FFFC` 与 `0x0001_0000` 这个 4B 相邻边界不会混淆；
- nonzero/max ID 在路由过程中能正确扩展和还原；
- illegal address 不会泄漏到 downstream。

### 1.2 当前已有有效 test/vseq

| test | vseq | 当前价值 | 后续策略 |
|---|---|---|---|
| `axicb_smoke_test` | `axicb_smoke_vseq` | 快速 sanity，覆盖 4 条合法路径、随机合法地址、单拍 write/read/compare | 保留为 fast gate |
| `axicb_decode_full_range_test` | `axicb_decode_full_range_vseq` | 已覆盖 `m0/m1 x s0/s1` 的 base/mid/end，且使用非 0 ID，并直接检查 downstream VIF | 作为下一步 decode 完善的核心基础 |
| `axicb_decerr_single_test` | `axicb_decerr_single_vseq` | 随机非法地址，单拍 read/write DECERR，检查 downstream 不泄漏 | decode illegal path 可复用其检查思想 |
| `axicb_decerr_burst_test` | `axicb_decerr_burst_vseq` | 非法突发、DECERR 后合法恢复、随机合法 burst 恢复 | 后续并入 DECERR robustness pack |
| `axicb_decerr_id_test` | `axicb_decerr_id_vseq` | 非 0 ID 覆盖合法/非法路径，覆盖多种 burst length | ID 检查点应拆回 route/decode 与 DECERR 两类 pack |
| `axicb_decerr_dual_mst_test` | `axicb_decerr_dual_mst_vseq` | dual-master DECERR、legal/illegal 混合、交叉 read/write | 长期拆入 DECERR robustness 与 concurrency pack |

### 1.3 当前 testbench 已具备能力

| 能力 | 当前状态 | 对 decode 完善的价值 |
|---|---|---|
| upstream monitor | 已连接 scoreboard 和 coverage | 可检查 upstream response、ID 还原、数据读回 |
| downstream monitor | slave agent 内已存在，但尚未连接 scoreboard/coverage | 是 route 真实观测的基础，但目前利用不足 |
| sequence 控制 ID | 已支持 `awid/arid` | 可覆盖 zero/nonzero/max ID |
| sequence 表达预期 DECERR | 已支持 `expect_decerr` | 可复用到 illegal decode test |
| scoreboard 数据模型 | 支持合法 write/read compare，支持 DECERR 过滤 | 可作为 data correctness 的主检查点 |
| coverage | 已有 type、burst、routing、response 基础 covergroup | 可继续扩展为 route/decode focused coverage |
| direct downstream checker | `axicb_decode_base_vseq` 可直接看 downstream VIF | 当前 decode test 最直接、最强的判错机制 |

### 1.4 当前 decode test 的基本判断

当前 `decode_full_range_vseq` 已经具备比较好的方向，它不是简单地只测一个地址，而是覆盖了：

- `m0/m1` 两个 upstream master；
- `s0/s1` 两个 downstream slave；
- 每个 slave 的 base/mid/end；
- write -> read -> compare；
- nonzero ID；
- downstream VIF direct check。

因此下一步不应该再单独新增这些低价值小 vseq：

| 旧测试点 | 判断 |
|---|---|
| `decode_boundary_test` | 不应独立存在，应合入 `decode_full_range` 的 boundary section |
| `decode_random_addr_test` | 不应独立存在，应作为 legal random sample section |
| `id_nonzero_test` | 不应独立存在，应作为 ID section |
| `id_extreme_values_test` | 不应独立存在，应作为 ID loop |

更合理的方向是：把 `decode_full_range_vseq` 升级成 `route_decode_vseq`，内部包含 full-range、boundary、legal random、ID、downstream no-extra-activity 等强相关测试点。

---

## 2. 完善 Decode 前 testbench 需要修改和健全的内容

decode test 的质量不只取决于 sequence 发了多少地址，更取决于 testbench 是否真的能看见错误、判定错误。以下修改应优先于大量新增 vseq。

### 2.1 修正 scoreboard full-address 建模

当前 scoreboard 存在地址截断风险。若只使用低 16 bit 建模，则：

```text
0x0000_0000 和 0x0001_0000 可能映射到同一个 ref_mem key
0x0000_FFFC 和 0x0001_FFFC 也可能互相覆盖
```

这会直接破坏 decode 边界测试的可信度。

应修改为 full address aligned key：

```systemverilog
word_addr = {addr[ADDR_WIDTH-1:2], 2'b00};
```

同时需要检查：

- `calculate_beat_addr()` 返回值应从 `bit [15:0]` 改为 `bit [ADDR_WIDTH-1:0]`；
- `ref_mem` key 使用完整 32-bit aligned address；
- DECERR transaction 不写入 `ref_mem`；
- `s0/s1` 相同 offset 的地址必须能同时存在于模型中。

#### 通过标志

- 对 `0x0000_0000` 写 `32'hAAAA_0001`；
- 对 `0x0001_0000` 写 `32'hBBBB_0002`；
- 分别读回时不能互相覆盖；
- scoreboard 不报 mismatch；
- debug log 中可以看到两个不同 full address key。

### 2.2 接入 downstream monitor，建立 route-aware 观测

当前 downstream monitor 已经存在于 `axi_slave_agent`，但尚未接入 scoreboard/coverage。decode 的真正目标是确认事务实际到达了正确 downstream，而不是只靠 upstream 地址推断。

建议新增连接：

```text
slv_agent00.item_collected_port -> scb
slv_agent01.item_collected_port -> scb
slv_agent00.item_collected_port -> cov
slv_agent01.item_collected_port -> cov
```

scoreboard 或专用 route checker 应能区分四类输入：

| 输入 | 含义 |
|---|---|
| upstream m0 | master0 侧请求/响应 |
| upstream m1 | master1 侧请求/响应 |
| downstream s0 | 实际到达 slave0 的事务 |
| downstream s1 | 实际到达 slave1 的事务 |

#### route-aware 检查规则

1. legal address 必须只出现在预测 downstream 端口；
2. legal address 不允许同时出现在两个 downstream 端口；
3. illegal address 不允许出现在任何 downstream 端口；
4. downstream `AWID/ARID` 必须等于 `{src_master_idx, upstream_id}`；
5. upstream `BID/RID` 必须还原为原始 upstream ID。

#### 通过标志

- `m0 -> s0/s1` 和 `m1 -> s0/s1` 四条路径均由真实 downstream monitor 命中；
- 非预测 downstream port 没有误命中；
- illegal address 的 downstream hit count 为 0；
- coverage 中 `src_master x dst_slave x txn_type` 命中 8/8。

### 2.3 增强 `downstream_decode_checker()` 的 ID 检查

当前 decode helper 更偏向检查 downstream response `BID/RID`，但 decode/ID 测试还应覆盖 address phase 的 ID 扩展。

需要在 AW/AR handshake 当拍检查：

```systemverilog
// AW handshake 后
if (vif_slv.awid !== expected_id)
    `uvm_error("DECODE_ID", "downstream AWID mismatch")

// AR handshake 后
if (vif_slv.arid !== expected_id)
    `uvm_error("DECODE_ID", "downstream ARID mismatch")
```

其中：

```text
expected_id = {src_master_idx[0], upstream_id[7:0]}
```

#### 通过标志

- `m0` 使用 `8'hAB` 时，downstream ID 为 `9'h0AB`；
- `m1` 使用 `8'hAB` 时，downstream ID 为 `9'h1AB`；
- upstream response 回来后仍为 `8'hAB`；
- AW/AR/B/R 四个方向都没有 ID mismatch。

### 2.4 健全 DECERR no-leak 检查

decode 完善不能只覆盖 legal route，也必须证明 illegal decode 不会错误转发到下游。

需要在 DECERR 相关 testbench 检查中明确：

- illegal write 返回 `BRESP=DECERR`；
- illegal read 返回 `RRESP=DECERR`；
- illegal read beat 数等于 `ARLEN+1`；
- illegal read 最后一拍 `RLAST=1`；
- illegal write/read 均不允许出现 downstream AW/AR；
- illegal transaction 不污染 scoreboard `ref_mem`。

#### 通过标志

- 对 `0x0002_0000` 发 read/write；
- upstream 得到 DECERR；
- s0/s1 downstream monitor 均无对应 AW/AR；
- 随后 legal write/read 仍能正常 compare。

### 2.5 重构 decode coverage

coverage 不应按 testcase 数量设计，而应按 DUT 行为设计。decode 完善阶段至少需要以下 covergroup/bins：

| coverage | 内容 |
|---|---|
| `cg_route` | `src_master x dst_slave x txn_type` |
| `cg_addr_bucket` | `s0_base/s0_mid/s0_end/s1_base/s1_mid/s1_end/illegal` |
| `cg_boundary` | `0x0000_FFFC`、`0x0001_0000` |
| `cg_id` | `id_zero/id_nonzero/id_max x src_master x downstream_id_msb` |
| `cg_resp` | `OKAY/DECERR x READ/WRITE x legal/illegal` |
| `cg_no_leak` | illegal request no downstream hit |

#### decode coverage 关闭标准

- legal route: `m0/m1 x s0/s1 x read/write = 8/8`；
- boundary: `0x0000_FFFC -> s0` 和 `0x0001_0000 -> s1` 均命中；
- ID: zero/nonzero/max 均命中；
- downstream ID MSB: m0 为 0，m1 为 1；
- response: OKAY read/write 与 DECERR read/write 均命中；
- no-leak: illegal read/write 均证明无 downstream 转发。

### 2.6 统一 decode vseq helper，减少重复代码

当前 decode vseq 不应继续扩展大量相似 task，例如 `mx_s0_decode_test()` / `mx_s1_decode_test()` 的变体。建议抽象为少量统一 helper：

```systemverilog
run_write_read_compare(master_idx, addr, id, data);
run_access(master_idx, txn_type, addr, id, data);
expect_route(master_idx, addr, expected_slave, id);
expect_no_downstream_activity(addr);
```

#### 设计目标

- 地址列表负责表达测试意图；
- helper 负责统一执行 write/read/compare；
- checker 负责统一判定 route、ID、response；
- 后续新增 ID 或 random sample 时只增加数据表，不复制流程。

#### 通过标志

- P1 route/decode 测试主体能用地址表和 ID 表驱动；
- 新增一个地址点不需要新增一套 task；
- fail log 能明确打印 master、addr、expected slave、actual slave、ID。

### 2.7 暂不进入 decode 完善主线的内容

以下内容有价值，但不是当前完善 decode test 的第一优先级：

| 内容 | 暂缓原因 |
|---|---|
| WRAP burst | scoreboard/slave memory 尚未完整支持 WRAP，贸然加入会降低结果可信度 |
| 大规模 concurrency/order | 依赖 responder delay knobs 和 nonblocking response collector |
| reset mid-transaction | 需要 scoreboard reset flush 与 monitor partial transaction 策略 |
| 随机 backpressure | 需要 responder 可控延迟和稳定 seed triage |

当前阶段的正确顺序是：

1. 修 scoreboard full-address；
2. 补 downstream AWID/ARID direct check；
3. 扩展 `decode_full_range` 为 P1 route/decode pack；
4. 接 downstream monitor 到 scoreboard/coverage；
5. 再把 DECERR no-leak 纳入 decode/DECERR 交界检查。

---

## 3. 从 Smoke 开始的 test 和测试步骤

本节保留完整 test pack 视角，但当前近期任务应优先完成 P0 和 P1。P2 中的 illegal decode/no-leak 是 P1 之后最紧密相关的下一步。

每个测试点都必须回答三个问题：

- **激励思路**：sequence 应该发什么事务，地址、ID、burst、时序如何组织。
- **设计思路**：这个点在验证 DUT 的哪类风险，为什么它应该放在当前 pack 中。
- **检查通过标志**：明确哪些 monitor、scoreboard、coverage 或 direct checker 现象必须成立。

### P0 - Smoke Gate

#### 当前 test/vseq

- `axicb_smoke_test`
- `axicb_smoke_vseq`

#### 验证目标

快速确认环境能跑、四条合法路径能通、基础数据读回正确。

#### 覆盖内容

- `m0 -> s0`
- `m0 -> s1`
- `m1 -> s0`
- `m1 -> s1`
- 单拍 `INCR`
- 4B aligned
- `WSTRB=4'hF`
- write -> read -> compare

#### 测试点细化

| 测试点 | 激励思路 | 设计思路 | 检查通过标志 |
|---|---|---|---|
| reset 后基础连通 | 复位释放后只发最简单的 4B aligned 单拍 write/read，先访问 `m0->s0` | 先证明 testbench、interface、clock/reset、sequencer、driver、slave responder 都处于可用状态 | 无 UVM FATAL/ERROR；write 返回 `BRESP=OKAY`；read 返回 `RRESP=OKAY` 且 `RLAST=1` |
| 四条合法路径 smoke | `m0->s0`、`m0->s1`、`m1->s0`、`m1->s1` 各执行一次 write -> read -> compare | 这是 crossbar 最小有效连通矩阵，任何 route、端口绑定、地址配置错误都会在这里暴露 | 四条路径均完成；scoreboard compare 全部通过；coverage route bins 命中 4 条 legal path |
| 基础数据通路 | 每条路径使用不同 data pattern，例如 `32'hA0A0_0000 + path_idx` | 避免所有路径写相同数据导致误路由或数据串扰被掩盖 | 每个地址读回对应 pattern；不存在跨 slave 或跨 master 的数据互串 |
| 基础 response/ID | 使用默认 ID 或 `8'h00`，只检查最基础 `BID/RID` 还原 | smoke 不承担复杂 ID 验证，只保证默认 ID 路径没有断 | upstream `BID==AWID`；upstream `RID==ARID`；scoreboard `error_count==0` |

#### 退出条件

- 无 UVM ERROR/FATAL；
- `scb.check_count > 0`；
- `scb.error_count == 0`；
- 基础 route bins 至少命中四条合法路径。

### P1 - Legal Route / Decode / ID Pack

#### 建议 test/vseq

- 短期: 继续使用并增强 `axicb_decode_full_range_test` / `axicb_decode_full_range_vseq`
- 长期: 重构为 `axicb_route_decode_test` / `axicb_route_decode_vseq`

#### 替代的旧测试点

本 pack 覆盖并替代：

- test2-1: `decode_full_range`
- test2-2: `decode_boundary`
- test2-3: `decode_random_addr`
- test2-4: `id_nonzero`

#### Section 设计

| section | 激励 | 检查 |
|---|---|---|
| full-range directed | `m0/m1` 分别访问 `s0:{base,mid,end}` 和 `s1:{base,mid,end}` | downstream port 正确，地址不变，OKAY response，readback 正确 |
| boundary adjacency | 连续访问 `0x0000_FFFC` 和 `0x0001_0000` | 低侧进 `s0`，高侧进 `s1`，数据不混淆 |
| legal random sample | 20~100 个合法 aligned 地址，分布到 `s0/s1` | route prediction 与实际 route 一致，data compare |
| nonzero/extreme ID | 使用 `8'h00/8'h55/8'hAA/8'hFF` 等 ID | upstream response ID 正确还原，downstream ID 正确扩展 |
| same upstream ID from both masters | m0/m1 都使用 `8'hAB` | downstream ID 分别为 `9'h0AB/9'h1AB` |

#### 测试点细化

| 测试点 | 激励思路 | 设计思路 | 检查通过标志 |
|---|---|---|---|
| full-range directed: s0 | `m0/m1` 分别访问 `0x0000_0000`、`0x0000_8000`、`0x0000_FFFC`，每个地址执行 write -> read -> compare | 覆盖 s0 地址窗口的基址、中间、末尾最后一个 4B 对齐 word，证明 decode 不是只在一个样本点成立 | downstream 只在 s0 观察到 AW/AR；AWADDR/ARADDR 保持原值；response OKAY；readback data 正确 |
| full-range directed: s1 | `m0/m1` 分别访问 `0x0001_0000`、`0x0001_8000`、`0x0001_FFFC`，每个地址执行 write -> read -> compare | 覆盖 s1 地址窗口的同构点，尤其证明 `addr[31:16]==16'h0001` 能稳定选中 s1 | downstream 只在 s1 观察到 AW/AR；s0 不出现该事务；response OKAY；readback data 正确 |
| boundary adjacency | 连续发 `0x0000_FFFC` 和 `0x0001_0000`，数据分别使用强区分 pattern，例如 `32'hAAAA_0001` 与 `32'hBBBB_0002` | 两个地址只差 4 byte，却应进入不同 slave，这是 decode 边界最关键的精准打击点 | `0x0000_FFFC` 只到 s0；`0x0001_0000` 只到 s1；两处数据互不覆盖；scoreboard 不发生 full-address alias |
| reverse boundary adjacency | 先访问 `0x0001_0000` 再访问 `0x0000_FFFC` | 排除因事务顺序或 ref_mem 更新顺序造成的假通过 | 两种顺序下 route 和 data compare 均通过；无旧数据残留 |
| legal random sample | 在 `{s0,s1}` 合法窗口内随机 20~100 个 4B aligned 地址，master 在 `m0/m1` 中随机，read/write 成对执行 | 随机样本用于补 directed 没覆盖到的 offset，但不单独成 vseq，避免制造低价值测试 | 每笔事务的预测 slave 与实际 downstream 一致；data compare 通过；coverage `base/mid/end/random` bucket 均命中 |
| ID zero/nonzero/max | 对同一组地址轮流使用 `8'h00`、`8'h55`、`8'hAA`、`8'hFF` | ID 是 route decode 的正交属性，应和合法路由一起覆盖，而不是独立成小测试 | upstream `BID/RID` 等于发送的 `AWID/ARID`；downstream `AWID/ARID/BID/RID` 的扩展 ID 正确 |
| same upstream ID from both masters | `m0` 和 `m1` 同时或连续使用相同 upstream ID，例如 `8'hAB`，分别访问 s0/s1 | 验证 crossbar 的 ID 扩展机制 `{src_master, id}`，避免两个 master 同 ID 在 downstream 侧混淆 | downstream s0/s1 monitor 或 direct checker 看到 `m0` 为 `9'h0AB`，`m1` 为 `9'h1AB`；upstream response 都还原为 `8'hAB` |
| downstream address-phase ID | 在 AW/AR handshake 当拍检查 downstream `AWID/ARID`，不仅检查 `BID/RID` | 只检查 response ID 不够强，地址相位 ID 错误也可能被 slave responder 或返回路径掩盖 | AW handshake 后 `m_awid=={src,id}`；AR handshake 后 `m_arid=={src,id}`；发现不匹配立即报 UVM ERROR |
| no extra downstream activity | 每笔 legal access 根据地址预测唯一 slave，同时观察另一个 slave | decode 错误常见形式不是完全没到，而是两个下游同时收到或收到错误端口 | 预测端口有且只有一笔事务；非预测端口在观察窗口内无对应 AW/AR |

#### 实现建议

避免继续 copy-paste `mx_s0_decode_test()` / `mx_s1_decode_test()`，统一成 helper：

```systemverilog
run_write_read_compare(master_idx, addr, id, data);
run_access(master_idx, txn_type, addr, id, data);
expect_route(master_idx, addr, expected_slave, id);
```

#### 退出条件

- `src_master x dst_slave x txn_type = 8/8`；
- `0x0000_FFFC -> s0` 命中；
- `0x0001_0000 -> s1` 命中；
- ID zero/nonzero/max 命中；
- downstream ID MSB 对 m0/m1 区分正确；
- `s0/s1` 相同 offset 不发生 scoreboard alias；
- legal decode 不出现额外 downstream activity。

### P2 - DECERR Robustness Pack

#### 建议 test/vseq

- `axicb_decerr_robust_test`
- `axicb_decerr_robust_vseq`

现有四个 DECERR vseq 可以短期保留，但长期应合并成一个错误路径鲁棒性 pack。

#### Section 设计

| section | 激励 | 检查 |
|---|---|---|
| illegal write single | `m0/m1` 写非法地址 | `BRESP=DECERR`，`BID=AWID`，无 downstream AW/W 泄漏 |
| illegal read single | `m0/m1` 读非法地址 | 1 拍 `RRESP=DECERR`，`RID=ARID`，`RLAST=1`，无 downstream AR 泄漏 |
| illegal burst write | 2/4/8/16-beat illegal write | W beats 被接收/丢弃，最终 1 个 DECERR B，无下游泄漏 |
| illegal burst read | 2/4/8/16-beat illegal read | 精确 `ARLEN+1` 拍 DECERR，最后一拍 `RLAST=1` |
| DECERR recovery | illegal 后立即 legal write/read | legal 路径恢复，data compare 正确，`ref_mem` 不被非法事务污染 |
| mixed legal/illegal dual master | 一个 master illegal，另一个 legal | illegal 隔离，legal 不受影响 |
| DECERR ID | 非 0 ID 走 illegal path | DECERR response ID 正确还原 |

#### 测试点细化

| 测试点 | 激励思路 | 设计思路 | 检查通过标志 |
|---|---|---|---|
| illegal write single | `m0/m1` 分别向 `0x0002_0000`、`0xFFFF_FFFC` 等非法 4B aligned 地址发单拍 write | 覆盖最基本非法写路径，证明 crossbar 能在地址 decode 阶段直接产生 DECERR | upstream 收到且只收到 1 个 `BVALID`；`BRESP=DECERR`；`BID=AWID`；任何 downstream 端口都没有对应 AW/W |
| illegal read single | `m0/m1` 分别向非法地址发单拍 read | 覆盖最基本非法读路径，读 DECERR 需要同时验证 beat 数和 `RLAST` | upstream 收到 1 拍 R；`RRESP=DECERR`；`RID=ARID`；`RLAST=1`；任何 downstream 端口都没有对应 AR |
| first illegal after legal windows | 访问 `0x0002_0000`，并与 `0x0001_FFFC` 前后相邻执行 | 这是 s1 之后第一个非法窗口，能验证 decode 不会把 `0x0002_xxxx` 错误落到 s1 | `0x0001_FFFC` OKAY 且进 s1；`0x0002_0000` DECERR 且无下游泄漏 |
| illegal burst write | 对非法地址发 2/4/8/16 beat INCR write，W data 使用递增 pattern | 非法 burst write 的风险是 AW 已 DECERR，但 W channel 接收/清理不完整导致死锁或污染 | 所有 W beats 被协议层正常消耗或按 DUT 设计处理；最终 1 个 DECERR B；无 downstream AW/W；后续合法事务不被阻塞 |
| illegal burst read | 对非法地址发 2/4/8/16 beat INCR read | 读 burst DECERR 不能只返回 1 拍，必须和 `ARLEN+1` 的协议语义一致，除非 DUT spec 明确例外 | R beat 数等于 `ARLEN+1`；每拍 `RRESP=DECERR`；最后一拍且仅最后一拍 `RLAST=1`；无 downstream AR |
| DECERR 后同 master 恢复 | 同一 master、同一 ID，先 illegal write/read，再立即 legal write/read 到 s0 或 s1 | 检查错误路径不会污染 thread state、ID state、scoreboard memory 或 channel 状态 | illegal 返回 DECERR；紧随其后的 legal 返回 OKAY；legal readback 正确；scoreboard `ref_mem` 未写入非法地址 |
| DECERR 后换 master 恢复 | `m0` 触发 DECERR 后，`m1` 立即执行 legal access，反向也执行 | 验证错误隔离范围是单事务，不应影响另一个 upstream 端口 | legal master 不被卡住；route 正确；response ID 正确；无额外 error |
| mixed legal/illegal dual master | 两个 master 并行或近距离发送，一个 legal、一个 illegal，read/write 组合交叉 | 更接近真实流量，验证 legal 与 illegal 同时存在时不会互相吞响应 | illegal 只得到 DECERR；legal 只到预测 downstream 且 OKAY；两边 response 数量和 ID 都匹配 |
| DECERR ID zero/nonzero/max | illegal read/write 分别使用 `8'h00`、`8'h5A`、`8'hFF` | DECERR 也是 response，必须遵守 upstream ID 还原规则 | `BID/RID` 始终等于请求 ID；coverage `DECERR x ID bucket` 命中 |
| no-leak watchdog | 在非法事务发出后的固定 handshake 窗口内监听 s0/s1 downstream monitor | DECERR 的核心不是“返回错”，还要证明非法地址没有被错误转发到 slave | s0/s1 均无匹配非法地址 AW/AR；若有 downstream activity，必须能对应其他 legal transaction |

#### 退出条件

- `WRITE x DECERR` 和 `READ x DECERR` bins 命中；
- illegal request 不出现在任何 downstream port；
- DECERR read beat count 正确；
- DECERR 后同 ID legal transaction 不被卡死；
- legal recovery data compare 通过。

### P3 - Burst / Byte-Lane Data Pack

#### 建议 test/vseq

- `axicb_burst_data_test`
- `axicb_burst_data_vseq`

#### 验证目标

验证合法路由场景下的数据通路与 beat/lane 语义，而不是重复地址 decode。

| section | 激励 | 检查 |
|---|---|---|
| INCR burst | 1/2/4/8/16 beats，覆盖 `m0/m1 x s0/s1` | 所有 beat 数据读回一致，W channel 不跨 slave |
| long INCR smoke | 稳定后加入 32/64/128/256 beats 中少量 case | 长 burst 期间 W route 锁定到同一 downstream |
| FIXED burst | 4/8 beat FIXED write/read | 多 beat 写同一地址，最终读回符合模型 |
| WSTRB partial | full/low-byte/high-byte/sparse masks | byte merge 正确 |
| narrow size | 1B/2B/4B | byte lane 与地址推进正确 |
| unaligned INCR | 合法未对齐起始地址 | 首拍地址和后续 aligned 地址符合模型 |

#### 测试点细化

| 测试点 | 激励思路 | 设计思路 | 检查通过标志 |
|---|---|---|---|
| INCR burst basic | 在 `m0/m1 x s0/s1` 上执行 1/2/4/8/16 beat INCR write -> read，每 beat data 不同 | 先覆盖 AXI 最常用 burst 类型，验证地址递增、数据队列、`WLAST/RLAST` 和 route 锁定 | 每个 beat readback data 与写入一致；`WLAST` 只在最后一拍；`RLAST` 只在最后一拍；burst 全程只进入同一 downstream |
| INCR burst near window middle | 选择窗口中部地址，例如 `0x0000_8000`、`0x0001_8000` | 避免边界因素干扰，作为 burst 数据模型的稳定基准 | scoreboard beat address 递增正确；无 mismatch；coverage length bins 命中 |
| long INCR smoke | 在模型稳定后选少量 32/64/128/256 beat case，不做全组合 | 长 burst 用于暴露计数器、buffer、`LAST` 和 outstanding 相关 bug，但不应该在 directed 中爆炸组合数 | 长 burst 完整结束；response 数量正确；无 timeout；readback 全部正确 |
| FIXED burst overwrite | 对同一地址发 4/8 beat FIXED write，data 每拍不同，然后读回 | FIXED 的语义是地址不变，多拍写同一位置，最终值应由 byte-lane 合并后的最后有效写决定 | downstream 地址保持不变；scoreboard 最终模型与 readback 一致；`FIXED x len` coverage 命中 |
| WSTRB full/single lane | 对同一 word 先写全字，再用 `4'b0001/0010/0100/1000` 分别改写单 byte | 验证 byte lane merge，不让 scoreboard 只按整字覆盖而漏掉 WSTRB bug | 未使能 byte 保持原值；使能 byte 更新；四个 single-lane bins 全命中 |
| WSTRB sparse mask | 使用 `4'b0101`、`4'b1010`、`4'b0110` 等 sparse mask | sparse mask 是 byte merge 的高价值 corner，比简单 low/high byte 更容易暴露拼接错误 | readback 每个 byte 与预期模型一致；coverage sparse bin 命中 |
| narrow size 1B/2B/4B | 使用 `AWSIZE/ARSIZE` 为 0/1/2，地址覆盖不同 byte offset | 验证 size 与地址低位共同决定有效 byte lane，防止只按 4B word 简化建模 | 每笔 narrow write 只影响合法 byte；readback 与模型一致；无协议 error |
| unaligned INCR | 在 DUT/VIP 支持范围内选择未 4B 对齐起始地址，例如 `+1/+2` offset 的 1B/2B transfer | 该点依赖 scoreboard 与 slave memory beat 计算，目的是验证低位地址推进，不用于 route decode | 首拍 byte lane 与起始 offset 一致；后续 beat 地址推进符合 AXI 规则；无数据错位 |
| region-edge burst policy | 先作为 review item：确认是否允许 burst 从 `0x0000_FFFx` 跨过 `0x0001_0000` 地址窗口 | crossbar 当前按起始地址 decode，跨 region burst 的期望需要由 spec 明确，不能贸然写成 directed pass/fail | 未澄清前不进入 regression；澄清后补明确断言：要么禁止并报错，要么全 burst 按起始地址路由 |

#### 前置条件

- scoreboard full-address 修正完成；
- scoreboard 和 `axi_slave_mem` 的 beat address 计算通过 review；
- WRAP 暂不进入此 pack，直到模型支持。

#### 退出条件

- `cg_burst` 覆盖 INCR/FIXED 与 1/2/4/8/16 beat；
- `cg_wstrb_lane` 关键 bins 命中；
- 多 beat readback 无 mismatch。

### P4 - Concurrency / Ordering / Limit Pack

#### 建议 test/vseq

- `axicb_concurrency_order_test`
- `axicb_concurrency_order_vseq`

#### 验证目标

验证 crossbar 不只是能路由，还能在并发和 ordering 约束下正确工作。

| section | 激励 | DUT 特性 |
|---|---|---|
| different-slave parallel | `m0->s0` 与 `m1->s1` 并行 | 不同目标可并发 |
| same-slave contention | `m0->s0` 与 `m1->s0` 并行 | AW/AR 仲裁 |
| same ID different master | m0/m1 使用同一 `8'h33` | downstream ID MSB 区分 source |
| same master same ID same destination | 同源同 ID 多笔到同一 slave | thread match destination 允许 |
| same master same ID different destination | 同源同 ID，一笔到 s0 未完成时再发 s1 | ordering protection 应阻塞第二笔 |
| thread limit | 同一 upstream 超过 2 个 unique active ID | 第 3 个 thread 应被 backpressure |
| issue limit | 同一 downstream 超过 4 个 outstanding | downstream issue limit 应 backpressure |

#### 测试点细化

| 测试点 | 激励思路 | 设计思路 | 检查通过标志 |
|---|---|---|---|
| different-slave parallel | 配置 responder 延迟，使 `m0->s0` 与 `m1->s1` 的 write/read 有重叠窗口 | 不同下游目标之间理论上可并发，验证 crossbar 没有不必要的全局串行化 | 两条路径的 AW/AR 能在重叠时间内前进；response 都回到正确 master；数据不互串 |
| same-slave contention | 同时发 `m0->s0` 与 `m1->s0`，再对 s1 重复 | 同一 downstream 需要仲裁，验证仲裁不会丢请求、重复响应或串 ID | 两个请求最终都到同一目标 slave；response 数量为 2；每个 response ID 对应原请求；data compare 通过 |
| same ID different master | `m0` 和 `m1` 使用同一 upstream ID，例如 `8'h33`，目标可相同也可不同 | 这是 ID 扩展的并发版本，比 P1 的连续访问更强 | downstream 看到不同 9-bit ID MSB；upstream 各自收到 `8'h33`；不会把 m0 response 送到 m1 |
| same master same ID same destination | 同一 master、同一 ID，连续发多笔到同一 slave，并通过 responder delay 保持 outstanding | 验证同 ID 同目标 thread 的顺序和接受能力 | response 顺序符合 AXI 同 ID ordering；无数据覆盖错误；无死锁 |
| same master same ID different destination | 同一 master、同一 ID，第一笔到 s0 未完成时尝试第二笔到 s1 | `axi_crossbar_addr` 有 thread destination tracking，这个点验证同 ID 不允许同时占用不同目标 | 第二笔应被 backpressure 到第一笔完成后，或按 DUT 设计保持 ordering；不得同时向两个 slave 发出同源同 ID active transaction |
| read/write overlap | 同一 master 对不同地址混合发 read 与 write，另一个 master 同时发相反方向 | 验证 AR/AW/W/B/R 五通道并发交错时，scoreboard 仍能按事务类型正确匹配 | read/write response 均完整；read 不读到未完成 write 的错误模型值；无 channel timeout |
| thread limit | 同一 upstream 使用 3 个 unique active ID，前两笔通过 responder delay 保持未完成 | 当前 `S_THREADS=2`，第三个 unique thread 应体现为 backpressure 或延后接受 | 第三个 AW/AR 在前两个 active 期间不能被错误接受；前两个完成后第三个可继续；无协议 error |
| issue limit | 同一 downstream 保持 4 个 outstanding 未完成后继续发第 5 个 | 当前 `M_ISSUE=4`，验证下游 issue limit 不会溢出 | 第 5 个请求被 backpressure/延后；已接受请求全部有 response；无丢失、重复或 ID 错配 |
| bounded contention smoke | 在同一 slave 上持续交替发 m0/m1 请求一小段时间，不要求严格 fairness 证明 | 当前计划不做形式化公平性，只做有限窗口内的 starvation smoke | 在有限事务数内两个 master 都至少完成一次；无长时间无响应 timeout |

#### 前置条件

- route-aware scoreboard 已稳定；
- responder delay knobs 可用；
- nonblocking response collection 可用。

#### 退出条件

- 并发下无数据互串；
- 同 ID ordering 行为符合 `axi_crossbar_addr` thread tracking；
- limit 行为体现为 backpressure，而不是协议错误或数据丢失。

### P5 - Backpressure / Reset Pack

#### 建议 test/vseq

- `axicb_backpressure_reset_test`
- `axicb_backpressure_reset_vseq`

#### 验证目标

| section | 激励 | 检查 |
|---|---|---|
| downstream AW/AR backpressure | 延迟某个 downstream `awready/arready` | upstream valid/data 稳定，无 route 丢失 |
| W channel stall | burst 中间延迟 `wready` | WDATA/WSTRB/WLAST 稳定且顺序正确 |
| B/R response delay | 延迟 `bvalid/rvalid` | response 回到正确 upstream |
| reset idle | idle 时 reset | 所有接口回到 reset 状态 |
| reset mid-write | AW 后或 W burst 中 reset | 无 stale B，reset 后 legal transaction 正常 |
| reset mid-read | AR 后或 R burst 中 reset | 无 stale R，reset 后 legal transaction 正常 |

#### 测试点细化

| 测试点 | 激励思路 | 设计思路 | 检查通过标志 |
|---|---|---|---|
| downstream AW/AR backpressure | 对某个 downstream slave 注入 `AWREADY/ARREADY` 延迟，另一 slave 保持正常 | 验证地址通道 backpressure 只影响目标路径，不应污染非目标路径 | upstream valid 期间地址、ID、control 保持稳定；目标路径最终完成；非目标路径可继续或按设计正常仲裁 |
| W channel stall | 在 burst write 中间拉低 `WREADY` 若干周期，覆盖 first/middle/last beat stall | W channel 最容易发生 data、WSTRB、WLAST 错位，必须独立打击 | stall 期间 `WDATA/WSTRB/WLAST` 稳定；恢复后 beat 顺序正确；readback 全部一致 |
| B response delay | 延迟 downstream `BVALID` 或 slave responder 返回 B 的时间 | 验证 write response path 的 ID 和 master routing 不依赖固定延迟 | B 延迟后仍回到正确 upstream；`BID` 正确；后续事务不被错误释放或覆盖 |
| R response delay | 延迟 read data beat，特别是 burst 的中间拍和最后一拍 | 验证 R channel skid/pipeline 和 `RLAST` 传播 | R beat 数正确；顺序正确；`RID/RLAST/RRESP` 不错位；readback data 正确 |
| reset idle | 无 active transaction 时插入 reset，然后重新跑 P0 的四路径 smoke | 先证明 reset plumbing 正常，作为 mid-transaction reset 的前置 | reset 期间接口信号回到合法状态；reset 后 smoke 全通过 |
| reset after AW before W done | write 地址已握手，W beat 尚未全部发送时 reset | 验证 partial write 清理策略，避免 reset 后冒出 stale B 或残留 W state | reset 后不允许出现旧事务 B；scoreboard flush 后 legal write/read 正常 |
| reset during R burst | read burst 已返回部分 R beat 时 reset | 验证 partial read 清理策略，避免 reset 后冒出 stale R beat | reset 后旧 RID/RDATA 不继续返回；monitor 不产生不可归属事务；后续 legal read 正常 |
| reset recovery with both masters | reset 后 `m0/m1` 分别重新访问 s0/s1 | reset 风险常体现在 per-port state 未清干净，必须覆盖两个 upstream | reset 后四条 legal path 都可重新完成；coverage recovery bin 命中；无 stale scoreboard entry |

#### 前置条件

- responder delay knobs；
- scoreboard reset flush 策略；
- monitor partial transaction 处理通过 review。

### P6 - Random Regression Pack

#### 建议 test/vseq

- `axicb_random_regress_test`
- `axicb_random_regress_vseq`

#### 进入条件

只有 P1~P5 的 directed pack 都稳定后，random 才有意义。

#### 随机空间

| 维度 | 范围 |
|---|---|
| source master | m0/m1 |
| destination | s0/s1/illegal |
| operation | read/write |
| ID | weighted zero/nonzero/max |
| burst type | INCR/FIXED，WRAP 待模型支持后加入 |
| burst length | 1/2/4/8/16，少量 long burst |
| burst size | 1B/2B/4B |
| WSTRB | full/partial/sparse |
| backpressure | off/light/heavy |

#### 测试点细化

| 测试点 | 激励思路 | 设计思路 | 检查通过标志 |
|---|---|---|---|
| legal random route | 约束地址只落在 s0/s1，随机 master、read/write、ID、burst length | 用随机补 directed 的组合洞，但仍保证失败容易归因到合法 route/data path | 无 UVM ERROR/FATAL；route prediction 与 downstream 实际一致；data compare 通过 |
| illegal random route | 约束地址落在非法窗口，随机 master、read/write、ID、短 burst | 用随机补 DECERR 地址空间，而不是只测固定 `0x0002_0000` | 所有事务返回 DECERR；无 downstream 泄漏；DECERR coverage bins 增长 |
| mixed legal/illegal stream | 按权重混合 legal:illegal，例如 80:20，保持事务数量可控 | 更接近 regression 场景，验证错误路径和正常路径长时间交错 | legal 全部 OKAY 并可 compare；illegal 全部 DECERR；无死锁或 response 丢失 |
| random burst/lane | 在已支持范围内随机 INCR/FIXED、len、size、WSTRB | 用于提高 burst/lane cross coverage，但不替代 P3 directed debug | burst/lane coverage 达到目标；所有 readback 与 scoreboard 一致 |
| random backpressure profile | 在 responder delay knobs 可用后，随机选择 off/light/heavy profile | 让 pipeline/skid buffer 在多 seed 下被扰动，但每个 profile 必须可复现 | seed 记录完整；失败可用同 seed 重现；无不可解释 timeout |
| seed triage hook | 每个 seed 输出配置摘要：权重、delay profile、最大 outstanding、启用 feature | random 的价值在于可复现和可归因，否则只会制造调试噪声 | regress log 中能定位 seed 和 profile；失败能归入 P1~P5 某个 directed gap |

#### 退出条件

- 多 seed 无 UVM ERROR/FATAL；
- coverage 达到目标阈值；
- 任何随机失败都能用 seed 复现，并能归类到某个 directed gap。
