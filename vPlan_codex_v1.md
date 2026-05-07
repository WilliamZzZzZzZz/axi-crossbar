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

- `axicb_burst_base_vseq`：中间层，不直接作为 test 运行，负责 burst 公共 helper 与 checker。
- `axicb_burst_type_test`
- `axicb_burst_type_vseq`
- `axicb_burst_size_lane_test`
- `axicb_burst_size_lane_vseq`
- `axicb_burst_long_test`
- `axicb_burst_long_vseq`
- `axicb_burst_region_policy_test`：gated，region-edge policy 澄清后再进入 regression。
- `axicb_burst_region_policy_vseq`：gated，region-edge policy 澄清后再进入 regression。

#### 验证目标

验证合法路由场景下三种 AXI burst mode 的数据通路、beat 地址推进、`LAST` 语义与 byte-lane 语义，而不是重复地址 decode。

P3 的验证顺序应以 burst 完整性为主线：先用简单、可归因的条件同时建立 `FIXED/INCR/WRAP` 三种传输模式的基础闭环，再扩展 `burst_type x burst_len x burst_size x read/write` 组合覆盖，最后展开 WSTRB、narrow、unaligned 等 byte-lane 功能点。这样既保持 burst 验证思路完整，也避免在基础 burst/address 模型尚未证明前把复杂 byte-lane 场景混入，导致失败难以归因。

#### Vseq 分层架构

P3 不建议实现为一个装满所有 testcase 的 `burst_data_vseq`。参考当前 `axicb_decerr_base_vseq -> axicb_decerr_single/burst/id/dual_mst_vseq` 和 `axicb_decode_base_vseq -> axicb_decode_full_range_vseq` 的组织方式，burst pack 应拆成一个中间层和若干按风险域划分的底层 vseq。底层 vseq 数量不预设，按 testcase 的调试归因、运行成本和 signoff 阶段自然拆分。

| 层级 | vseq | 职责 |
|---|---|---|
| 中间层 | `axicb_burst_base_vseq` | 提供 burst 参数表、地址选择、write/read 启动、response/data/route checker、byte-lane 预测等公共 helper；不直接承载 testcase。 |
| 底层 | `axicb_burst_type_vseq` | 验证 `FIXED/INCR/WRAP` 三种 burst mode 的基础语义、length matrix、FIXED overwrite、WRAP address loop。 |
| 底层 | `axicb_burst_size_lane_vseq` | 验证 `AxSIZE`、WSTRB merge、narrow transfer、unaligned INCR 等 byte-lane 语义；依赖 type foundation 已稳定。 |
| 底层 | `axicb_burst_long_vseq` | 验证长 burst counter、buffer、`LAST`、timeout 风险；运行成本高于普通 directed case，因此单独拆出。 |
| gated 底层 | `axicb_burst_region_policy_vseq` | 验证 region-edge/cross-window burst policy；spec 未澄清前只保留计划，不进入主 regression。 |

#### `axicb_burst_base_vseq` 通用 helper

