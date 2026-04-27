# AXI Crossbar 验证计划 - vPlan_codex_v1

> DUT: `axi_crossbar_wrap_2x2`
>
> 当前验证环境: `uvm/` 下已有 UVM testbench、AXI VIP、scoreboard、coverage、directed vseq
>
> 核心目标: 在当前 testbench 能力基础上，重构一份可落地、少重复、强覆盖、便于验证工程师实现和维护的验证计划。

---

## 1. 总体判断

旧验证计划的问题不是“想测的东西太少”，而是“测试点拆得太碎、重复太多、vseq 粒度不合理”。

一个优秀的 crossbar 验证计划不应该把每个小现象都拆成一个独立 vseq，例如：

- 边界相邻地址单独一个 vseq；
- 随机合法地址单独一个 vseq；
- 非 0 ID 单独一个 vseq；
- DECERR 后恢复又按单拍/突发/ID 分成多个小 vseq。

这些小点当然有价值，但它们属于同一个更大的 DUT 行为族，应该被放进同一个高质量 vseq 的不同 section 中，而不是制造大量低信息密度的测试。

本计划采用以下原则：

1. **一个 vseq 对应一个 DUT 行为族，而不是一个小测试点。**
2. **每个 vseq 内部必须包含多个强相关验证点。**
3. **新增 vseq 前，必须确认现有 scoreboard/coverage 有能力观测并判错。**
4. **每推进一组同类 vseq，同步升级 scoreboard 或 coverage。**
5. **不设计当前 testbench 无法稳定落地的测试。**

---

## 2. 当前工程真实基线

本节基于当前仓库源码状态，而不是基于理想化未来环境。

### 2.1 DUT 配置

| 项目 | 当前值 | 验证含义 |
|---|---:|---|
| 上游端口 | 2 | `m0/m1`，连接 DUT `s00/s01` |
| 下游端口 | 2 | `s0/s1`，连接 DUT `m00/m01` |
| 数据宽度 | 32 bit | `WSTRB=4`，每拍 4 个 byte lane |
| 上游 ID | 8 bit | master 侧可见 ID |
| 下游 ID | 9 bit | `{src_port, upstream_id}` |
| `s0` 地址窗口 | `0x0000_0000 ~ 0x0000_FFFF` | `M00_ADDR_WIDTH=16` |
| `s1` 地址窗口 | `0x0001_0000 ~ 0x0001_FFFF` | `M01_ADDR_WIDTH=16` |
| 非法地址窗口 | `>= 0x0002_0000` | DUT 应返回 DECERR |
| `S_THREADS` | 2 / upstream port | 同一上游端口最多跟踪 2 个 active ID thread |
| `S_ACCEPT` | 16 / upstream port | 上游接收 outstanding 限制 |
| `M_ISSUE` | 4 / downstream port | 下游 issue outstanding 限制 |
| Register 配置 | S 侧多为 bypass，M 侧 AW/AR simple，W/R skid | 有 pipeline 行为，但当前 responder 延迟控制还不充分 |

### 2.2 当前已有有效 vseq/test

| test | vseq | 当前价值 | 后续策略 |
|---|---|---|---|
| `axicb_smoke_test` | `axicb_smoke_vseq` | 快速 sanity，覆盖 4 条合法路径、随机合法地址、单拍 write/read/compare | 保留为 fast gate |
| `axicb_decode_full_range_test` | `axicb_decode_full_range_vseq` | 已覆盖 `m0/m1 x s0/s1` 的 base/mid/end，且使用非 0 ID，并直接检查 downstream VIF | 保留并增强，作为合法 decode/ID directed pack 的核心 |
| `axicb_decerr_single_test` | `axicb_decerr_single_vseq` | 随机非法地址，单拍 read/write DECERR，检查下游不泄漏 | 短期保留，长期并入 DECERR robustness pack |
| `axicb_decerr_burst_test` | `axicb_decerr_burst_vseq` | 非法突发、DECERR 后合法恢复、随机合法 burst 恢复 | 短期保留，长期并入 DECERR robustness pack |
| `axicb_decerr_id_test` | `axicb_decerr_id_vseq` | 非 0 ID 覆盖合法/非法路径，覆盖多种 burst length | 短期保留，ID 检查点并入 route/DECERR 两类 pack |
| `axicb_decerr_dual_mst_test` | `axicb_decerr_dual_mst_vseq` | dual-master DECERR、legal/illegal 混合、交叉 read/write | 短期保留，长期拆入 DECERR robustness 与 concurrency pack |

### 2.3 当前 testbench 已具备能力

| 能力 | 状态 |
|---|---|
| upstream monitor | 已连接 scoreboard 和 coverage |
| downstream monitor | slave agent 内已存在，但尚未连接 scoreboard/coverage |
| sequence 控制 ID | 已支持 `awid/arid` |
| sequence 表达预期 DECERR | 已支持 `expect_decerr` |
| scoreboard 数据模型 | 支持合法 write/read compare，支持 DECERR 过滤 |
| coverage | 已有 type、burst、routing、response 基础 covergroup |
| direct downstream checker | `axicb_decode_base_vseq` 可直接看 downstream VIF，检查路由和 ID |

### 2.4 当前 testbench 的关键限制

这些限制必须直接影响验证计划的排序，否则计划会变成不可落地的愿望清单。

| 限制 | 影响 | 应对策略 |
|---|---|---|
| scoreboard beat address 当前使用低 16 bit | `s0:0x0000_0000` 和 `s1:0x0001_0000` 可能在 `ref_mem` 中别名，可能隐藏错误或制造假错误 | 立刻改成 full 32-bit aligned address |
| downstream monitor 未接入 scoreboard/coverage | 当前 route coverage 主要由 upstream 地址推断，不是真实下游观测 | 在 route-aware 阶段接入 downstream analysis port |
| `downstream_decode_checker()` 目前主要检查 downstream `BID/RID` | 对 downstream `AWID/ARID` 地址相位 ID 没有显式检查 | 在 checker 或 route scoreboard 中补 AWID/ARID 检查 |
| scoreboard/slave memory 尚未完整支持 WRAP | WRAP 测试即使跑起来也不可信 | WRAP 放到后期，先升级模型 |
| responder 缺少可编程 backpressure/delay knobs | 仲裁、公平性、limit 类测试不可稳定复现 | 在 concurrency/limit 前补 responder 延迟配置 |
| nonblocking response 收集不够完整 | outstanding 测试难以逐笔精确核对 | 依赖 monitor/scoreboard 或补 response collector |

---

## 3. 重复测试点裁剪结论

以下测试点不应该作为独立 vseq 保留。

| 原测试点 | 结论 | 具体理由 |
|---|---|---|
| `axicb_decode_boundary_test` | 合并到合法 decode pack | `0x0000_FFFC` 和 `0x0001_0000` 已是 `decode_full_range` 的核心边界点。相邻地址连续访问可以作为 section，不值得独立 vseq。 |
| `axicb_decode_random_addr_test` | 合并到 smoke 或合法 decode pack | 当前 smoke 已做随机合法地址 write/read/compare。随机合法地址如果没有真实 downstream 观测，对 decode 证明力有限。 |
| `axicb_id_nonzero_test` | 合并到合法 decode/ID pack | `decode_full_range` 已使用非 0 ID；`decerr_id_vseq` 也已覆盖非 0 ID 合法/非法路径。 |
| `id_extreme_values_test` | 合并到 ID section | `8'h00/8'hFF/中间值` 应该是一个 ID loop，不应单独成 vseq。 |
| 多个 `decerr_then_legal_*` 小测试 | 合并到 DECERR robustness pack | 恢复行为应该按状态机路径覆盖，不应按每个小 DECERR case 重复写。 |

---

## 4. 新测试架构

最终测试集合应压缩为少量高价值 pack：