| helper 类别 | helper 功能 | 作用 |
|---|---|---|
| 地址选择 | 根据 `slv_idx` 返回 `base/mid/end` 地址，并提供 safe mid-window 地址选择 | 避免每个底层 vseq 重复写 `s0/s1` 地址表；foundation 与 matrix case 默认使用 mid-window 地址，降低与 decode edge 的耦合。 |
| route 预测 | 根据起始地址计算 expected slave，并返回对应 downstream vif | 统一 route checker 的期望值；P3 只验证合法路由下 burst 不跨 slave，不重复 P1 decode 表。 |
| burst 参数转换 | 统一计算 `beat_num = AxLEN + 1`、`bytes_per_beat = 1 << AxSIZE`、WRAP 合法 len 集合 | 防止各 testcase 对 len enum、size enum 的解释不一致；WRAP single-beat 在这里统一屏蔽。 |
| WRAP 地址模型 | 根据 `base_addr/burst_len/burst_size/beat_idx` 计算 wrap window 与每拍期望地址 | 供 WRAP testcase、narrow WRAP representative case 和 checker 复用；避免 scoreboard 与 vseq checker 使用两套语义。 |
| 通用 beat 地址模型 | 对 `FIXED/INCR/WRAP` 计算每拍期望地址序列 | 支撑 readback 预测、FIXED overwrite、unaligned INCR 首拍与后续 aligned 推进检查。 |
| 地址合法性保护 | 判断 burst 是否会越过 slave window，生成不跨 window 的安全地址；region-edge case 可显式绕过 | 保证普通 burst testcase 失败时可归因到 burst/data path，而不是未定义的 cross-window policy。 |
| data pattern 生成 | 生成 per-beat data，例如 `base_pattern + beat_idx`、walking byte、固定 seed random | 保证 readback mismatch 能定位到 beat index；FIXED/WRAP 场景需要每拍不同 data 才能暴露地址计算错误。 |
| WSTRB pattern 生成 | 生成 full、single-lane、sparse、per-beat rotating mask | lane vseq 不需要手写 mask 数组；coverage 可以按 mask class 收敛。 |
| byte merge 预测 | 根据 old word、new data、WSTRB 计算期望 word | 这是 WSTRB/narrow/FIXED overwrite 的核心 golden model；避免只比较整 word 覆盖掉 byte-lane bug。 |
| burst write 启动 | 创建 `axicb_single_write_sequence`，配置 master、addr、burst_type、len、size、ID、data array、WSTRB array，并返回 B response/ID | 底层 vseq 只表达 testcase 参数，不重复 sequence 字段配置；也便于统一检查 OKAY/DECERR。 |
| burst read 启动 | 创建 `axicb_single_read_sequence`，配置 master、addr、burst_type、len、size、ID，并返回每拍 data/resp/last 信息 | 支撑 write -> read compare、read-only matrix、response count 与 `RLAST` 检查。 |
| write-read compare | 封装 write 后 read，并用 beat address + byte merge 模型预测期望 readback | 大多数合法 burst testcase 复用这个 helper，底层只传参数表。 |
| response checker | 检查 write 只有 1 个 OKAY B 且 BID 匹配；read 有 `ARLEN+1` 个 OKAY R、RID 匹配、仅最后一拍 `RLAST=1` | 直接观察 DUT 在 upstream 返回的协议现象，确保 testcase 成功不只是 scoreboard 静默。 |
| downstream attr checker | 检查 downstream AW/AR 的 `addr/id/burst/len/size` 与 upstream 期望一致 | crossbar 不应转换、拆分、合并 burst；这是 P3 对 crossbar 透传属性的关键检查。 |
| route lock checker | 检查合法 burst 的 AW/AR 只进入 expected slave，W channel 在整个 burst 内不泄漏到其他 downstream | 覆盖 crossbar 在多 beat write 中最关键的 route lock 风险。 |
| timeout checker | 对 B/R burst 完成设置 timeout，并在失败 log 中打印 testcase 参数、master/slave、type/len/size/addr | 长 burst 与 matrix case 必须可诊断，避免失败只表现为仿真挂死。 |
| coverage checkpoint | 在 testcase 结束时打印本 case 期望命中的 coverage 类别 | 让底层 vseq 与 `cg_burst/cg_wrap/cg_wstrb_lane` 的目标保持对应关系，便于 regression triage。 |

#### 底层 vseq 与 testcase 分类

| 底层 vseq | 容纳 testcase | 分类理由 |
|---|---|---|
| `axicb_burst_type_vseq` | `tc_burst_foundation_3type`、`tc_burst_type_len_matrix`、`tc_fixed_overwrite`、`tc_wrap_address_loop` | 这些 testcase 都在回答同一个问题：三种 burst mode 的地址语义、length 行为、route lock 与参数透传是否闭环。 |
| `axicb_burst_size_lane_vseq` | `tc_burst_type_size_rw_matrix`、`tc_wstrb_lane_merge`、`tc_narrow_size_matrix`、`tc_unaligned_incr` | `AxSIZE` 在 AXI 中既是 burst 参数也是 byte-lane 行为的入口；把 size、WSTRB、narrow、unaligned 放在同一 vseq，可以让失败归因集中到 lane/低位地址模型。 |
| `axicb_burst_long_vseq` | `tc_long_incr_smoke` | 长 burst 的价值是打计数器、buffer、`LAST` 和 timeout，运行成本和 debug 方式都不同于普通 matrix，所以单独拆成轻量 smoke vseq。 |
| `axicb_burst_region_policy_vseq` | `tc_region_edge_burst_policy` | cross-window burst 是 crossbar 特有 policy，不是普通 burst 数据通路问题；spec 未明确前该 vseq gated，不进入常规 regression。 |

#### Testcase 细化