| Pack | test/vseq | 目标 | 当前状态 |
|---|---|---|---|
| P0 | `axicb_smoke_test` / `axicb_smoke_vseq` | 快速 sanity gate | 已存在 |
| P1 | `axicb_route_decode_test` / `axicb_route_decode_vseq` | 合法 decode、边界、随机合法样本、非 0/极值 ID | 基于 `decode_full_range` 重构 |
| P2 | `axicb_decerr_robust_test` / `axicb_decerr_robust_vseq` | DECERR read/write/burst/no-leak/recovery/ID | 由现有 DECERR vseq 合并演进 |
| P3 | `axicb_burst_data_test` / `axicb_burst_data_vseq` | INCR/FIXED/narrow/unaligned/WSTRB 数据完整性 | 新增，依赖 scoreboard 修正 |
| P4 | `axicb_concurrency_order_test` / `axicb_concurrency_order_vseq` | 并发、仲裁、ID ordering、thread/issue limit | 新增，依赖 responder delay 和 route scoreboard |
| P5 | `axicb_backpressure_reset_test` / `axicb_backpressure_reset_vseq` | backpressure/reset 鲁棒性 | 新增，后期 |
| P6 | `axicb_random_regress_test` / `axicb_random_regress_vseq` | 随机收敛 | 最后阶段 |

---

## 5. 基础设施路线

## I0 - 立即修正 scoreboard 基础模型

这是后续所有 decode/random/burst 测试的前置条件。

### I0.1 full address ref_mem

当前 scoreboard 中存在地址截断风险：

```systemverilog
word_addr = {addr[15:2], 2'b00};
```

应改为：

```systemverilog
word_addr = {addr[ADDR_WIDTH-1:2], 2'b00};
```

同时：

- `calculate_beat_addr()` 返回值从 `bit [15:0]` 改成 `bit [ADDR_WIDTH-1:0]`；
- `ref_mem` 继续使用 full address 作为 key；
- 避免 `s0` 与 `s1` 相同 offset 的地址互相覆盖。

### I0.2 保持 DECERR 不污染 ref_mem

当前 DECERR early return 是正确方向，应继续保留：

- illegal write: 检查 `BRESP=DECERR` 后直接 return，不写 `ref_mem`；
- illegal read: 检查所有 `RRESP=DECERR` 后 return，不做 data compare。

建议补强：

- read DECERR beat count 等于 `ARLEN+1`；
- 最后一拍 `RLAST=1`；
- 每拍 `RID=ARID`。

### I0.3 scoreboard 层增加 upstream ID 检查

当前很多 ID 检查写在 vseq helper 中，后续应下沉到 scoreboard：

- write: `BID == AWID`
- read: `RID == ARID`

这样所有 vseq 都自动受益。

---

## I1 - 接入 downstream monitor，建立 route-aware scoreboard

当前 downstream monitor 已经存在于 `axi_slave_agent`，但没有接入 env 的 scoreboard/coverage。

下一步应新增：

- `slv_agent00.item_collected_port -> scb`
- `slv_agent01.item_collected_port -> scb`
- `slv_agent00.item_collected_port -> cov`
- `slv_agent01.item_collected_port -> cov`

scoreboard 需要区分四类输入：

| 输入 | 含义 |
|---|---|
| upstream m0 | master0 看到的请求/响应 |
| upstream m1 | master1 看到的请求/响应 |
| downstream s0 | 实际到达 slave0 的事务 |
| downstream s1 | 实际到达 slave1 的事务 |

route-aware scoreboard 的基本检查：

1. upstream 地址预测目标端口：
   - `0x0000_0000 ~ 0x0000_FFFF -> s0`
   - `0x0001_0000 ~ 0x0001_FFFF -> s1`
   - 其他地址 -> DECERR
2. legal request 必须只出现在预测 downstream 端口；
3. illegal request 不允许出现在任何 downstream 端口；
4. downstream ID 必须为 `{src_master_idx, upstream_id}`；
5. response 回到 upstream 后 ID 必须还原。

---

## I2 - coverage 模型重构

coverage 不应服务于“有多少个 testcase”，而应服务于“DUT 行为有没有被覆盖”。