| testcase | vseq/task 设计 | checker/期望观测 | 必要性与取舍 |
|---|---|---|---|
| `tc_burst_foundation_3type` | 属于 `axicb_burst_type_vseq`。在 `m0/m1 x s0/s1` 上选 mid-window 地址，例如 `0x0000_8000`、`0x0001_8000`；循环调用 base helper 执行 `FIXED/INCR/WRAP` write -> read，统一使用 4-beat、4B、full WSTRB、per-beat data pattern。WRAP 选合法 non-boundary start，例如 4-beat、4B、`addr=0x0000_8008`。 | response checker 看到 1 个 OKAY B、`ARLEN+1` 个 OKAY R、仅最后一拍 `RLAST=1`；downstream attr checker 看到 `AxBURST/AxLEN/AxSIZE` 透传；route lock checker 看到 AW/AR/W 只进入 expected slave；data checker 看到 readback 与期望一致。 | 这是 P3 的最小闭环门禁。它不追求组合全覆盖，而是先证明三种 burst mode 在最简单条件下都能跑通；没有它，后续 matrix/lane 失败会很难归因。 |
| `tc_burst_type_len_matrix` | 属于 `axicb_burst_type_vseq`。用参数表驱动：`FIXED/INCR` 覆盖 1/2/4/8/16 beats；`WRAP` 覆盖合法 2/4/8/16 beats。每个 case 复用同一 write-read helper，地址由 safe-address helper 保证不跨 slave window。 | response checker 逐 case 检查 beat 数与 `LAST`；coverage checkpoint 期望 `BURST_TYPE_X_LEN` 合法 bins 命中；WRAP single 不生成或被 coverage ignore。 | 这是 burst 完整性矩阵的主干。它替代单独的 `INCR basic` 重复表，不再为 INCR 额外写一套低价值 case。 |
| `tc_burst_type_size_rw_matrix` | 属于 `axicb_burst_size_lane_vseq`。在 type/len foundation 通过后，对 `FIXED/INCR/WRAP` 各取代表性 len，覆盖 `AWSIZE/ARSIZE=0/1/2`，并显式拆 write-only、read-only、write-read 三类路径。 | downstream attr checker 检查 `AxSIZE` 透传；response checker 分别覆盖 B/R 路径；data checker 对 write-read case 按 size 预测 lane 影响；coverage checkpoint 期望 `BURST_TYPE_X_SIZE` 与 read/write cross 命中。 | size 组合既是 burst 参数覆盖，也是 lane 语义入口；把它放在 size/lane vseq，可以和 narrow/WSTRB checker 复用同一套 byte-lane golden model，避免在 type vseq 中重复建模。 |
| `tc_fixed_overwrite` | 属于 `axicb_burst_type_vseq`。对同一 word 地址执行 4/8 beat `FIXED` write，每拍 data 不同；基础版本使用 full WSTRB，扩展版本可调用 lane helper 加 partial WSTRB。随后用 FIXED 或 single read 读回同地址。 | beat address checker 期望每拍地址都等于起始地址；byte merge checker 预测最终 word 等于最后有效写合并后的值；readback 必须与最终模型一致。 | 普通 write-read compare 可能掩盖 FIXED 的“多拍同地址覆盖”语义，因此需要单独 testcase。它是 FIXED 最有价值的 corner，不是冗余 case。 |
| `tc_wrap_address_loop` | 属于 `axicb_burst_type_vseq`。对 WRAP 2/4/8/16 beat 分别运行 boundary start 与 non-boundary start；例如 4-beat、4B、`addr=0x0000_4008`，期望地址序列为 `0x4008,0x400C,0x4000,0x4004`。 | WRAP 地址 helper 计算 wrap window 和每拍期望地址；data checker 用不同 beat data 验证回绕后的读回位置；coverage checkpoint 期望 `WRAP_LEN` 与 `WRAP_START_OFFSET` 命中。 | WRAP 是三种基础 burst mode 之一，但它的风险集中在回绕地址，不应只靠 matrix 里的 readback 间接覆盖；这个 testcase 是必要的 WRAP directed。 |
| `tc_wstrb_lane_merge` | 属于 `axicb_burst_size_lane_vseq`。合并原 single-lane 与 sparse-mask 两类 testcase：先 full write baseline，例如 `32'hAABB_CCDD`；再依次使用 `4'b0001/0010/0100/1000` 与 `4'b0101/1010/0110` 写入易观察 data，每次写后 readback。 | byte merge checker 对每个 byte 独立判断保留/更新；readback 必须逐 byte 匹配；coverage checkpoint 期望 single-lane 与 sparse bins 命中。 | single 与 sparse 都验证同一个 byte merge 机制，拆成两个 testcase 会增加调度成本但不增加太多归因价值，因此合并为一个高价值 lane testcase。 |
| `tc_narrow_size_matrix` | 属于 `axicb_burst_size_lane_vseq`。覆盖 `AWSIZE/ARSIZE=0/1/2` 与不同 byte offset；在三种 burst type 中各取少量代表组合，例如 `INCR len=4 size=1B offset=1`、`FIXED len=4 size=2B`、`WRAP len=4 size=2B aligned start`。 | beat address checker 期望 stride 等于 `1 << size`；byte merge checker 期望 narrow write 只更新合法 byte；WRAP case 额外检查起始地址满足 transfer size 对齐；readback 与模型一致。 | 这个 testcase 覆盖 size 对 lane 的真实影响，和 `tc_burst_type_size_rw_matrix` 的参数/方向覆盖互补；前者看系统组合，后者看具体 lane 数据语义。 |
| `tc_unaligned_incr` | 属于 `axicb_burst_size_lane_vseq`。只覆盖 AXI 合法 unaligned INCR，例如 1B transfer 的 `addr+1/+2/+3`、2B transfer 的合法 offset；执行短 burst write -> read。 | beat address checker 期望第 0 拍使用 unaligned 起始地址，后续 beat 按 aligned stride 推进；byte-lane checker 期望首拍 lane 与 offset 匹配，后续无数据错位。 | unaligned 只对 INCR 有明确高价值；把它扩展到所有 type 会制造低收益组合。该 testcase 保留关键风险，避免冗余。 |
| `tc_long_incr_smoke` | 属于 `axicb_burst_long_vseq`。选少量 32/64/128/256 beat INCR case，不做 type/size 全组合；使用固定 seed data pattern，并限制 outstanding，确保失败可复现。 | timeout checker 确认不会挂死；response checker 统计 B/R 数量和最后一拍 `LAST`；data checker 可全量或抽样比对，并在失败 log 打印 beat index。 | 长 burst 主要打计数器、buffer、`LAST` 和 timeout 风险，和三种 type foundation 目标不同；保持 smoke 规模即可，避免 directed case 爆炸。 |
| `tc_region_edge_burst_policy` | 属于 gated `axicb_burst_region_policy_vseq`。先作为 review testcase：列出从 `0x0000_FFFx` 发起并可能跨到 `0x0001_0000` 的 INCR/WRAP case，等待 spec 明确 crossbar 是否允许跨 slave window burst。澄清后再实现为 directed task。 | 若 spec 定义禁止跨 window，checker 期待 DECERR 或拒绝策略且无 downstream 泄漏；若 spec 定义按起始地址路由，checker 确认整个 burst 固定到起始地址 decode 的 slave。未澄清前不进入 regression pass/fail。 | 这是 crossbar 特有的关键 policy 风险，不能遗漏；但在 spec 未明确前不能写成硬性 pass/fail，否则 regression 结果没有可信度。 |