| covergroup | coverpoint / cross |
|---|---|
| `cg_route` | `src_master x dst_slave x txn_type` |
| `cg_addr_bucket` | `s0_base/s0_mid/s0_end/s1_base/s1_mid/s1_end/illegal` |
| `cg_boundary` | `last_s0=0x0000_FFFC`，`first_s1=0x0001_0000` |
| `cg_id` | `id_zero/id_nonzero/id_max x src_master x downstream_id_msb` |
| `cg_resp` | `OKAY/DECERR x READ/WRITE x legal/illegal` |
| `cg_burst` | `burst_type x burst_len_bucket x burst_size` |
| `cg_wstrb_lane` | full/single-lane/sparse/zero-if-supported |
| `cg_concurrency` | diff-slave parallel/same-slave contention/same-ID-same-dst/same-ID-diff-dst |
| `cg_recovery` | DECERR-then-legal/reset-then-legal/backpressure-then-legal |

---

## I3 - responder delay 与 outstanding 支撑

在 P4/P5 前需要新增 responder 可控延迟：

- AWREADY delay
- WREADY delay
- BVALID delay
- ARREADY delay
- RVALID delay

否则仲裁、公平性、thread limit、issue limit 这类测试很难稳定复现。

同时需要明确 nonblocking response 的检查方式：

- 要么完全依赖 monitor + scoreboard；
- 要么在 vseq 层建立 response collector；
- 不允许依赖固定 `wait_cycles()` 后“猜测”事务完成。

---

## 6. Test Pack 详细设计

## P0 - Smoke Gate

### 当前 test/vseq

- `axicb_smoke_test`
- `axicb_smoke_vseq`

### 验证目标

快速确认环境能跑、四条合法路径能通、基础数据读回正确。

### 覆盖内容

- `m0 -> s0`
- `m0 -> s1`
- `m1 -> s0`
- `m1 -> s1`
- 单拍 `INCR`
- 4B aligned
- `WSTRB=4'hF`
- write -> read -> compare

### 退出条件

- 无 UVM ERROR/FATAL；
- `scb.check_count > 0`；
- `scb.error_count == 0`；
- 基础 route bins 至少命中四条合法路径。

---

## P1 - Legal Route / Decode / ID Pack

### 建议 test/vseq

- `axicb_route_decode_test`
- `axicb_route_decode_vseq`

当前可以先由 `axicb_decode_full_range_vseq` 承担此角色，再逐步改名或重构。

### 替代的旧测试点

本 pack 覆盖并替代：

- test2-1: `decode_full_range`
- test2-2: `decode_boundary`
- test2-3: `decode_random_addr`
- test2-4: `id_nonzero`

### Section 设计

| section | 激励 | 检查 |
|---|---|---|
| full-range directed | `m0/m1` 分别访问 `s0:{base,mid,end}` 和 `s1:{base,mid,end}` | downstream port 正确，地址不变，OKAY response，readback 正确 |
| boundary adjacency | 连续访问 `0x0000_FFFC` 和 `0x0001_0000` | 低侧进 `s0`，高侧进 `s1`，数据不混淆 |
| legal random sample | 20~100 个合法 aligned 地址，分布到 `s0/s1` | route prediction 与实际 route 一致，data compare |
| nonzero ID | 使用 `8'h55/8'hAA/8'hFF` 等 ID | upstream response ID 正确还原 |
| same upstream ID from both masters | m0/m1 都使用 `8'hAB` | downstream ID 分别为 `9'h0AB/9'h1AB` |

### 实现建议

避免继续 copy-paste `mx_s0_decode_test()` / `mx_s1_decode_test()`，统一成 helper：

```systemverilog
run_write_read_compare(master_idx, addr, id, data);
run_access(master_idx, txn_type, addr, id, data);
```

同时增强当前 `downstream_decode_checker()`：

```systemverilog
// AW handshake 后
if (vif_slv.awid !== expected_id)
    `uvm_error(...);

// AR handshake 后
if (vif_slv.arid !== expected_id)
    `uvm_error(...);
```

### 退出条件