#### 前置条件

- scoreboard full-address 修正完成；
- scoreboard 和 `axi_slave_mem` 的 beat address 计算通过 review；
- scoreboard、`axi_slave_mem`、sequence constraint 与 coverage 已支持 `FIXED/INCR/WRAP` 三种 burst type；
- WRAP 合法性约束明确：只生成 2/4/8/16 beat，且起始地址满足 transfer size 对齐。

#### 退出条件

- `axicb_burst_type_vseq`、`axicb_burst_size_lane_vseq`、`axicb_burst_long_vseq` 均无 UVM ERROR/FATAL；
- `cg_burst` 覆盖 `FIXED/INCR/WRAP` 与合法 length/size 组合；
- `cg_wrap` 覆盖 WRAP 2/4/8/16 beat 与 boundary/non-boundary start offset；
- `cg_wstrb_lane` 关键 bins 命中；
- 多 beat readback 无 mismatch；
- `axicb_burst_region_policy_vseq` 在 region-edge policy 明确前不计入 P3 active signoff。

### P4 - Concurrency / Ordering / Limit Pack

#### 建议 test/vseq

- `axicb_concurrency_base_vseq`：中间层，不直接作为 test 运行，负责 nonblocking 激励、overlap 控制、blocked-window 检查与 response 收集 helper。
- `axicb_concurrency_arb_test`
- `axicb_concurrency_arb_vseq`
- `axicb_ordering_resp_test`
- `axicb_ordering_resp_vseq`
- `axicb_limit_guard_test`
- `axicb_limit_guard_vseq`

#### 验证目标

P4 不应再按“并发场景名字”堆 testcase，而应从当前 DUT 在 concurrency / ordering 维度真正存在的独立 RTL 分支出发设计 directed case。对于本 DUT，P4 的 signoff 重点不是证明“事务能同时跑起来”这么泛的结论，而是逐个打到以下真正独立的设计点：

| DUT 代码位置 | 当前真正独立的验证点 | 对 testcase 设计的含义 |
|---|---|---|
| `axi_crossbar_addr.v` | `thread_match_dest` 命中时允许同 ID 同目标继续进入 | 必须有 same-master same-ID same-destination 的 active overlap case，证明同一 thread 可递增，而不是误阻塞 |
| `axi_crossbar_addr.v` | `thread_match` 命中但 `thread_match_dest` 不命中时阻塞 | 必须有 same-master same-ID different-destination case，证明 destination tracking 真在起作用 |
| `axi_crossbar_addr.v` | `!(&thread_active) && !thread_match` 时新 thread 分配 | 只需要少量 truly-new-ID case；不应把“不同地址/不同 slave 的不同 ID”拆成大量重复 testcase |
| `axi_crossbar_addr.v` | `&thread_active` 导致 `S_THREADS` 限流 | 必须有第 3 个 unique ID 被 backpressure 的 directed case |
| `axi_crossbar_addr.v` | `trans_limit` 导致 `S_ACCEPT` 限流 | 原 P4 未覆盖；必须补一个 same-master admission pressure case |
| `axi_crossbar_wr.v` | 同一 downstream 的 AW 仲裁 + `w_select_valid_reg` 写数据锁定 | 不能只做 single-beat contention；必须用 multi-beat write 才能真正覆盖 W channel lock |
| `axi_crossbar_wr.v` | upstream B response arbiter：多个 legal slave response 竞争同一 master | 原 P4 未显式覆盖；必须有 same-master dual-destination write overlap |
| `axi_crossbar_wr.v` | upstream B response arbiter：legal response 与 DECERR pseudo-port 竞争 | 原 P4 未覆盖；必须有 same-master legal+illegal overlap |
| `axi_crossbar_rd.v` | 同一 downstream 的 AR 仲裁 | 需要 read contention representative case，但不必把端口排列全排列展开 |
| `axi_crossbar_rd.v` | upstream R response arbiter + completion 只在 `RLAST` 计数完成 | 必须有 same-master dual-destination read overlap，且至少一个 multi-beat read case |
| `axi_crossbar_wr/rd.v` | per-downstream `M_ISSUE` limit | write/read 是两套独立 RTL，limit case 不能只测一个方向 |
| `arbiter.v` | RR mask path、fallback path、hold-until-ack path | 不需要单独立 arbiter testcase，但 same-slave repeated contention case 必须能让 grant 真正轮转，而不是只打一轮同时请求 |

P4 的 testcase 裁剪原则应明确写入计划：一个 testcase 至少要打到一个新的 DUT 分支、状态转移或资源上限；如果两个场景只是 master/slave/addr 的表面排列不同，但落到 DUT 的同一段 RTL，则不应拆成两个 case。

#### 基于 DUT 代码的 testcase 裁剪原则

| 看起来不同的场景 | 为什么不单独立项 |
|---|---|
| `m0->s0` 并行 `m1->s1` 与 `m0->s1` 并行 `m1->s0` | 这两类只是在 2x2 generate 实例上做镜像排列，对 source-level RTL 分支没有新增覆盖；保留一个能证明“不同 downstream 可并发”的代表场景即可 |
| `same ID different master` 的 same-slave 版和 different-slave 版 | downstream ID 扩展逻辑本质相同；保留 same-slave 版更强，因为它同时覆盖同一 downstream 仲裁与 response 路由 |
| same-master different-ID same-destination 与 same-master different-ID different-destination | 在 `axi_crossbar_addr` 看，二者都只是“新 thread 分配”；若不是为了打 `M_ISSUE` 或 upstream response arb，不应拆成两个 testcase |
| `read/write overlap` 作为独立 testcase | 当前读写路径在 `axi_crossbar.v` 中是两套基本独立子模块，纯粹的 read/write 混跑更像 testbench 压力而不是新的 DUT 逻辑点；不应作为 P4 主 testcase |
| fairness 证明型 case | 当前动态仿真只能做 bounded RR smoke，不能把“长期公平性证明”伪装成 directed testcase |
| same-ID different-region case | 当前 DUT `M_REGIONS=1`，相关分支不可达；不能设计看起来复杂但实际打不到代码的 testcase |

#### 原 P4 未覆盖但必须补入的点

| 缺口 | 对应 DUT 代码 | 为什么必须补 |
|---|---|---|
| `S_ACCEPT` limit | `axi_crossbar_addr.v` 的 `trans_limit` | 原 P4 只提 `S_THREADS` 和 `M_ISSUE`，漏掉了 upstream admission depth 这一条真实限流逻辑 |
| same-master legal+legal response arbitration | `axi_crossbar_wr.v` 的 `b_arb_inst`、`axi_crossbar_rd.v` 的 `r_arb_inst` | 原 P4 的 different-master parallel 不会让两个 downstream response 回到同一个 upstream，根本打不到这一层仲裁 |
| same-master legal+DECERR overlap | `b_request[M_COUNT_P1-1]`、`r_request[M_COUNT_P1-1]` | 原 P2/P4 都没有真正制造 DECERR pseudo-port 与 legal response 同 upstream 竞争的场景 |
| write multi-beat contention 下的 W lock | `w_select_valid_reg / w_select_reg` | single-beat write 不会真正覆盖 write data 路由锁定逻辑，容易留下最危险的 write 并发 bug |

#### Vseq 分层架构

P4 不建议继续沿用一个 `concurrency_order_vseq` 装下全部 testcase。参考 P3 的组织方式，P4 应按“真正独立的 RTL 风险域”拆为中间层和若干底层 vseq，而不是按场景名字堆砌。