- `src_master x dst_slave x txn_type = 8/8`；
- `0x0000_FFFC -> s0` 命中；
- `0x0001_0000 -> s1` 命中；
- ID zero/nonzero/max 命中；
- downstream ID MSB 对 m0/m1 区分正确；
- `s0/s1` 相同 offset 不发生 scoreboard alias。

---

## P2 - DECERR Robustness Pack

### 建议 test/vseq

- `axicb_decerr_robust_test`
- `axicb_decerr_robust_vseq`

现有四个 DECERR vseq 可以短期保留，但长期应合并成一个错误路径鲁棒性 pack。

### Section 设计

| section | 激励 | 检查 |
|---|---|---|
| illegal write single | `m0/m1` 写非法地址 | `BRESP=DECERR`，`BID=AWID`，无 downstream AW/W 泄漏 |
| illegal read single | `m0/m1` 读非法地址 | 1 拍 `RRESP=DECERR`，`RID=ARID`，`RLAST=1`，无 downstream AR 泄漏 |
| illegal burst write | 2/4/8/16-beat illegal write | W beats 被接收/丢弃，最终 1 个 DECERR B，无下游泄漏 |
| illegal burst read | 2/4/8/16-beat illegal read | 精确 `ARLEN+1` 拍 DECERR，最后一拍 `RLAST=1` |
| DECERR recovery | illegal 后立即 legal write/read | legal 路径恢复，data compare 正确，`ref_mem` 不被非法事务污染 |
| mixed legal/illegal dual master | 一个 master illegal，另一个 legal | illegal 隔离，legal 不受影响 |
| DECERR ID | 非 0 ID 走 illegal path | DECERR response ID 正确还原 |

### 退出条件

- `WRITE x DECERR` 和 `READ x DECERR` bins 命中；
- illegal request 不出现在任何 downstream port；
- DECERR read beat count 正确；
- DECERR 后同 ID legal transaction 不被卡死；
- legal recovery data compare 通过。

---

## P3 - Burst / Byte-Lane Data Pack

### 建议 test/vseq

- `axicb_burst_data_test`
- `axicb_burst_data_vseq`

### 验证目标

验证合法路由场景下的数据通路与 beat/lane 语义，而不是重复地址 decode。

| section | 激励 | 检查 |
|---|---|---|
| INCR burst | 1/2/4/8/16 beats，覆盖 `m0/m1 x s0/s1` | 所有 beat 数据读回一致，W channel 不跨 slave |
| long INCR smoke | 稳定后加入 32/64/128/256 beats 中少量 case | 长 burst 期间 W route 锁定到同一 downstream |
| FIXED burst | 4/8 beat FIXED write/read | 多 beat 写同一地址，最终读回符合模型 |
| WSTRB partial | full/low-byte/high-byte/sparse masks | byte merge 正确 |
| narrow size | 1B/2B/4B | byte lane 与地址推进正确 |
| unaligned INCR | 合法未对齐起始地址 | 首拍地址和后续 aligned 地址符合模型 |

### 前置条件

- scoreboard full-address 修正完成；
- scoreboard 和 `axi_slave_mem` 的 beat address 计算通过 review；
- WRAP 暂不进入此 pack，直到模型支持。

### 退出条件

- `cg_burst` 覆盖 INCR/FIXED 与 1/2/4/8/16 beat；
- `cg_wstrb_lane` 关键 bins 命中；
- 多 beat readback 无 mismatch。

---

## P4 - Concurrency / Ordering / Limit Pack

### 建议 test/vseq

- `axicb_concurrency_order_test`
- `axicb_concurrency_order_vseq`

### 验证目标

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

### 前置条件

- route-aware scoreboard 已稳定；
- responder delay knobs 可用；
- nonblocking response collection 可用。

### 退出条件

- 并发下无数据互串；
- 同 ID ordering 行为符合 `axi_crossbar_addr` thread tracking；
- limit 行为体现为 backpressure，而不是协议错误或数据丢失。

---

## P5 - Backpressure / Reset Pack

### 建议 test/vseq

- `axicb_backpressure_reset_test`
- `axicb_backpressure_reset_vseq`