| 层级 | vseq | 职责 |
|---|---|---|
| 中间层 | `axicb_concurrency_base_vseq` | 提供 nonblocking 启动、response collector、slave hold/release hook、blocked-window checker、overlap watcher、same-ID ordering checker、limit-release checker；不直接承载 testcase。 |
| 底层 | `axicb_concurrency_arb_vseq` | 覆盖同一 downstream 的 AW/AR 仲裁、RR 轮转、same-ID different-master 的 ID 扩展并发版本、write W-channel lock。 |
| 底层 | `axicb_ordering_resp_vseq` | 覆盖 same-master same-ID allow/block、same-master multi-destination legal response arbitration、same-master legal+DECERR overlap。 |
| 底层 | `axicb_limit_guard_vseq` | 覆盖 `S_THREADS`、`S_ACCEPT`、`M_ISSUE` 三类资源上限及其释放后的恢复行为。 |

#### `axicb_concurrency_base_vseq` 通用 helper

| helper 类别 | helper 功能 | 作用 |
|---|---|---|
| nonblocking 发起 | `launch_nb_write()` / `launch_nb_read()`：按 `master/addr/id/len/type/size` 发起 nonblocking transaction，并返回 tag | P4 的大部分 testcase 都要求多个 outstanding 重叠；不能再依赖单个 blocking `write->read` 流程 |
| response 收集 | `collect_write_rsp_by_tag()` / `collect_read_rsp_by_tag()` / `collect_rsp_by_monitor()` | same-master multi-outstanding case 不能依赖 sequence 返回顺序，必须有按 `master + id + txn_tag` 归属的显式 collector |
| downstream hold hook | `hold_slave_b_rsp()` / `hold_slave_r_rsp()` / `release_slave_rsp()` | 用于稳定制造 overlap 窗口、thread full、accept full、issue full，而不是靠随机时序“碰运气” |
| blocked-window 检查 | `expect_aw_blocked()` / `expect_ar_blocked()` | same-ID different-destination、thread full、accept full、issue full 的核心检查不是最终能跑完，而是在被设计要求阻塞的窗口内确实没有 handshake |
| route/ID 检查 | `expect_downstream_aw/ar()`、`expect_upstream_b/r()` | 复用 P1/P2 的 route-aware 检查，同时加强并发下的 `AWID/ARID/BID/RID` 归属确认 |
| overlap watcher | 记录 AW/AR/B/R 时间戳和 active count | 用于证明 overlap 真发生，而不是表面“fork 了两个 sequence”但实际上串行执行 |
| W interleave checker | 记录 multi-beat write 的 `WVALID/WREADY/WLAST` 来源与连续性 | 这是 write contention 的关键 checker；必须证明 burst 内 W beat 不会在两个 master 间交错 |
| limit-release checker | 在一个 completion 后等待被阻塞事务继续前进 | 三类 limit case 都必须证明“阻塞后可恢复”，而不是只证明会卡住 |

#### 底层 vseq 与 testcase 分类

| 底层 vseq | 容纳 testcase | 分类理由 |
|---|---|---|
| `axicb_concurrency_arb_vseq` | `tc_same_slave_rr_write_contention`、`tc_same_slave_rr_read_contention` | 这两个 testcase 共同回答一个问题：同一 downstream 下，仲裁、ID 扩展和写数据/读响应通路在真正有竞争时是否正确工作。 |
| `axicb_ordering_resp_vseq` | `tc_same_id_same_dest_allow`、`tc_same_id_diff_dest_block`、`tc_same_master_dual_dest_write_resp_arb`、`tc_same_master_dual_dest_read_resp_arb`、`tc_same_master_legal_illegal_overlap` | 这些 testcase 都围绕 address-thread rule 与 upstream response arbitration 展开，失败归因集中。 |
| `axicb_limit_guard_vseq` | `tc_thread_limit_unique_id`、`tc_accept_limit_same_id_pressure`、`tc_issue_limit_write`、`tc_issue_limit_read` | 三类 limit 都属于“资源上限 + 释放恢复”类问题，适合统一组织和统一 checker。 |

#### Testcase 细化

| testcase | vseq/task 设计 | 新增 DUT 覆盖点 | 检查/通过标志 | 必要性与取舍 |
|---|---|---|---|---|
| `tc_same_slave_rr_write_contention` | 属于 `axicb_concurrency_arb_vseq`。`m0` 与 `m1` 对同一 slave 发 4-beat write burst，两个 master 使用相同 upstream ID，例如 `8'h33`，并重复若干轮同类请求以推动 arbiter 真正轮转。优先选择 `s0_mid_addr`，避免 decode edge 干扰。 | `axi_crossbar_wr` 的 same-slave AW arb、`w_select_valid_reg`/`w_select_reg` 写数据锁定、`BID` 上游还原；`arbiter.v` 的 RR mask/fallback/ack hold 路径。 | 两个 master 都能在有限轮数内至少获得一次 grant；同一 burst 的 W beat 只能来自一个 master，直到该 burst `WLAST` 完成后才允许切换；两个 master 各收到 1 个且只收到 1 个 `B`；`BID` 都还原为 `8'h33`；downstream 看到两个不同 9-bit ID MSB。 | 这是 write 并发里最有价值的 representative case。它已经同时覆盖 same-slave contention 和 same-ID different-master，无需再拆一个“same ID 并发” testcase。 |
| `tc_same_slave_rr_read_contention` | 属于 `axicb_concurrency_arb_vseq`。`m0` 与 `m1` 对同一 slave 发 4-beat read burst，两个 master 同样使用相同 upstream ID。通过 slave response hold hook 让两个 read active 窗口重叠。 | `axi_crossbar_rd` 的 same-slave AR arb、`RID` 上游还原、`trans_complete` 只在 `RLAST` 完成。 | 两个 master 在有限轮数内都至少完成一次；downstream 看到不同 9-bit `ARID` MSB；上游各自只收到本 master 的 `RID=8'h33`；每个 read 都有精确 `ARLEN+1` 拍，且仅最后一拍 `RLAST=1`。 | 这是 read 方向对 write contention 的对称但不重复覆盖，因为 `axi_crossbar_rd` 是另一套独立 RTL。 |
| `tc_same_id_same_dest_allow` | 属于 `axicb_ordering_resp_vseq`。同一 master、同一 ID、同一 slave，先发一笔 multi-beat read 并保持未完成，再发第二笔同 ID 同目标 read；必要时追加第 3 笔形成同 thread 的计数递增。 | `axi_crossbar_addr.v` 的 `thread_match_dest` 允许分支，以及同一 thread 的 `thread_count_reg` 递增/递减。 | 第二笔请求在第一笔未完成时就能被接受；两个 response 按 AXI 同 ID ordering 返回；无死锁；全部完成后 active thread 释放。 | 这个点不能被 “different ID parallel” 代替，因为只有 same-ID same-destination 才会触发 `thread_match_dest` 分支。优先用 read 作为主代表，因为 `RLAST` completion 更容易观测。 |
| `tc_same_id_diff_dest_block` | 属于 `axicb_ordering_resp_vseq`。同一 master、同一 ID，第一笔先发到 `s0` 并保持 active，第二笔立即尝试发到 `s1`。主代表使用 write 地址通道即可；若后续需要实例级覆盖，可再补 read 镜像。 | `axi_crossbar_addr.v` 的 `thread_match` 命中但 `thread_match_dest` 不命中时阻塞的关键分支。 | 在第一笔完成前，第二笔 `AW/AR` 必须持续被 backpressure；对应的非目标 downstream 不允许出现提前的 AW/AR；第一笔完成后第二笔才能继续。 | 这是当前 crossbar 最关键的 ordering protection 之一，原 P4 虽提到但缺乏代码覆盖导向的设计说明。该点只需一个主代表方向即可，不必 write/read 全镜像。 |
| `tc_same_master_dual_dest_write_resp_arb` | 属于 `axicb_ordering_resp_vseq`。同一 master 使用两个不同 ID，分别向 `s0` 与 `s1` 发 short write，采用 nonblocking 启动并制造两个 legal B response 的重叠竞争窗口。 | `axi_crossbar_wr` 的 upstream `b_arb_inst` legal-vs-legal response arbitration；同一 master 下不同 downstream 可并发而非全局串行。 | 两个 AW 都能在前一笔 `B` 返回前进入系统；上游最终收到两笔且只收到两笔 `B`；两个 `BID` 分别对应原始请求 ID；无 response 丢失、重复或串 master。 | 原 P4 的 different-master parallel 根本打不到这个 arbiter 层，这个 testcase 是必须新增的。 |
| `tc_same_master_dual_dest_read_resp_arb` | 属于 `axicb_ordering_resp_vseq`。同一 master 使用两个不同 ID，分别向 `s0` 与 `s1` 发 multi-beat read，并通过 slave hold hook 让两个 downstream 的 R response 在 upstream 侧竞争。 | `axi_crossbar_rd` 的 upstream `r_arb_inst` legal-vs-legal response arbitration，以及 `trans_complete` 只在 `RLAST` 结束后释放 outstanding。 | 两个 AR 都能在前一笔 read 完成前被接受；每个 response 都回到正确 ID；任一 transaction 都不能在中间 beat 被“截断完成”；所有 `RLAST` 位置正确。 | 这比“different-slave parallel”更强，因为它真的覆盖了 same-upstream response competition。 |
| `tc_same_master_legal_illegal_overlap` | 属于 `axicb_ordering_resp_vseq`。同一 master、不同 ID，同时发一笔 legal access 和一笔 illegal access；分别做 write 子场景和 read 子场景。illegal 地址建议用 `0x0002_0000`。 | `axi_crossbar_wr/rd` response arbiter 中额外的 DECERR pseudo-port 路径；legal response 与 DECERR response 竞争同一 upstream。 | legal transaction 只收到 OKAY；illegal transaction 只收到 DECERR；illegal 仍无 downstream 泄漏；两个 response 都不能丢、重、串 ID。 | 这是原 P2/P4 都没有真正覆盖到的缺口；不补这个点，`b_request[M_COUNT_P1-1]` / `r_request[M_COUNT_P1-1]` 基本处于盲区。 |
| `tc_thread_limit_unique_id` | 属于 `axicb_limit_guard_vseq`。同一 master 连续发 3 个 unique active ID，前两笔保持未完成，第 3 笔尝试进入。主代表可用 read 路径。 | `axi_crossbar_addr.v` 的 `&thread_active` 限流路径，即 `S_THREADS=2` 的真实生效。 | 前两笔被接受且 active；第 3 笔在 active window 内不能被接受；任一前序 transaction 完成后，第 3 笔可继续；无协议 error。 | 这是原 P4 已提到但需要明确为“unique ID thread slot”而非泛泛 outstanding case。 |
| `tc_accept_limit_same_id_pressure` | 属于 `axicb_limit_guard_vseq`。同一 master、同一 ID、同一 destination，利用 same-thread allow 行为把 active transaction 压到 16 笔，再尝试第 17 笔。主代表推荐 read 路径，因为更容易用 R hold 稳定制造窗口。 | `axi_crossbar_addr.v` 的 `trans_limit`，即 `S_ACCEPT=16` 的真实 admission limit。 | 前 16 笔被接受；第 17 笔在前 16 笔 active 时不能被接受；释放任意一笔后，第 17 笔恢复前进；response 总数精确、无串 ID。 | 这是原 P4 漏掉的真实设计点，必须补入；否则 `S_ACCEPT` 参数基本没有 directed coverage。 |
| `tc_issue_limit_write` | 属于 `axicb_limit_guard_vseq`。在同一 downstream 上累计 4 个 active write 后继续发第 5 个。为避免与 `S_THREADS` 冲突，可采用 `m0` 两笔 + `m1` 两笔的组合，再由任一 master 发第 5 笔。 | `axi_crossbar_wr.v` 每个 downstream 的 `trans_limit`，即 `M_ISSUE=4` 的写方向实现。 | 前 4 笔被 downstream 接收且 outstanding；第 5 笔 AW 被 backpressure；任意一笔 `B` 完成后，第 5 笔恢复；无写数据串流、无丢失。 | write/read 的 `M_ISSUE` 是两套独立 RTL，不能只测一个方向。 |
| `tc_issue_limit_read` | 属于 `axicb_limit_guard_vseq`。在同一 downstream 上累计 4 个 active read 后继续发第 5 个，组织方式与 write limit 类似。 | `axi_crossbar_rd.v` 每个 downstream 的 `trans_limit`，即 `M_ISSUE=4` 的读方向实现。 | 前 4 笔被接受；第 5 笔 AR 被 backpressure；任意一笔 read 在 `RLAST` 完成后，第 5 笔继续；无 response 丢失、无错误提前完成。 | 这是 read 独有实现，不能被 write limit case 替代。 |