### 验证目标

| section | 激励 | 检查 |
|---|---|---|
| downstream AW/AR backpressure | 延迟某个 downstream `awready/arready` | upstream valid/data 稳定，无 route 丢失 |
| W channel stall | burst 中间延迟 `wready` | WDATA/WSTRB/WLAST 稳定且顺序正确 |
| B/R response delay | 延迟 `bvalid/rvalid` | response 回到正确 upstream |
| reset idle | idle 时 reset | 所有接口回到 reset 状态 |
| reset mid-write | AW 后或 W burst 中 reset | 无 stale B，reset 后 legal transaction 正常 |
| reset mid-read | AR 后或 R burst 中 reset | 无 stale R，reset 后 legal transaction 正常 |

### 前置条件

- responder delay knobs；
- scoreboard reset flush 策略；
- monitor partial transaction 处理通过 review。

---

## P6 - Random Regression Pack

### 建议 test/vseq

- `axicb_random_regress_test`
- `axicb_random_regress_vseq`

### 进入条件

只有 P1~P5 的 directed pack 都稳定后，random 才有意义。

### 随机空间

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

### 退出条件

- 多 seed 无 UVM ERROR/FATAL；
- coverage 达到目标阈值；
- 任何随机失败都能用 seed 复现，并能归类到某个 directed gap。

---

## 7. Regression 分层

### 7.1 当前 fast gate

适合每次小改后快速跑：

```text
smoke
decode_full_range
```

### 7.2 当前 practical regression

适合修改 route/DECERR/scoreboard 后跑：

```text
smoke
decode_full_range
decerr_single
decerr_burst
decerr_id
decerr_dual_mst
```

### 7.3 目标 regression

完成计划重构后的目标形态：

```text
smoke
route_decode
decerr_robust
burst_data
concurrency_order
backpressure_reset
random_regress SEED=<N>
```

---

## 8. 覆盖率关闭目标

| Feature | 关闭标准 |
|---|---|
| legal route | `m0/m1 x s0/s1 x read/write = 8/8` |
| boundary | `0x0000_FFFC -> s0`，`0x0001_0000 -> s1` |
| address class | base/mid/end/random/illegal |
| response | OKAY read/write，DECERR read/write |
| ID | zero/nonzero/max，m0/m1，downstream MSB 0/1 |
| burst | INCR/FIXED，1/2/4/8/16 beats |
| byte lane | full/single/sparse WSTRB |
| concurrency | diff-slave parallel，same-slave contention，same-ID cases |
| recovery | DECERR 后恢复，reset 后恢复，backpressure 后恢复 |

---

## 9. 推荐下一步实施顺序

从当前工程状态出发，建议按以下顺序推进：

1. 修正 scoreboard full-address 建模。
2. 在 `downstream_decode_checker()` 中补 AWID/ARID 检查。
3. 将当前 `decode_full_range` 重构为 P1 的核心 vseq：
   - full-range directed；
   - boundary adjacency；
   - nonzero/extreme ID；
   - 少量 legal random sample。
4. 接入 downstream monitor 到 scoreboard/coverage。
5. 将现有 DECERR vseq 逐步合并成 P2 的 `decerr_robust`。
6. route/DECERR 稳定后，再开发 burst/lane pack。
7. responder delay knobs 完成后，再做 concurrency/order/limit。
8. reset/backpressure 和 random regression 放到最后。

---

## 10. 最终判定规则

以后新增 vseq 前，必须满足三个条件：

1. 它验证的是一个独立 DUT 机制；
2. 它内部包含一组强相关验证点；
3. 当前 scoreboard/coverage 能够稳定观测并判错。

按这个规则：

- `decode_boundary` 单独存在太小；
- `decode_random_addr` 单独存在太弱；
- `id_nonzero` 单独存在重复；
- 把它们合并进 `route_decode_vseq` 才是高质量设计。

这份计划的目标不是单纯减少测试数量，而是减少低价值重复，让每个 vseq 都能精准击中一类真实 DUT 风险。