#### 前置条件

- route-aware scoreboard 已稳定；
- downstream monitor 已接入 scoreboard/coverage，且能区分 `upstream request / downstream accept / upstream response`；
- slave responder 具备可编程 hold/release 能力，至少能对指定 downstream 的 B/R response 制造可重复的 overlap 窗口；
- nonblocking response collection 可用，且 same-master multi-outstanding case 不依赖 sequence 返回顺序；
- 已具备 address-blocked window checker 与 W interleave checker；
- P2 的 DECERR no-leak checker 可被 P4 legal+illegal overlap 复用。

#### 退出条件

- `axi_crossbar_addr.v` 中 same-ID same-destination allow、same-ID different-destination block、thread full、accept full 四类关键分支均有 directed hit；
- `axi_crossbar_wr.v` 中 same-slave AW arb、W channel lock、B legal-legal arb、B legal-DECERR arb、write `M_ISSUE` limit 均有 directed hit；
- `axi_crossbar_rd.v` 中 same-slave AR arb、R legal-legal arb、R legal-DECERR arb、`RLAST`-based completion、read `M_ISSUE` limit 均有 directed hit；
- 所有限流行为都体现为 backpressure/延后接受，而不是 response 丢失、重复、串 ID 或协议 error；
- same-master multi-outstanding 场景下无死锁、无 timeout、无数据互串；
- 不保留只是在端口排列或地址取值上做表面变化、但未新增 DUT 覆盖点的冗余 testcase。

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
