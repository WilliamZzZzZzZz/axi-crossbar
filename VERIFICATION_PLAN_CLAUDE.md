# AXI4 2×2 Non-blocking Crossbar — 验证计划 (Verification Plan) v2

> **DUT**: `axi_crossbar_wrap_2x2`（源自 Alex Forencich verilog-axi）
> **方法学**: UVM 1.2 | **仿真器**: VCS
> **配置**: 2 Slave IF × 2 Master IF, DATA_WIDTH=32, ADDR_WIDTH=32, S_ID_WIDTH=8, M_ID_WIDTH=9
> **地址映射**: M00 = `0x0000_0000` ~ `0x0000_FFFF` (64KB), M01 = `0x0001_0000` ~ `0x0001_FFFF` (64KB)
> **日期**: 2026-04-18

---

## 一、验证特性提取 (Feature Extraction)

### 1.1 DUT 实例化参数一览

| 参数 | 值 | 验证含义 |
|---|---|---|
| `S_COUNT` / `M_COUNT` | 2 / 2 | 4 条路由路径 (m0→s0, m0→s1, m1→s0, m1→s1) |
| `DATA_WIDTH` | 32 | STRB_WIDTH=4, 每拍最大 4 字节 |
| `ADDR_WIDTH` | 32 | 地址解码在 `[31:16]` 区分 slave |
| `S_ID_WIDTH` / `M_ID_WIDTH` | 8 / 9 | ID 扩展：downstream `[8]=源 Slave 端口`, `[7:0]=原始 ID` |
| `M00_BASE_ADDR` / `M00_ADDR_WIDTH` | `32'h0000_0000` / 16 | Slave0 解码空间 `0x0000_0000 ~ 0x0000_FFFF` |
| `M01_BASE_ADDR` / `M01_ADDR_WIDTH` | `32'h0001_0000` / 16 | Slave1 解码空间 `0x0001_0000 ~ 0x0001_FFFF` |
| `S00/S01_THREADS` | 2 | 每个上游 Slave 接口最多同时跟踪 2 个唯一 ID（Transaction Ordering Protection） |
| `S00/S01_ACCEPT` | 16 | 每个上游 Slave 接口最大 16 并发 outstanding 事务 |
| `M00/M01_ISSUE` | 4 | 每个下游 Master 接口最大 4 并发 outstanding 事务 |
| `M00/M01_CONNECT_READ/WRITE` | `2'b11` | 全互连——两个 master 均可访问所有 slave |
| `M00/M01_SECURE` | 0 | 不启用安全保护过滤 |

### 1.2 Pipeline Register 配置

| 通道 | S-side (输入侧) | M-side (输出侧) | 验证影响 |
|---|---|---|---|
| AW | 0 (bypass) | 1 (simple buffer) | M 侧 AW 有一拍延迟，simple buffer 存在气泡周期 |
| W  | 0 (bypass) | 2 (skid buffer) | M 侧 W 有 skid buffer，保证无气泡吞吐 |
| B  | 1 (simple buffer) | 0 (bypass) | S 侧 B 有一拍延迟 |
| AR | 0 (bypass) | 1 (simple buffer) | M 侧 AR 有一拍延迟 |
| R  | 2 (skid buffer) | 0 (bypass) | S 侧 R 有 skid buffer |

### 1.3 协议特性 (AXI4 Protocol Features)

| 编号 | 特性 | 描述 | RTL 行为 |
|---|---|---|---|
| F-P01 | Burst 类型 | FIXED / INCR / WRAP | 透传，crossbar 不做 burst 转换/分割/合并 |
| F-P02 | Burst 长度 | `awlen`/`arlen` = 0~255 | 透传；DECERR 时读通道需生成 `len+1` 拍响应 |
| F-P03 | Burst 大小 | `awsize`/`arsize` ≤ `$clog2(DATA_WIDTH/8)` = 2 (4B) | 支持 narrow transfer (1B/2B) |
| F-P04 | WSTRB | 4-bit 写字节使能 | 透传至 slave；DECERR 路径中被 `w_drop_reg` 吞掉 |
| F-P05 | WLAST | 写突发末拍标记 | S 侧 `w_select_valid_reg` 在 `wlast & wready` 时释放，结束当前 W 路由 |
| F-P06 | RLAST | 读突发末拍标记 | R 响应仲裁在 `rlast & rready & rvalid` 时 acknowledge，释放 grant |
| F-P07 | BRESP / RRESP | 2-bit 响应码 | crossbar 地址无匹配时自行生成 DECERR(`2'b11`)；正常时透传下游 slave 响应 |
| F-P08 | LOCK / CACHE / PROT | 控制信号 | 透传不处理（M_SECURE=0 时不检查 PROT[1]） |
| F-P09 | QOS / REGION / USER | 边带信号 | QOS 不参与仲裁，REGION 由地址解码模块根据匹配区域生成，USER 在当前配置下 disable |

### 1.4 Crossbar 微架构特性 (Micro-architectural Features)

| 编号 | 特性 | RTL 实现 | 验证策略 |
|---|---|---|---|
| F-M01 | 读写物理分离 | `axi_crossbar_rd` 与 `axi_crossbar_wr` 完全独立实例 | 同时发送读写事务至不同目标，验证互不阻塞 |
| F-M02 | 地址译码 | `axi_crossbar_addr`: `addr >> M_ADDR_WIDTH == base >> M_ADDR_WIDTH` | 遍历 {基址, 中间, 末尾, 跨界, 非法} 地址 |
| F-M03 | DECERR 生成 (写) | `match=0` → `m_wc_decerr=1`, `w_drop_reg=1` 吞掉全部 W beats, 仲裁虚端口 `M_COUNT` 返回 `bresp=2'b11` | 非法地址写：验证 BRESP=DECERR，W 数据不泄漏到任何 slave |
| F-M04 | DECERR 生成 (读) | `match=0` → `decerr_len_reg` 计数器产生 `len+1` 拍 `rresp=2'b11`, 最后一拍 `rlast=1` | 非法地址读：验证 RRESP=DECERR 拍数 = `arlen+1` |
| F-M05 | ID 位宽扩展 | `m_axi_id = {source_slave_port[$clog2(S_COUNT)-1:0], upstream_id[S_ID_WIDTH-1:0]}` | 监控 downstream ID，验证 `id[8]` 对应源 master 编号 |
| F-M06 | ID 还原与响应路由 | B/R 响应的 `id >> S_ID_WIDTH` 提取源 Slave 端口号 → MUX 回原 master | 两 master 同 ID 并发，验证响应不混淆 |
| F-M07 | Thread Tracking | `thread_id_reg[S_THREADS-1:0]`/`thread_m_reg`/`thread_count_reg`：同 ID 必须路由到同一 destination | 同 ID 发往不同 slave → 第二笔被阻塞直到第一笔完成 |
| F-M08 | Thread 限制 | `S_THREADS=2`：最多 2 个活跃唯一 ID 同时在飞 | 3 个不同 ID 连发 → 第 3 个 ID 被阻塞 |
| F-M09 | Accept 限制 | `trans_count_reg` ≤ `S_ACCEPT=16` | 大量 outstanding 事务 → 验证不超限 |
| F-M10 | Issue 限制 | M 侧 `trans_count_reg` ≤ `M_ISSUE=4` | 超过 4 笔 outstanding → 被背压 |
| F-M11 | 地址仲裁 (AW/AR) | Round-Robin, `ARB_BLOCK=1, ARB_BLOCK_ACK=1, LSB_HIGH_PRIORITY=1` | 两 master 同时竞争同一 slave → 轮转公平性验证 |
| F-M12 | 响应仲裁 (B/R) | Round-Robin, 端口数 = `M_COUNT+1` (含 DECERR 虚端口) | DECERR 响应与正常 slave 响应同时就绪 → 仲裁行为 |
| F-M13 | W 通道路由 (S 侧) | AW 解码 → `w_select_reg` 锁存 → W beats 全部路由到同一 M 端口 → `wlast` 释放 | 多拍 write 中途不能被截断/混淆 |
| F-M14 | W 通道路由 (M 侧) | AW 仲裁赢得 → `w_select_reg` 锁存 → W beats 接收 → `wlast` 释放 → 新 AW 才能被仲裁 | AW 仲裁条件包含 `!w_select_valid_next`，验证 pipeline 行为 |
| F-M15 | Pipeline Register | bypass(0)/simple(1)/skid(2) 三模式 | simple buffer 气泡 vs skid buffer 无气泡，通过高吞吐场景观察 |

---

## 二、Testbench 基线现状 (Baseline Assessment)

### 2.1 当前 TB 能力

| 能力 | 状态 | 细节 |
|---|---|---|
| 4 路基础路由 | ✅ | Smoke test 串行覆盖 m0→s0, m0→s1, m1→s0, m1→s1 |
| 单拍 write-then-read | ✅ | INCR / SIZE_4BYTES / WSTRB=4'hF |
| Scoreboard 数据完整性 | ✅ | ref_mem 关联数组，INCR/FIXED 地址计算 |
| SVA 信号稳定性 | ✅ | 5 条握手稳定性断言（valid&&!ready |=> valid_stable）绑定在 axi_if |
| 基础 Covergroup | ✅ | cg_trans_type (W/R) + cg_burst (type×len, type×size) |
| Pipeline 非阻塞 | ✅ | `wait_for_response=0` 已支持 |
| Monitor 双侧 ID | ✅ | upstream 8-bit / downstream 9-bit 参数化 |

### 2.2 当前已知缺陷与限制

| 缺陷 | 影响 | 修复时机 |
|---|---|---|
| 所有事务 `tr_id=0` | 无法测试多 ID / 乱序 / thread tracking | Milestone 1 |
| Element sequence 未暴露 `tr_id` | Virtual sequence 无法控制 ID | Milestone 1 |
| 仅串行执行，无 fork 并发 | 未验证非阻塞并行 / 仲裁 | Milestone 2 |
| 无 DECERR 测试（无非法地址） | crossbar 错误路径未覆盖 | Milestone 1 |
| VIP 对 non-OKAY resp 打 uvm_error | DECERR 测试会误报 | Milestone 1 |
| Scoreboard 不过滤 DECERR 事务 | DECERR 写入 ref_mem 导致比对错误 | Milestone 1 |
| Scoreboard 不支持 WRAP 地址 | WRAP burst 测试前置条件不满足 | Milestone 3 |
| Slave mem 不支持 WRAP 地址 | 同上 | Milestone 3 |
| `cg_comprehensive` 未实例化 | 死代码，覆盖率缺失 | Milestone 1 |
| 无路由/端口覆盖 | 不知道哪些路径被覆盖 | Milestone 1 |
| 无 response 类型覆盖 | 不知道 DECERR bins 是否命中 | Milestone 1 |
| Slave responder 无延迟旋钮 | 无法注入 backpressure | Milestone 4 |
| `compare_single_data()` 有 bug | `return 1` 在 uvm_info 之前，后续不可达 | Milestone 1 |
| `BURST_LEN_16BEATS` 枚举值=0x11=17 | 实际是 18 拍而非 16 拍 | Milestone 3 |
| axiram_* 基类缺失且已注释 | 这些测试不可编译 | 不修复，重写 |

---

## 三、渐进式里程碑 (Progressive Milestones)

### 总体路线图

```
Milestone 0: 基础设施修复与升级    ← 零新 Test，纯修 bug + 补接口
     │
Milestone 1: DECERR 错误路径       ← crossbar 独有特性，最小代码改动
     │
Milestone 2: ID 路由 + 基础并发    ← crossbar 核心路由验证
     │
Milestone 3: Burst 全类型          ← AXI4 协议完整性
     │
Milestone 4: 深度并发 + 仲裁       ← 压力与竞争场景
     │
Milestone 5: Backpressure + Reset  ← 鲁棒性与边界
     │
Milestone 6: 随机回归 + 覆盖率收敛 ← 收官
```

---

### Milestone 0: 基础设施修复与升级

**进入条件**: Smoke test 已通过（当前基线满足）
**退出条件**: 全部基础设施改动完成，Smoke test 回归通过

本阶段不新增任何 Test，只修复 bug、扩展接口、升级 Scoreboard 和 Coverage，为后续所有 Milestone 铺路。

#### 0.1 Bug 修复

| 编号 | 修改项 | 文件 | 具体改动 |
|---|---|---|---|
| INF-01 | `compare_single_data()` bug | `axicb_base_virtual_sequence.sv` | 将 `return 1;` 移到函数末尾，使 uvm_info/uvm_error 可达 |
| INF-02 | `BURST_LEN_16BEATS` 枚举 | `axi_types.sv` | 将 `8'h11` 修正为 `8'h0F` (15，即 16 拍) |

#### 0.2 Element Sequence 接口扩展

| 编号 | 修改项 | 文件 | 具体改动 |
|---|---|---|---|
| INF-03 | 暴露 `tr_id` 字段 | `axicb_single_write_sequence.sv` | 新增 `bit [7:0] tr_id = 0` 字段，在 `body()` 中传递给 `axi_master_single_sequence.tr_id` |
| INF-04 | 暴露 `tr_id` 字段 | `axicb_single_read_sequence.sv` | 同上 |
| INF-05 | `expect_decerr` 开关 | `axi_master_single_sequence.sv` | 新增 `bit expect_decerr = 0`；当 `expect_decerr=1` 时，`do_write()` 对 `bresp!=OKAY` 不打 uvm_error（因为 DECERR 是预期的），同理 `do_read()` 对 `rresp` 中包含 DECERR 不打 uvm_error |
| INF-06 | 暴露 `expect_decerr` | `axicb_single_write_sequence.sv` / `axicb_single_read_sequence.sv` | 新增 `bit expect_decerr = 0`，传递到 VIP 层 |

#### 0.3 Scoreboard 升级

| 编号 | 修改项 | 具体改动 |
|---|---|---|
| INF-07 | DECERR 事务过滤 | `write()` 方法中：若 `trans_type==WRITE` 检查 `bresp`；若 `trans_type==READ` 检查 `rresp[0]`。当 resp 为 DECERR (`2'b11`) 时跳过 `ref_mem` 操作，仅打 uvm_info 并递增 `decerr_count` 计数器。这防止非法地址事务污染参考模型 |
| INF-08 | 新增 `decerr_count` | 在 `report_phase` 中打印 DECERR 事务统计 |

#### 0.4 Coverage 升级 (第一批)

| 编号 | 修改项 | 具体改动 |
|---|---|---|
| INF-09 | 激活 `cg_comprehensive` | 在 `new()` 中调用 `cg_comprehensive = new()`，在 `write()` 中 sample |
| INF-10 | 新增 `cg_routing` | 新 covergroup：`cp_src_master` {m0, m1} × `cp_dst_slave` {s0, s1} × `cp_txn_type` {WRITE, READ}，交叉覆盖 `cx_routing` 产生 2×2×2 = 8 bins。slave 索引通过地址范围推断：`addr < 32'h0001_0000` → s0，否则 → s1。master 索引需新增字段（由 monitor/env 通过 config 或 transaction 扩展注入） |
| INF-11 | 新增 `cg_response` | `cp_bresp` {OKAY, DECERR} + `cp_rresp` {OKAY, DECERR}。仅在对应事务类型时 sample |
| INF-12 | `cg_burst` 补 WRAP | 在 BURST_TYPE bins 中加入 `WRAP` |

#### 0.5 回归验证

| 检查项 | 方法 |
|---|---|
| Smoke test 通过 | `make run TEST=axicb_smoke_test` |
| Scoreboard `check_count > 0`, `error_count == 0` | report_phase 输出 |
| 新 covergroup 可 sample（非空） | 仿真日志确认 `cg_routing` 至少命中 smoke test 的 4 条路径 |

---

### Milestone 1: DECERR 错误路径验证

**进入条件**: Milestone 0 全部完成（INF-01~INF-12 合入，Smoke 回归通过）
**退出条件**: 6 个 DECERR Test 全部通过；`cg_response` 的 DECERR bins 命中；Scoreboard `decerr_count > 0` 且 `error_count == 0`

**设计原理**: DECERR 是 crossbar 独有的内部逻辑（非协议透传），是与 AXI slave 验证最大的差异点。此路径涉及地址解码失败 (`match=0`)、W 通道数据丢弃 (`w_drop_reg`)、B/R 虚端口响应仲裁 (`M_COUNT` 号端口)、以及 DECERR 后状态恢复。优先验证此路径可尽早暴露地址解码和状态机 bug。

#### Test 1-1: `axicb_decerr_single_write_test`

**验证目标**: 验证写通道 DECERR 生成——地址不匹配时 crossbar 内部吞掉 W 数据并返回 BRESP=DECERR。

**Virtual Sequence**: `axicb_decerr_single_write_vseq`

**详细设计**:

| 步骤 | 信号/行为 | 具体数值 |
|---|---|---|
| 1. m0 发起 AW | `awaddr=32'h0002_0000`（超出 M00/M01 地址空间）, `awlen=0`(单拍), `awsize=SIZE_4BYTES`, `awburst=INCR`, `awid=8'h00` | 此地址 `>> 16 = 0x0002`，不等于 `M00_BASE>>16=0x0000` 也不等于 `M01_BASE>>16=0x0001` |
| 2. m0 发 W data | `wdata=32'hDEAD_BEEF`, `wstrb=4'hF`, `wlast=1` | DUT 内部 `w_drop_reg=1`，wready 由 drop 逻辑直接返回 |
| 3. 等待 B 响应 | 检查 `bresp` | 期望 `bresp == 2'b11` (DECERR) |
| 4. 检查 downstream | 监控 m00/m01 的 awvalid | 期望两个 downstream 端口 awvalid **始终为 0**——事务不应泄漏到任何 slave |

**Scoreboard 行为**: `bresp=DECERR` → 跳过 `ref_mem` 写入 → `decerr_count++`。

**Coverage 命中**: `cg_response.cp_bresp` = DECERR bin; `cg_routing.cp_src_master` = m0（dst_slave 无意义，可归入 illegal bin）。

---

#### Test 1-2: `axicb_decerr_single_read_test`

**验证目标**: 验证读通道 DECERR 生成——地址不匹配时 crossbar 用 `decerr_len_reg` 计数器生成正确拍数的 DECERR R 响应。

**Virtual Sequence**: `axicb_decerr_single_read_vseq`

**详细设计**:

| 步骤 | 信号/行为 | 具体数值 |
|---|---|---|
| 1. m0 发起 AR | `araddr=32'h0003_0000`, `arlen=0`(单拍), `arsize=SIZE_4BYTES`, `arburst=INCR`, `arid=8'h00` | |
| 2. 等待 R 响应 | 检查 `rresp`, `rlast`, 拍数 | 期望收到 **1 拍** R 数据，`rresp=2'b11`(DECERR), `rlast=1`, `rid=8'h00` |
| 3. 检查 downstream | 监控 m00/m01 的 arvalid | 期望两个 downstream arvalid **始终为 0** |

**Scoreboard 行为**: `rresp[0]=DECERR` → 跳过 `ref_mem` 比对。

---

#### Test 1-3: `axicb_decerr_burst_write_test`

**验证目标**: 验证多拍写的 DECERR 路径——`w_drop_reg` 必须吞掉所有 `awlen+1` 拍 W 数据直到 `wlast`，然后释放 W 通道路由。验证 DECERR 不阻塞后续合法事务。

**Virtual Sequence**: `axicb_decerr_burst_write_vseq`

**详细设计**:

| 步骤 | 信号/行为 | 期望 |
|---|---|---|
| 1. m0 非法写 | `awaddr=32'hFFFF_0000`, `awlen=3`(4拍), `wdata[0..3]={A,B,C,D}`, `wlast` 在第 4 拍 | DUT 内 `w_drop_reg=1`，4 拍 W 数据全被 drop |
| 2. 等 B 响应 | `bresp` | `bresp=DECERR`, `bid` 正确 |
| 3. m0 合法写 | `awaddr=32'h0000_1000`(s0 范围), `awlen=0`, `wdata=32'h1234_5678` | 验证 crossbar W 通道路由已释放，合法事务正常路由到 s0 |
| 4. m0 合法读 | `araddr=32'h0000_1000`, `arlen=0` | `rdata=32'h1234_5678`, `rresp=OKAY` |

**关键验证点**: 步骤 3 能成功说明 `w_drop_reg` 在 `wlast` 后正确释放，`w_select_valid_reg` 清零，新事务可正常进入地址解码。

---

#### Test 1-4: `axicb_decerr_burst_read_test`

**验证目标**: 验证多拍读的 DECERR 路径——`decerr_len_reg` 计数器必须精确生成 `arlen+1` 拍 RRESP=DECERR 响应，最后一拍 `rlast=1`。

**Virtual Sequence**: `axicb_decerr_burst_read_vseq`

**详细设计**:

| 步骤 | 信号/行为 | 期望 |
|---|---|---|
| 1. m1 非法读 | `araddr=32'h8000_0000`, `arlen=7`(8拍), `arsize=SIZE_4BYTES`, `arid=8'h05` | |
| 2. 等 R 响应 | 逐拍检查 | 收到 **8 拍** R 数据。`rresp[0..6]=DECERR`, `rlast[0..6]=0`; `rresp[7]=DECERR`, `rlast[7]=1`; `rid` 每拍 = `8'h05` |
| 3. 检查 downstream | m00/m01 的 arvalid | 始终为 0 |

**关键验证点**: `decerr_len_reg` 初值 = `arlen`(7)，每拍递减，到 0 时置 `rlast=1`。验证计数器精度。

---

#### Test 1-5: `axicb_decerr_then_legal_test`

**验证目标**: 验证 DECERR 后 crossbar 状态完全恢复——地址解码 FSM、thread 槽位、trans_count 均正确释放。

**Virtual Sequence**: `axicb_decerr_then_legal_vseq`

**详细设计**:

| 步骤 | 信号/行为 | 期望 |
|---|---|---|
| 1. m0 非法写 | `awaddr=32'hDEAD_0000`, `awlen=0`, `awid=8'h10` | `bresp=DECERR` |
| 2. m0 非法读 | `araddr=32'hBEEF_0000`, `arlen=3`, `arid=8'h10` | 4 拍 DECERR |
| 3. m0 合法写 s0 | `awaddr=32'h0000_2000`, `awlen=0`, `awid=8'h10`, `wdata=32'hAAAA_BBBB` | `bresp=OKAY` |
| 4. m0 合法读 s0 | `araddr=32'h0000_2000`, `arlen=0`, `arid=8'h10` | `rdata=32'hAAAA_BBBB`, `rresp=OKAY` |
| 5. m0 合法写 s1 | `awaddr=32'h0001_3000`, `awlen=0`, `awid=8'h10`, `wdata=32'hCCCC_DDDD` | `bresp=OKAY` |
| 6. m0 合法读 s1 | `araddr=32'h0001_3000`, `arlen=0`, `arid=8'h10` | `rdata=32'hCCCC_DDDD`, `rresp=OKAY` |

**关键验证点**: 步骤 3~6 使用与 DECERR 事务**相同的 ID**(`8'h10`)，验证 thread 槽在 DECERR 完成后正确释放该 ID，不会阻塞后续同 ID 事务。

---

#### Test 1-6: `axicb_decerr_both_masters_test`

**验证目标**: 验证两个 master 分别发送非法地址时，各自独立收到 DECERR，互不干扰。

**Virtual Sequence**: `axicb_decerr_both_masters_vseq`

**详细设计**:

| 步骤 | 信号/行为 | 期望 |
|---|---|---|
| 1. fork-join: m0 非法写 + m1 非法写 | m0: `awaddr=32'h0005_0000`, `awid=8'h01`; m1: `awaddr=32'h0006_0000`, `awid=8'h02` | 各自 `bresp=DECERR` |
| 2. fork-join: m0 非法读 + m1 非法读 | m0: `araddr=32'h0007_0000`, `arlen=1`(2拍), `arid=8'h01`; m1: `araddr=32'h0008_0000`, `arlen=0`(单拍), `arid=8'h02` | m0 收 2 拍 DECERR; m1 收 1 拍 DECERR |
| 3. m0 合法写读 s0 | `addr=32'h0000_4000` | 数据正确，OKAY |
| 4. m1 合法写读 s1 | `addr=32'h0001_4000` | 数据正确，OKAY |

**关键验证点**: 步骤 1 中 m0 和 m1 **并行 fork**——这是本验证计划中首次出现并发场景。由于两个 master 的 DECERR 路径完全独立（各自的 `s_ifaces` 内部处理），不存在仲裁竞争。步骤 3-4 验证状态恢复。

---

#### 【基础设施同步升级 — Milestone 1 出口检查】

**Scoreboard 验证**:
- `decerr_count` ≥ 6（至少 6 笔 DECERR 事务被正确过滤）
- `error_count == 0`（合法事务数据比对无误）
- `check_count > 0`（合法事务被正确检查）

**Coverage 验证**:

| Covergroup | 期望命中 |
|---|---|
| `cg_response.cp_bresp` | OKAY bin ✅ + DECERR bin ✅ |
| `cg_response.cp_rresp` | OKAY bin ✅ + DECERR bin ✅ |
| `cg_routing.cx_routing` | 新增 m0→s0, m0→s1, m1→s0, m1→s1 合法路径（从 Test 1-5/1-6 的合法事务命中） |
| `cg_burst` | 已有 bins 继续命中，无新增需求 |

---

### Milestone 2: ID 路由与基础并发

**进入条件**: Milestone 1 全部通过
**退出条件**: 9 个 Test 全部通过；`cg_id` 的极值 bins 命中；双 master 并行场景下 Scoreboard `error_count==0`

**设计原理**: ID 扩展 (8→9 bit) 和 ID 还原是 crossbar 路由正确性的核心。thread tracking (ordering protection) 是防止数据混淆的关键微架构。本阶段先验证 ID 路由正确性，再引入基础并发以验证非阻塞特性。

#### 2.A — 地址解码完整性 (3 Tests)

##### Test 2-1: `axicb_decode_full_range_test`

**验证目标**: 遍历两个 slave 地址空间的关键点——基址、中间、末尾——验证地址解码的边界正确性。

**Virtual Sequence**: `axicb_decode_full_range_vseq`

**详细设计**:

| 步骤 | Master | 地址 | Slave | 具体值 |
|---|---|---|---|---|
| 1 | m0 | s0 基址 | s0 | `awaddr=32'h0000_0000` |
| 2 | m0 | s0 中间 | s0 | `awaddr=32'h0000_8000` |
| 3 | m0 | s0 末尾 | s0 | `awaddr=32'h0000_FFFC`（最后一个 4B 对齐字） |
| 4 | m0 | s1 基址 | s1 | `awaddr=32'h0001_0000` |
| 5 | m0 | s1 中间 | s1 | `awaddr=32'h0001_8000` |
| 6 | m0 | s1 末尾 | s1 | `awaddr=32'h0001_FFFC` |
| 7~12 | m1 | 重复 1~6 | — | 验证 m1 也能正确路由到两个 slave |

每个地址点：write 单拍 → read 单拍 → compare data。

**关键验证点**: `awaddr=32'h0000_FFFC` 的解码结果为 s0 (因为 `0x0000_FFFC >> 16 == 0x0000 == M00_BASE >> 16`)。`awaddr=32'h0001_0000` 解码为 s1。这两个地址是解码边界的分界点。

---

##### Test 2-2: `axicb_decode_boundary_test`

**验证目标**: 在 slave0/slave1 地址空间的分界处连续发送事务，验证相邻地址不会路由错误。

**Virtual Sequence**: `axicb_decode_boundary_vseq`

**详细设计**:

| 步骤 | 地址 | 期望 slave | 数据 |
|---|---|---|---|
| 1. m0 写 | `32'h0000_FFFC` | s0 | `32'hAAAA_0001` |
| 2. m0 写 | `32'h0001_0000` | s1 | `32'hBBBB_0002` |
| 3. m0 读 | `32'h0000_FFFC` | s0 | 期望 `32'hAAAA_0001` |
| 4. m0 读 | `32'h0001_0000` | s1 | 期望 `32'hBBBB_0002` |
| 5. m0 写 | `32'h0000_FFF8` | s0 | `32'hCCCC_0003` |
| 6. m0 写 | `32'h0001_0004` | s1 | `32'hDDDD_0004` |
| 7~8 | m0 读 | 对应地址 | compare |

**关键验证点**: 步骤 1-2 的地址仅差 4 字节但路由到不同 slave，验证解码不会因地址接近而混淆。

---

##### Test 2-3: `axicb_decode_random_addr_test`

**验证目标**: 大量随机地址事务覆盖地址空间。

**Virtual Sequence**: `axicb_decode_random_addr_vseq`

**详细设计**:

```
repeat (100) begin
  randomize addr with {
    addr[31:16] inside {16'h0000, 16'h0001};  // 仅合法范围
    addr[1:0] == 2'b00;                        // 4B 对齐
  };
  randomize master_idx with { master_idx inside {0, 1}; };
  write(master_idx, addr, random_data);
  read(master_idx, addr);
  compare;
end
```

---

#### 2.B — ID 路由与扩展 (4 Tests)

##### Test 2-4: `axicb_id_nonzero_test`

**验证目标**: 验证非零 ID 的端到端传递——upstream `awid`/`arid` 经扩展后到达 downstream，response 返回时 ID 正确还原。

**Virtual Sequence**: `axicb_id_nonzero_vseq`

**详细设计**:

| 步骤 | Master | ID | 地址 | 验证 |
|---|---|---|---|---|
| 1. m0 写 s0 | m0 | `awid=8'hAB` | `32'h0000_5000` | upstream monitor 捕获 `awid=8'hAB`; downstream monitor 捕获 `m_awid=9'h0AB`（`[8]=0` 因为 m0 是 Slave 端口 0） |
| 2. m0 读 s0 | m0 | `arid=8'hAB` | `32'h0000_5000` | upstream `rid=8'hAB` |
| 3. m1 写 s0 | m1 | `awid=8'hAB` | `32'h0000_6000` | downstream `m_awid=9'h1AB`（`[8]=1` 因为 m1 是 Slave 端口 1） |
| 4. m1 读 s0 | m1 | `arid=8'hAB` | `32'h0000_6000` | upstream `rid=8'hAB` |

**关键验证点**: m0 和 m1 使用**相同的 upstream ID** `8'hAB`，但 downstream ID 不同（`9'h0AB` vs `9'h1AB`）。这是 crossbar ID 扩展的核心机制——通过高位区分源端口。验证方式：在 sequence 层检查 upstream monitor 捕获的 `bid`/`rid` 等于发送时的 `awid`/`arid`。

---

##### Test 2-5: `axicb_id_extreme_values_test`

**验证目标**: ID 极值测试——`8'h00` 和 `8'hFF` 不会因位操作（移位、拼接）产生溢出或截断。

**Virtual Sequence**: `axicb_id_extreme_values_vseq`

**详细设计**:

| ID 值 | m0 downstream | m1 downstream | 验证 |
|---|---|---|---|
| `8'h00` | `9'h000` | `9'h100` | `8'h00 | (0<<8) = 9'h000`; `8'h00 | (1<<8) = 9'h100` |
| `8'hFF` | `9'h0FF` | `9'h1FF` | `8'hFF | (0<<8) = 9'h0FF`; `8'hFF | (1<<8) = 9'h1FF` |

每种组合：write → read → compare data + verify upstream response ID。

---

##### Test 2-6: `axicb_same_id_diff_master_concurrent_test`

**验证目标**: 两个 master 使用相同 upstream ID 并行发送到同一个 slave，验证 downstream ID 高位区分源端口，response 不混淆。

**Virtual Sequence**: `axicb_same_id_diff_master_concurrent_vseq`

**详细设计**:

```
fork
  begin  // m0 → s0
    write(master=0, addr=32'h0000_A000, id=8'h55, data=32'h1111_1111);
    read(master=0, addr=32'h0000_A000, id=8'h55);
    assert(rdata == 32'h1111_1111);
  end
  begin  // m1 → s0
    write(master=1, addr=32'h0000_B000, id=8'h55, data=32'h2222_2222);
    read(master=1, addr=32'h0000_B000, id=8'h55);
    assert(rdata == 32'h2222_2222);
  end
join
```

**关键验证点**: m0 和 m1 用**相同 ID `8'h55`** 同时访问 **同一个 slave s0**。在 s0 看来有两笔事务：`m_awid=9'h055`(来自 m0) 和 `m_awid=9'h155`(来自 m1)。响应返回时 crossbar 用 `bid[8]` 区分路由回哪个 master。如果 ID 扩展/还原有 bug，两个 master 会收到对方的数据。

---

##### Test 2-7: `axicb_response_route_parallel_test`

**验证目标**: 两个 master 分别访问不同 slave（m0→s0, m1→s1），并行 fork 执行多笔事务，验证 response 不会路由到错误的 master。

**Virtual Sequence**: `axicb_response_route_parallel_vseq`

**详细设计**:

```
fork
  begin  // m0 → s0: 连续 5 笔 write-then-read
    for (int i = 0; i < 5; i++) begin
      addr = 32'h0000_0100 + i*4;
      write(master=0, addr=addr, id=8'h(i), data=random);
      read(master=0, addr=addr, id=8'h(i));
      compare;
    end
  end
  begin  // m1 → s1: 连续 5 笔 write-then-read
    for (int i = 0; i < 5; i++) begin
      addr = 32'h0001_0100 + i*4;
      write(master=1, addr=addr, id=8'h(i+0x10), data=random);
      read(master=1, addr=addr, id=8'h(i+0x10));
      compare;
    end
  end
join
```

**关键验证点**: 访问不同 slave 时应完全不阻塞（F-M14: 独立 arbiter/mux），两个 fork 分支应接近同时完成。Scoreboard 通过 ref_mem 数据比对保证正确性。

---

#### 2.C — 基础 Outstanding (2 Tests)

##### Test 2-8: `axicb_outstanding_write_test`

**验证目标**: 验证单 master 使用 pipeline 模式（`wait_for_response=0`）连续发送 4 笔写事务（= `M_ISSUE` 上限），验证全部成功完成。

**Virtual Sequence**: `axicb_outstanding_write_vseq`

**详细设计**:

| 步骤 | 行为 | 关键参数 |
|---|---|---|
| 1. m0 连发 4 笔写 | `wait_for_response=0`; 地址 `32'h0000_0100/0104/0108/010C`; 数据 `{A,B,C,D}`; 每笔不同 ID `{8'h01,8'h02,8'h03,8'h04}` | pipeline 模式——AW 握手后立即发下一笔，不等 B 响应 |
| 2. 等待所有 B 响应 | 等待 drain_time 或显式轮询 | 4 笔 `bresp=OKAY` |
| 3. m0 阻塞读回 | 顺序读回 4 个地址 | 数据正确: `{A,B,C,D}` |

**关键验证点**: 4 笔 outstanding 达到 `M_ISSUE=4` 上限。M 侧 `trans_count_reg` 最高应达到 4。如果第 5 笔被发送，应被背压（这属于 Milestone 4 的 Issue 限制测试）。

**Scoreboard 行为**: 4 笔写按到达顺序写入 ref_mem，4 笔读按到达顺序比对。由于同一 master 的写事务**地址不重叠**，ref_mem 不存在 RAW 冲突。

---

##### Test 2-9: `axicb_outstanding_read_test`

**验证目标**: 验证单 master pipeline 模式连续发送 4 笔读事务。

**Virtual Sequence**: `axicb_outstanding_read_vseq`

**详细设计**:

| 步骤 | 行为 | 关键参数 |
|---|---|---|
| 1. 预写数据 | m0 阻塞写 4 个地址 `32'h0000_0200/0204/0208/020C` | 确保 slave 有数据 |
| 2. m0 连发 4 笔读 | `wait_for_response=0`; 读回上述 4 个地址 | pipeline 读 |
| 3. 验证数据 | Scoreboard 自动比对 | 4 笔全部正确 |

---

#### 【基础设施同步升级 — Milestone 2 出口检查】

##### Scoreboard 升级

| 编号 | 改进项 | 具体改动 |
|---|---|---|
| SCB-01 | 验证 upstream response ID | 在 `process_write()` 中检查 `bid == awid`；在 `process_read()` 中检查 `rid == arid`。若不匹配则 `uvm_error` + `error_count++`。（注意：当前 monitor 已采集完整 transaction，但 scoreboard 未做 ID 一致性检查） |

##### Coverage 升级

| 编号 | 新增/修改 | 具体改动 |
|---|---|---|
| COV-01 | 新增 `cg_id` | `cp_upstream_id`: bins = {`8'h00`, `[8'h01:8'hFE]`, `8'hFF`}; `cp_src_master`: {m0, m1}; cross `cx_id_master` |
| COV-02 | 新增 `cg_outstanding` | `cp_outstanding_depth`: bins = {1, 2, 3, 4}; 需在 M 侧 monitor 或 scoreboard 内部用计数器跟踪同一 master 的 in-flight 事务数 |
| COV-03 | `cg_routing.cx_routing` | 验证 8 bins 全部命中（4 路径 × 2 类型）|

**退出标准**:
- 9 个 Test 全部 `error_count == 0`
- `cg_id.cx_id_master` 覆盖 {`8'h00`, mid-range, `8'hFF`} × {m0, m1} = 6 bins
- `cg_routing.cx_routing` 8 bins 全部命中
- `cg_outstanding.cp_outstanding_depth` 至少命中 depth=4

---

### Milestone 3: Burst 全类型验证

**进入条件**: Milestone 2 全部通过
**退出条件**: INCR/FIXED/WRAP burst 测试通过；narrow/unaligned 测试通过；Scoreboard WRAP 地址计算正确

**设计原理**: crossbar 对 burst 参数做纯透传（不分割/合并），但 Scoreboard 和 Slave mem 需要正确计算每拍地址。本阶段先升级基础设施（WRAP 支持），再逐步验证各种 burst 类型。

#### 【前置基础设施升级】

| 编号 | 改进项 | 文件 | 具体改动 |
|---|---|---|---|
| INF-13 | Scoreboard WRAP 地址计算 | `axicb_scoreboard.sv` | `calculate_beat_addr()` 新增 `WRAP` 分支: `wrap_boundary = (base_addr / (burst_size * (burst_len+1))) * (burst_size * (burst_len+1))`; 每拍: `addr = wrap_boundary + ((start_offset + beat_idx * burst_size) % (burst_size * (burst_len+1)))` |
| INF-14 | Slave mem WRAP 地址计算 | `axi_slave_mem.sv` | `calc_beat_addr()` 新增 `WRAP` 分支，逻辑同上 |
| INF-15 | `BURST_LEN_16BEATS` 修正 | `axi_types.sv` | （如果 Milestone 0 未修复则在此修复）|

---

##### Test 3-1: `axicb_incr_burst_test`

**验证目标**: INCR burst 多种长度，验证 crossbar 透传正确性和 Scoreboard 逐拍比对。

**Virtual Sequence**: `axicb_incr_burst_vseq`

**详细设计**:

| 子 case | `awlen` | 拍数 | 地址 | `awsize` |
|---|---|---|---|---|
| 3-1a | 0 | 1 | `32'h0000_0400` | SIZE_4BYTES |
| 3-1b | 1 | 2 | `32'h0000_0500` | SIZE_4BYTES |
| 3-1c | 3 | 4 | `32'h0000_0600` | SIZE_4BYTES |
| 3-1d | 7 | 8 | `32'h0000_0700` | SIZE_4BYTES |
| 3-1e | 15 | 16 | `32'h0000_0800` | SIZE_4BYTES |
| 3-1f | 255 | 256 | `32'h0000_1000` | SIZE_4BYTES |

每种长度：m0 写 s0 → m0 读 s0 → Scoreboard 逐拍比对。

**关键验证点**: `awlen=255` 产生 256 拍 burst，每拍地址 +4，最终覆盖 1024 字节。验证 W 通道路由在长 burst 期间不中断——`w_select_valid_reg` 持续锁定直到 `wlast`。

**信号时序**: AW 握手一拍完成 → W 连续 256 拍（每拍 wvalid+wready 握手）→ 第 256 拍 `wlast=1` → W 通道释放 → B 响应返回。

---

##### Test 3-2: `axicb_fixed_burst_test`

**验证目标**: FIXED burst——所有拍地址相同，验证 Scoreboard 对 FIXED 地址计算的正确性。

**Virtual Sequence**: `axicb_fixed_burst_vseq`

**详细设计**:

| 子 case | `awlen` | `awburst` | 地址 |
|---|---|---|---|
| 3-2a | 3 (4拍) | FIXED | `32'h0001_2000` |
| 3-2b | 7 (8拍) | FIXED | `32'h0001_3000` |

FIXED burst 特性：每拍 `wdata` 写入**同一地址**，后拍覆盖前拍。读回时只能验证最后一拍的数据。

**Sequence 设计**: 写入 `wdata[0..3] = {A, B, C, D}`，读回单拍期望 `rdata = D`（最后一拍值）。

---

##### Test 3-3: `axicb_wrap_burst_test`

**验证目标**: WRAP burst——地址在 wrap boundary 处回绕。AXI4 规定 WRAP 仅允许 `awlen` ∈ {1, 3, 7, 15} (即 2/4/8/16 拍)。

**Virtual Sequence**: `axicb_wrap_burst_vseq`

**详细设计** (以 4 拍 WRAP, SIZE_4BYTES 为例):

| 参数 | 值 |
|---|---|
| `awaddr` | `32'h0000_4008`（非 wrap boundary 对齐的起始地址）|
| `awlen` | 3 (4 拍) |
| `awsize` | SIZE_4BYTES (4B) |
| `awburst` | WRAP |

地址序列计算：
- wrap_size = 4 × 4 = 16 字节
- wrap_boundary = `0x4008` & ~(16-1) = `0x4000`
- 拍 0: `0x4008` → 拍 1: `0x400C` → 拍 2: `0x4000`（回绕）→ 拍 3: `0x4004`

Sequence: 写 4 拍 → 读 4 拍 → Scoreboard 按 WRAP 地址逐拍比对。

| 子 case | `awlen` | 起始地址 | wrap boundary |
|---|---|---|---|
| 3-3a | 1 (2拍) | `32'h0000_5004` | `0x5000` |
| 3-3b | 3 (4拍) | `32'h0000_4008` | `0x4000` |
| 3-3c | 7 (8拍) | `32'h0000_6010` | `0x6000` |
| 3-3d | 15 (16拍) | `32'h0000_7020` | `0x7000` |

---

##### Test 3-4: `axicb_narrow_transfer_test`

**验证目标**: narrow transfer——`awsize` < DATA_WIDTH/8=4。验证字节通道定位和 WSTRB 的正确性。

**Virtual Sequence**: `axicb_narrow_transfer_vseq`

**详细设计**:

| 子 case | `awsize` | 字节数 | `awlen` | WSTRB 模式 | 地址 |
|---|---|---|---|---|---|
| 3-4a | SIZE_1BYTE | 1 | 3 (4拍) | `4'h1/2/4/8` 依次 | `32'h0001_5000` |
| 3-4b | SIZE_2BYTES | 2 | 3 (4拍) | `4'h3/C` 交替 | `32'h0001_5100` |
| 3-4c | SIZE_1BYTE | 1 | 0 (单拍) | `4'h4` (byte 2) | `32'h0001_5202` (非对齐) |

**关键验证点**: narrow INCR burst 中，每拍的 byte lane 位置随地址递增而变化。例如 SIZE_1BYTE 从 `addr=0x5000` 开始: beat 0 → byte 0 (wstrb=4'h1), beat 1 → byte 1 (wstrb=4'h2), beat 2 → byte 2 (wstrb=4'h4), beat 3 → byte 3 (wstrb=4'h8)。

**Scoreboard 行为**: `merge_data_with_strb` 按 byte lane 合并，只有 strobe 为 1 的字节被更新。

---

##### Test 3-5: `axicb_unaligned_burst_test`

**验证目标**: 非对齐起始地址的 INCR burst。AXI4 规定首拍地址可以非对齐，但后续拍按 `awsize` 对齐递增。

**Virtual Sequence**: `axicb_unaligned_burst_vseq`

**详细设计**:

| 子 case | 起始地址 | `awsize` | `awlen` | 首拍 WSTRB |
|---|---|---|---|---|
| 3-5a | `32'h0000_8001` | SIZE_4BYTES | 3 | `4'hE` (byte 1,2,3 有效) |
| 3-5b | `32'h0000_8002` | SIZE_4BYTES | 3 | `4'hC` (byte 2,3 有效) |
| 3-5c | `32'h0000_8003` | SIZE_4BYTES | 3 | `4'h8` (byte 3 有效) |
| 3-5d | `32'h0000_8001` | SIZE_2BYTES | 7 | `4'h2` (byte 1 有效) |

首拍地址非对齐，`wstrb` 只覆盖有效字节；后续拍按 `awsize` 对齐后全字节有效。

---

##### Test 3-6: `axicb_partial_strobe_test`

**验证目标**: 随机 WSTRB 模式——验证 Slave mem 和 Scoreboard 的 byte-level 合并正确性。

**Virtual Sequence**: `axicb_partial_strobe_vseq`

**详细设计**:

```
repeat (20) begin
  randomize with {
    awlen inside {[0:7]};
    awsize == SIZE_4BYTES;
    awburst == INCR;
    foreach (every_beat_wstrb[i]) every_beat_wstrb[i] inside {4'h1,4'h2,4'h3,4'h5,4'h9,4'hF};
  };
  // 预写全 0xFF → 部分 strobe 写 → 读回验证字节级正确性
end
```

---

#### 【基础设施同步升级 — Milestone 3 出口检查】

##### Coverage 升级

| 编号 | 新增/修改 | 具体改动 |
|---|---|---|
| COV-04 | `cg_burst` 完善 | 确认 WRAP bins 命中; 新增 `cp_burst_len_extended`: bins = {1, 2, 4, 8, 16, 256} |
| COV-05 | 新增 `cg_narrow` | `cp_awsize`: {SIZE_1BYTE, SIZE_2BYTES, SIZE_4BYTES}; `cp_alignment`: {aligned, unaligned}; cross |
| COV-06 | 新增 `cg_wstrb` | `cp_wstrb_pattern`: {all_ones(4'hF), single_byte(4'h1/2/4/8), partial(others)}; 需 sample 每拍 wstrb |

**退出标准**:
- 6 个 Test 全部 `error_count == 0`
- `cg_burst` 的 FIXED/INCR/WRAP × 各长度 bins 命中
- `cg_narrow` 至少命中 1B/2B narrow 和 aligned/unaligned
- Scoreboard WRAP 地址计算无误（通过 Test 3-3 验证）

---

### Milestone 4: 深度并发与仲裁

**进入条件**: Milestone 3 全部通过
**退出条件**: 并发竞争测试通过；thread/issue/accept 限制测试通过；仲裁公平性验证

**设计原理**: 本阶段聚焦 crossbar 的核心非阻塞和仲裁特性。两个 master 竞争同一 slave 时，Round-Robin 仲裁器决定接入顺序；同时访问不同 slave 时应互不阻塞。Thread tracking 和 Issue/Accept 限制在高并发下尤为关键。

#### 4.A — 并发路由 (3 Tests)

##### Test 4-1: `axicb_parallel_diff_slave_test`

**验证目标**: m0→s0 和 m1→s1 同时发送，验证完全非阻塞——两条路径无任何仲裁冲突。

**Virtual Sequence**: `axicb_parallel_diff_slave_vseq`

**详细设计**:

```
fork
  begin  // m0 → s0: 20 笔 INCR burst(len=3), pipeline 模式
    for (int i = 0; i < 20; i++) begin
      addr = 32'h0000_0000 + i * 16;
      write(master=0, addr=addr, id=8'h(i%4), burst_len=3, wait_for_response=0);
    end
    // 等待所有 B 响应
    #(200 * CLK_PERIOD);
    // 阻塞读回验证
    for (int i = 0; i < 20; i++)
      read(master=0, addr=32'h0000_0000 + i*16, burst_len=3);
  end
  begin  // m1 → s1: 20 笔 INCR burst(len=3), pipeline 模式
    for (int i = 0; i < 20; i++) begin
      addr = 32'h0001_0000 + i * 16;
      write(master=1, addr=addr, id=8'h(i%4+0x10), burst_len=3, wait_for_response=0);
    end
    #(200 * CLK_PERIOD);
    for (int i = 0; i < 20; i++)
      read(master=1, addr=32'h0001_0000 + i*16, burst_len=3);
  end
join
```

**关键验证点**: 由于访问不同 slave，M 侧 AW 仲裁器不存在冲突——m0 的事务直接进入 m00 仲裁器，m1 的事务直接进入 m01 仲裁器。两个 fork 分支应接近同时完成。

---

##### Test 4-2: `axicb_same_slave_write_contention_test`

**验证目标**: m0 和 m1 同时写同一个 slave s0，验证 AW 仲裁器的 Round-Robin 行为。

**Virtual Sequence**: `axicb_same_slave_write_contention_vseq`

**详细设计**:

```
fork
  begin  // m0 → s0: 10 笔单拍写
    for (int i = 0; i < 10; i++)
      write(master=0, addr=32'h0000_0000 + i*4, id=8'h01, data=32'h(1000+i));
  end
  begin  // m1 → s0: 10 笔单拍写
    for (int i = 0; i < 10; i++)
      write(master=1, addr=32'h0000_1000 + i*4, id=8'h02, data=32'h(2000+i));
  end
join
// 顺序读回验证全部数据
for (int i = 0; i < 10; i++) begin
  read(master=0, addr=32'h0000_0000 + i*4);  // 期望 1000+i
  read(master=0, addr=32'h0000_1000 + i*4);  // 期望 2000+i
end
```

**关键验证点**: m00 端口的 AW 仲裁器（`ARB_TYPE_ROUND_ROBIN=1, ARB_BLOCK=1, ARB_BLOCK_ACK=1`）收到两个请求，应轮转交替授权。注意 W 通道在 M 侧也有 `w_select_valid` 锁定机制——AW 仲裁赢得后，W 数据传输完成（`wlast`）才释放，下一个 AW 才能被仲裁。

---

##### Test 4-3: `axicb_same_slave_mixed_rw_test`

**验证目标**: m0 写 s0，m1 读 s0，同时 fork。由于读写通道物理分离 (F-M01)，应完全不阻塞。

**Virtual Sequence**: `axicb_same_slave_mixed_rw_vseq`

**详细设计**:

| 步骤 | 行为 |
|---|---|
| 预写 | m0 先串行写 10 笔数据到 s0 (`32'h0000_C000 + i*4`) |
| fork 并发 | m0: 10 笔新地址写 s0 (`32'h0000_D000 + i*4`); m1: 读回预写数据 (`32'h0000_C000 + i*4`) |
| 验证 | m1 读回预写数据正确; m0 新写数据读回正确 |

---

#### 4.B — Thread Tracking 与 Ordering Protection (3 Tests)

##### Test 4-4: `axicb_thread_limit_test`

**验证目标**: 验证 `S_THREADS=2` 限制——单 master 使用 3 个不同 ID 发送事务，第 3 个 ID 应被阻塞直到前两个 ID 之一的事务全部完成。

**Virtual Sequence**: `axicb_thread_limit_vseq`

**详细设计**:

```
// m0 连续发 3 笔 pipeline 写（不等 B 响应），使用 3 个不同 ID
write(master=0, addr=32'h0000_E000, id=8'h01, wait_for_response=0);  // 占 thread slot 0
write(master=0, addr=32'h0000_E004, id=8'h02, wait_for_response=0);  // 占 thread slot 1
write(master=0, addr=32'h0000_E008, id=8'h03, wait_for_response=0);  // S_THREADS=2, 无空闲 slot → 阻塞

// 等待足够时间让前两笔完成
#(100 * CLK_PERIOD);
// 第三笔应在前两笔之一完成后自动放行
// 读回所有数据验证
read(master=0, addr=32'h0000_E000, id=8'h01);
read(master=0, addr=32'h0000_E004, id=8'h02);
read(master=0, addr=32'h0000_E008, id=8'h03);
```

**关键验证点**: `axi_crossbar_addr` 中 `thread_active` 在两个 slot 都被占用时，新 ID 的 `thread_match` 为 0 且 `all_active=1`，准入条件 `!all_active && !thread_match` 不满足 → 阻塞。只有当某个 slot 的 `thread_count_reg` 减到 0（B 响应返回时 `s_cpl_valid`），该 slot 才释放。

**无死锁保证**: 虽然 `aready` 被暂时阻塞，但前两笔事务已经进入 crossbar 并在下游处理中，它们的 B 响应会最终返回，释放 thread slot。

---

##### Test 4-5: `axicb_thread_dest_lock_test`

**验证目标**: 验证同一 ID 必须路由到同一 destination——如果 ID=X 的事务正在飞往 s0，新的 ID=X 事务目标为 s1 时应被阻塞。

**Virtual Sequence**: `axicb_thread_dest_lock_vseq`

**详细设计**:

```
// m0 用 ID=0x10 发 pipeline 写到 s0（不等响应）
write(master=0, addr=32'h0000_F000, id=8'h10, wait_for_response=0);  // → s0, 占 thread slot, dest=s0

// 立即用 ID=0x10 发写到 s1——thread slot 记录 dest=s0, 新请求 dest=s1 不匹配
// thread_match=1 但 thread_match_dest=0 → 阻塞！
write(master=0, addr=32'h0001_F000, id=8'h10, wait_for_response=1);

// 如果到达这里，说明第二笔在第一笔完成后被放行
read(master=0, addr=32'h0000_F000, id=8'h10);  // 数据正确
read(master=0, addr=32'h0001_F000, id=8'h10);  // 数据正确
```

**关键验证点**: `axi_crossbar_addr` 中 `thread_match[n] && !thread_match_dest[n]` → 准入条件不满足。第二笔必须等第一笔完成（`thread_count_reg[slot]==0`），slot 被释放后重新分配到 s1。这是 AXI ordering protection 的核心——防止同 ID 事务到达不同 slave 后乱序完成，导致 master 无法区分。

---

##### Test 4-6: `axicb_two_id_ordering_test`

**验证目标**: 验证同 ID 事务严格保序，不同 ID 之间无排序要求。

**Virtual Sequence**: `axicb_two_id_ordering_vseq`

**详细设计**:

```
// m0 用 2 个 ID 各发 4 笔写到 s0（pipeline 模式）
// ID=0x20: addr = 0x0000_2000, 2004, 2008, 200C
// ID=0x30: addr = 0x0000_3000, 3004, 3008, 300C
// 交替发送：ID20_wr0, ID30_wr0, ID20_wr1, ID30_wr1, ...

for (int i = 0; i < 4; i++) begin
  write(master=0, addr=32'h0000_2000+i*4, id=8'h20, data=32'h(2000+i), wait_for_response=0);
  write(master=0, addr=32'h0000_3000+i*4, id=8'h30, data=32'h(3000+i), wait_for_response=0);
end

#(200 * CLK_PERIOD);

// 验证：分别按 ID 读回，同 ID 数据必须按写入顺序排列
for (int i = 0; i < 4; i++)
  read(master=0, addr=32'h0000_2000+i*4, id=8'h20);  // 期望 2000+i
for (int i = 0; i < 4; i++)
  read(master=0, addr=32'h0000_3000+i*4, id=8'h30);  // 期望 3000+i
```

**Scoreboard 行为**: ref_mem 是全局的，按地址索引，不区分 ID。只要写入地址不重叠，比对就是正确的。ordering 验证通过"写入的值与地址一一对应"隐式保证。

---

#### 4.C — Issue/Accept 限制 (2 Tests)

##### Test 4-7: `axicb_issue_limit_test`

**验证目标**: 验证 `M_ISSUE=4` 限制——单 master 向单 slave 连发 8 笔 pipeline 写，前 4 笔应立即被接受，后 4 笔应在前序完成后才被放行。

**Virtual Sequence**: `axicb_issue_limit_vseq`

**详细设计**:

```
// m0 连续 pipeline 发 8 笔写到 s0（wait_for_response=0）
for (int i = 0; i < 8; i++)
  write(master=0, addr=32'h0000_0800+i*4, id=8'h(i%2), data=32'h(i), wait_for_response=0);

// 等待所有完成
#(500 * CLK_PERIOD);

// 读回验证全部 8 笔数据正确
for (int i = 0; i < 8; i++)
  read(master=0, addr=32'h0000_0800+i*4);
```

**关键验证点**: M 侧 `trans_count_reg` 最高为 4，第 5 笔的 AW 会被 S 侧 `axi_crossbar_addr` 的 `trans_limit` 背压（因为 `trans_count >= M_ISSUE && !trans_complete`）。无死锁——前 4 笔会逐步完成释放 slot。

**注意**: 此测试使用 2 个 ID (`i%2`)，不超过 `S_THREADS=2`，避免 thread 限制干扰 issue 限制的验证。

---

##### Test 4-8: `axicb_accept_limit_test`

**验证目标**: 验证 `S_ACCEPT=16` 限制——逼近 accept 上限。

**Virtual Sequence**: `axicb_accept_limit_vseq`

**详细设计**:

两个 master 各发 8 笔 pipeline 写到同一 slave s0（总计 16 笔 = `S_ACCEPT`）:

```
fork
  begin  // m0 → s0: 8 笔 pipeline 写
    for (int i = 0; i < 8; i++)
      write(master=0, addr=32'h0000_A000+i*4, id=8'h01, wait_for_response=0);
  end
  begin  // m1 → s0: 8 笔 pipeline 写
    for (int i = 0; i < 8; i++)
      write(master=1, addr=32'h0000_B000+i*4, id=8'h01, wait_for_response=0);
  end
join
#(500 * CLK_PERIOD);
// 读回验证 16 笔数据
```

**关键验证点**: `axi_crossbar_addr` 的 `trans_count_reg` 可达 16 后触发 `trans_limit`。此后新事务阻塞。结合 `M_ISSUE=4` 限制，实际每个 master 最多发 4 笔到同一 slave，两个 master 合计最多 8 笔同时 in-flight（受 M_ISSUE 限制）。要真正触及 `S_ACCEPT=16`，需要事务更快发出且 slave 响应较慢。

---

#### 【基础设施同步升级 — Milestone 4 出口检查】

##### Scoreboard 升级

| 编号 | 改进项 | 具体改动 |
|---|---|---|
| SCB-02 | ordering 隐式验证 | 当前 ref_mem 按地址比对已隐式保证同 ID ordering（因为写入地址唯一对应写入值）。不需要额外改动，但在 `report_phase` 中新增统计：`concurrent_test_count` 记录并发场景的事务数 |

##### Coverage 升级

| 编号 | 新增/修改 | 具体改动 |
|---|---|---|
| COV-07 | 新增 `cg_concurrency` | `cp_concurrent_masters`: bins = {single_master, dual_master_diff_slave, dual_master_same_slave}; `cp_concurrent_rw`: bins = {write_only, read_only, mixed_rw} |
| COV-08 | 新增 `cg_thread` | `cp_active_threads`: bins = {1, 2}（等于 S_THREADS 时为满载）; `cp_thread_blocked`: bins = {0, 1} (是否发生过 thread 阻塞) |
| COV-09 | `cg_outstanding` 扩展 | `cp_issue_depth`: bins = {1, 2, 3, 4}; `cp_issue_full`: bins = {0, 1} |

**退出标准**:
- 8 个 Test 全部 `error_count == 0`
- 无死锁（仿真在合理时间内结束）
- `cg_concurrency` 覆盖 dual_master_diff_slave + dual_master_same_slave bins
- `cg_thread` 覆盖 active_threads={1,2}

---

### Milestone 5: Backpressure 与 Reset

**进入条件**: Milestone 4 全部通过
**退出条件**: 带 backpressure 的场景无死锁；reset 后恢复正常

**设计原理**: Backpressure 测试需要 VIP 的 slave responder 支持随机延迟注入，这需要一定代码改动。Reset 测试验证 crossbar 在传输中途被复位后能否恢复到干净状态。

#### 【前置基础设施升级】

| 编号 | 改进项 | 文件 | 具体改动 |
|---|---|---|---|
| INF-16 | Slave responder 延迟旋钮 | `axi_slave_write_responder.sv` | 新增 `int aw_ready_delay = 0`, `int w_ready_delay = 0`; `accept_aw_channel()` 中在拉高 awready 前插入 `repeat(aw_ready_delay) @(posedge clk)` |
| INF-17 | Slave responder 延迟旋钮 | `axi_slave_read_responder.sv` | 新增 `int ar_ready_delay = 0`, `int r_valid_delay = 0`; 在驱动 rvalid 前插入延迟 |
| INF-18 | Master driver 延迟旋钮 | `axi_master_read_driver.sv` | 新增 `int rready_delay = 0`; 在拉高 rready 前可选延迟 |
| INF-19 | 配置传递 | `axi_configuration.sv` | 新增延迟配置字段，通过 config_db 传入 responder/driver |

---

##### Test 5-1: `axicb_backpressure_slave_test`

**验证目标**: slave 端施加随机延迟——awready/wready/arready 不立即拉高，验证 crossbar pipeline register 正确缓冲。

**Virtual Sequence**: `axicb_backpressure_slave_vseq`

**详细设计**:

| 步骤 | 配置 | 事务 |
|---|---|---|
| 1. 设置 slave 延迟 | s0: `aw_ready_delay=rand(0,5)`, `w_ready_delay=rand(0,3)`, `r_valid_delay=rand(0,4)` | |
| 2. m0 → s0: 10 笔 INCR burst(len=3) | pipeline 模式 | 阻塞读回验证数据正确 |
| 3. 并发: m0→s0 + m1→s0 | 各 5 笔 | 验证数据正确，无死锁 |

**关键验证点**: M 侧 AW 通道有 simple buffer (REG_TYPE=1)，W 通道有 skid buffer (REG_TYPE=2)。skid buffer 保证即使下游反压，上游仍能连续发送一拍而不产生气泡。simple buffer 在反压时会产生气泡——验证不会丢数据。

---

##### Test 5-2: `axicb_backpressure_master_test`

**验证目标**: master 端延迟 rready——模拟 master 处理慢，R 通道产生反压。

**Virtual Sequence**: `axicb_backpressure_master_vseq`

**详细设计**:

| 步骤 | 配置 | 事务 |
|---|---|---|
| 1. 设置 master 延迟 | m0: `rready_delay=rand(1,10)` | |
| 2. m0 → s0: 5 笔 INCR burst(len=7) | 阻塞模式 | S 侧 R 通道有 skid buffer (REG_TYPE=2)，验证不丢拍 |

---

##### Test 5-3: `axicb_reset_idle_test`

**验证目标**: 在 idle 状态下 reset，验证 DUT 输出信号全部清零，reset 释放后可正常工作。

**Virtual Sequence**: `axicb_reset_idle_vseq`

**详细设计**:

| 步骤 | 行为 | 期望 |
|---|---|---|
| 1. m0 写读 s0 | 基础事务验证连通性 | 数据正确 |
| 2. 等待 idle | 所有 valid 信号为 0 | |
| 3. 拉高 reset 20ns | `vif.assert_reset()` | 所有 valid 输出 = 0 |
| 4. 释放 reset | `vif.deassert_reset()` | |
| 5. m0 写读 s0 | 新数据 | 数据正确（slave mem 被 clear） |

**Scoreboard 行为**: reset 后 `ref_mem` 应被清空（因为 slave mem 在 reset 时 clear）。需在 monitor 检测到 reset 时通知 scoreboard 清空 ref_mem。

---

##### Test 5-4: `axicb_reset_mid_write_test`

**验证目标**: 在 W 数据传输中途 reset，验证 DUT 不挂死。

**Virtual Sequence**: `axicb_reset_mid_write_vseq`

**详细设计**:

```
fork
  begin  // 发起 8 拍写
    write(master=0, addr=32'h0000_0000, burst_len=7, wait_for_response=1);
  end
  begin  // 在第 3 拍后 reset
    repeat(10) @(posedge clk);  // 等待 AW 握手 + 约 3 个 W 拍
    vif.do_reset(20);           // assert 20ns then deassert
  end
join_any
disable fork;

// reset 后恢复
#(100);
write(master=0, addr=32'h0000_0100, data=32'h12345678);
read(master=0, addr=32'h0000_0100);
// 期望数据正确
```

**Scoreboard 行为**: mid-write 事务可能产生 partial transaction——monitor 在 `monitor_reset()` 中将其写出到 analysis port，scoreboard 需识别并跳过（通过检查 `wbeat_finish` 标志或 reset 事件）。

---

##### Test 5-5: `axicb_reset_mid_read_test`

**验证目标**: 在 R 数据返回中途 reset，验证恢复正常。

**详细设计**: 类似 Test 5-4，但针对 read burst。

---

#### 【基础设施同步升级 — Milestone 5 出口检查】

##### Scoreboard 升级

| 编号 | 改进项 | 具体改动 |
|---|---|---|
| SCB-03 | Reset 清空 ref_mem | 新增 `reset_detected` 事件；env 在 monitor 检测到 reset 时触发；scoreboard 清空 `ref_mem` 并 reset `check_count`/`error_count` |
| SCB-04 | Partial transaction 过滤 | 在 `write()` 方法中检查 `wbeat_finish` / `rbeat_finish`，未完成的事务跳过 ref_mem 操作 |

##### Coverage 升级

| 编号 | 新增 | 具体改动 |
|---|---|---|
| COV-10 | 新增 `cg_backpressure` | `cp_aw_backpressure`: {none(0), short(1-3), long(4+)}; `cp_w_backpressure`: 同上; `cp_r_backpressure`: 同上 |
| COV-11 | 新增 `cg_reset` | `cp_reset_state`: {idle, mid_write, mid_read}; `cp_post_reset_recovery`: {0, 1} |

**退出标准**:
- 5 个 Test 无死锁、无数据错误
- reset 后恢复正常
- `cg_backpressure` 至少覆盖 non-zero delay bins
- `cg_reset` 覆盖 idle/mid_write/mid_read

---

### Milestone 6: 随机回归与覆盖率收敛

**进入条件**: Milestone 5 全部通过
**退出条件**: 功能覆盖率 ≥ 95%；代码覆盖率 ≥ 90%（或有 waiver）；1000+ 随机 seeds 稳定通过

**设计原理**: 前 5 个 Milestone 以 directed test 为主，保证每个特性被精确验证。本阶段用全随机 test 扫荡残余覆盖率盲区。

##### Test 6-1: `axicb_random_single_master_test`

**Virtual Sequence**: `axicb_random_single_master_vseq`

```
repeat (200) begin
  randomize with {
    master_idx inside {0, 1};
    addr[31:16] inside {16'h0000, 16'h0001};
    addr[1:0] == 2'b00;
    burst_len inside {[0:15]};
    burst_type inside {FIXED, INCR, WRAP};
    burst_size inside {SIZE_1BYTE, SIZE_2BYTES, SIZE_4BYTES};
    tr_id inside {[0:255]};
    // WRAP 约束：len must be 1,3,7,15
    burst_type == WRAP -> burst_len inside {1, 3, 7, 15};
  };
  write → read → compare;
end
```

---

##### Test 6-2: `axicb_random_dual_master_contention_test`

**Virtual Sequence**: `axicb_random_dual_master_contention_vseq`

```
fork
  begin  // m0: 100 笔全随机
    repeat(100) randomized_write_read(master=0);
  end
  begin  // m1: 100 笔全随机
    repeat(100) randomized_write_read(master=1);
  end
join
```

包含：随机 burst 类型/长度/大小、随机 ID、随机 slave 目标、pipeline 模式。

---

##### Test 6-3: `axicb_random_stress_test`

**Virtual Sequence**: `axicb_random_stress_vseq`

全维度随机 + backpressure 延迟随机注入 + 偶发 reset（约每 500 个事务一次）。

---

#### 【最终覆盖率检查】

| Covergroup | 目标 |
|---|---|
| `cg_routing.cx_routing` | 8/8 bins = 100% |
| `cg_burst` | FIXED/INCR/WRAP × 各 len × 各 size ≥ 95% |
| `cg_response` | OKAY + DECERR bins = 100% |
| `cg_id.cx_id_master` | ≥ 95% |
| `cg_narrow` | aligned + unaligned × 各 size ≥ 95% |
| `cg_concurrency` | all bins hit |
| `cg_thread` | active_threads=1,2 + blocked hit |
| `cg_outstanding` | depth 1~4 hit |
| `cg_wstrb` | all_ones + single_byte + partial hit |
| `cg_backpressure` | non-zero bins hit |
| `cg_reset` | idle + mid_write + mid_read hit |

---

## 四、覆盖率收集计划汇总 (Coverage Plan Summary)

### 4.1 功能覆盖率 (Functional Coverage)

| Covergroup | Coverpoints | Cross | 引入 Milestone | Sample 来源 |
|---|---|---|---|---|
| `cg_trans_type` | `cp_type`: {WRITE, READ} | — | 0 (已有) | upstream monitor |
| `cg_burst` | `cp_burst_type`: {FIXED, INCR, WRAP}; `cp_burst_len`: {1,2,4,8,16,256}; `cp_burst_size`: {1B,2B,4B} | type×len, type×size | 0 (补 WRAP) | upstream monitor |
| `cg_comprehensive` | type × burst × len | 三维交叉 | 0 (激活) | upstream monitor |
| `cg_routing` | `cp_src_master`: {m0,m1}; `cp_dst_slave`: {s0,s1}; `cp_txn_type`: {W,R} | `cx_routing` 2×2×2=8 | 0 (新增) | upstream monitor + 地址推断 |
| `cg_response` | `cp_bresp`: {OKAY, DECERR}; `cp_rresp`: {OKAY, DECERR} | — | 0 (新增) | upstream monitor |
| `cg_id` | `cp_upstream_id`: {0x00, [0x01:0xFE], 0xFF}; `cp_src_master`: {m0,m1} | `cx_id_master` | 2 (新增) | upstream monitor |
| `cg_outstanding` | `cp_outstanding_depth`: {1,2,3,4}; `cp_issue_full`: {0,1} | — | 2 (新增) | scoreboard 内部计数 |
| `cg_narrow` | `cp_awsize`: {1B,2B,4B}; `cp_alignment`: {aligned, unaligned} | cross | 3 (新增) | upstream monitor |
| `cg_wstrb` | `cp_wstrb_pattern`: {all_ones, single_byte, partial} | — | 3 (新增) | upstream monitor per-beat |
| `cg_concurrency` | `cp_concurrent_masters`: {single, dual_diff, dual_same}; `cp_concurrent_rw`: {W,R,mixed} | cross | 4 (新增) | env 层全局状态 |
| `cg_thread` | `cp_active_threads`: {1,2}; `cp_thread_blocked`: {0,1} | — | 4 (新增) | SVA 或 scoreboard |
| `cg_backpressure` | `cp_aw/w/r_backpressure`: {none, short, long} | — | 5 (新增) | slave responder config |
| `cg_reset` | `cp_reset_state`: {idle, mid_write, mid_read} | — | 5 (新增) | test 层 |

### 4.2 断言覆盖率 (SVA)

以下断言建议绑定在 DUT 内部关键节点，在 Milestone 4 之后逐步加入：

| 编号 | SVA | 绑定位置 | 描述 | 何时加入 |
|---|---|---|---|---|
| SVA-1 | AXI Handshake Stability | `axi_if` (已有) | `valid && !ready \|=> $stable(signals)` — 已实现 5 条 | 基线 |
| SVA-2 | Arbiter Grant One-hot | `axi_crossbar_wr.m_ifaces[*].a_arb_inst` | `grant_valid \|-> $onehot(grant)` — 仲裁授权必须是 one-hot | Milestone 4 |
| SVA-3 | Trans Count Range | `axi_crossbar_wr.m_ifaces[*]` / `axi_crossbar_rd.m_ifaces[*]` | `trans_count_reg >= 0 && trans_count_reg <= M_ISSUE` — 计数器不越界 | Milestone 4 |
| SVA-4 | DECERR Read Completeness | `axi_crossbar_rd.s_ifaces[*]` | `decerr_m_axi_rvalid && decerr_m_axi_rlast \|=> !decerr_m_axi_rvalid` — DECERR 读在 rlast 后释放 | Milestone 1 |
| SVA-5 | W Channel Routing Lock | `axi_crossbar_wr.s_ifaces[*]` | `w_select_valid_reg && !wlast \|=> w_select_valid_reg` — W 路由在 wlast 前保持锁定 | Milestone 3 |
| SVA-6 | No Valid During Reset | `axi_if` (新增) | `arst \|-> !awvalid && !wvalid && !arvalid` — reset 期间 DUT 输出 valid 为 0 | Milestone 5 |

---

## 五、记分板设计建议 (Scoreboard Architecture)

### 5.1 Layer 1: Data Integrity (当前实现 + 渐进升级)

```
axicb_scoreboard (uvm_subscriber#(axi_transaction))
  │
  ├── ref_mem: bit[31:0] associative array [bit[31:0]]
  │     └── 全局共享内存模型，按 word 地址索引
  │
  ├── process_write(txn):
  │     ├── [M0] 检查 bresp：DECERR → decerr_count++, skip ref_mem
  │     ├── [M1] 检查 bid == awid (ID 一致性)
  │     └── 逐拍: calculate_beat_addr → merge_data_with_strb → ref_mem[word_addr] = merged
  │
  ├── process_read(txn):
  │     ├── [M0] 检查 rresp[0]：DECERR → decerr_count++, skip compare
  │     ├── [M1] 检查 rid == arid (ID 一致性)
  │     └── 逐拍: calculate_beat_addr → expected = ref_mem[word_addr] → compare with rdata
  │
  ├── calculate_beat_addr(base, burst_type, burst_size, burst_len, beat_idx):
  │     ├── FIXED: return base (所有拍)
  │     ├── INCR: addr = aligned_base + beat_idx * burst_size
  │     │         (首拍使用原始 base_addr，后续拍按 size 对齐递增)
  │     └── WRAP: wrap_boundary = aligned_base & ~(wrap_size-1)
  │               addr = wrap_boundary + ((start_offset + beat_idx*size) % wrap_size)
  │               where wrap_size = burst_size * (burst_len + 1)
  │
  ├── merge_data_with_strb(old_data, new_data, wstrb):
  │     └── 4 byte-lane 逐字节合并
  │
  ├── reset_handler():
  │     └── 清空 ref_mem, 重置计数器
  │
  └── report_phase():
        └── 打印 check_count / error_count / decerr_count
```

**数据流**: upstream monitor (mst_agent00/01) → `analysis_export` → `write()` → dispatch

**演进路径**:

| Milestone | 改动 |
|---|---|
| M0 | 新增 DECERR 过滤 (`bresp`/`rresp` 检查) |
| M2 | 新增 ID 一致性检查 (`bid==awid`, `rid==arid`) |
| M3 | 补充 WRAP 地址计算 |
| M5 | 新增 reset 清空逻辑 + partial transaction 过滤 |

### 5.2 Layer 2: Route & ID Checker (建议 Milestone 4 开始开发)

**目的**: 验证 crossbar 路由正确性——事务是否到达了正确的 slave、ID 扩展/还原是否正确。

**架构**:

```
axicb_route_checker (uvm_component)
  │
  ├── upstream_expect_q: axi_transaction queue[2]  // per-master 期望队列
  │
  ├── 输入端口:
  │     ├── upstream_wr_port[0/1]  ← mst_agent00/01 monitor (AW 握手后的 txn)
  │     └── downstream_wr_port[0/1] ← slv_agent00/01 monitor (AW 握手后的 txn)
  │
  ├── 路由预测:
  │     ├── predict_slave(addr) → slave_idx
  │     │   └── addr[31:16]==0x0000 → s0; addr[31:16]==0x0001 → s1; else → DECERR
  │     └── predict_downstream_id(upstream_id, master_idx) → {master_idx, upstream_id}
  │
  └── 比对:
        ├── upstream txn 到达时: 预测 slave_idx, 将 txn+预测放入 expect_q
        └── downstream txn 到达时: 从 expect_q 中按 predicted_downstream_id 匹配
              ├── 验证到达端口 == predicted slave_idx
              ├── 验证 m_awid == predicted_downstream_id
              └── 匹配成功则删除 expect 条目
```

**关键数据结构**:
```systemverilog
typedef struct {
  axi_transaction    txn;
  int                predicted_slave;
  bit [M_ID_WIDTH-1:0] predicted_m_id;
} route_expect_t;

route_expect_t upstream_expect_q[2][$];  // [master_idx][$]
```

**时机**: Layer 2 不在 Milestone 0-3 实现。在 Milestone 2 中通过 sequence 层显式检查 ID 代替。完整 Layer 2 作为 Milestone 4 的前置开发任务。

### 5.3 并发安全性

当前 ref_mem 是单一全局关联数组。两个 master 的写事务到达 scoreboard 的顺序取决于 monitor 的采样顺序（B 握手时序）。**只要两个 master 的写地址不重叠**，ref_mem 不存在 RAW 冲突。

对于同一地址被两个 master 写入的场景（如 Test 4-2），最终 ref_mem 的值取决于最后写入者。读回时只要从正确的 master 读回最后一次写入的值即可。验证计划中通过**地址分离**（m0 写 `0x0000_0000+i*4`, m1 写 `0x0000_1000+i*4`）避免此问题。

---

## 六、全量 Test 索引 (Master Test Index)

| # | Testcase | Milestone | 依赖 |
|---|---|---|---|
| — | Smoke test (已有) | 基线 | — |
| 1-1 | `axicb_decerr_single_write_test` | M1 | INF-05~07 |
| 1-2 | `axicb_decerr_single_read_test` | M1 | INF-05~07 |
| 1-3 | `axicb_decerr_burst_write_test` | M1 | INF-05~07 |
| 1-4 | `axicb_decerr_burst_read_test` | M1 | INF-05~07 |
| 1-5 | `axicb_decerr_then_legal_test` | M1 | INF-05~07 |
| 1-6 | `axicb_decerr_both_masters_test` | M1 | INF-05~07 |
| 2-1 | `axicb_decode_full_range_test` | M2 | M1 |
| 2-2 | `axicb_decode_boundary_test` | M2 | M1 |
| 2-3 | `axicb_decode_random_addr_test` | M2 | M1 |
| 2-4 | `axicb_id_nonzero_test` | M2 | INF-03~04 |
| 2-5 | `axicb_id_extreme_values_test` | M2 | INF-03~04 |
| 2-6 | `axicb_same_id_diff_master_concurrent_test` | M2 | INF-03~04 |
| 2-7 | `axicb_response_route_parallel_test` | M2 | INF-03~04 |
| 2-8 | `axicb_outstanding_write_test` | M2 | INF-03~04 |
| 2-9 | `axicb_outstanding_read_test` | M2 | INF-03~04 |
| 3-1 | `axicb_incr_burst_test` | M3 | M2 |
| 3-2 | `axicb_fixed_burst_test` | M3 | M2 |
| 3-3 | `axicb_wrap_burst_test` | M3 | INF-13~14 |
| 3-4 | `axicb_narrow_transfer_test` | M3 | M2 |
| 3-5 | `axicb_unaligned_burst_test` | M3 | M2 |
| 3-6 | `axicb_partial_strobe_test` | M3 | M2 |
| 4-1 | `axicb_parallel_diff_slave_test` | M4 | M3 |
| 4-2 | `axicb_same_slave_write_contention_test` | M4 | M3 |
| 4-3 | `axicb_same_slave_mixed_rw_test` | M4 | M3 |
| 4-4 | `axicb_thread_limit_test` | M4 | M3 |
| 4-5 | `axicb_thread_dest_lock_test` | M4 | M3 |
| 4-6 | `axicb_two_id_ordering_test` | M4 | M3 |
| 4-7 | `axicb_issue_limit_test` | M4 | M3 |
| 4-8 | `axicb_accept_limit_test` | M4 | M3 |
| 5-1 | `axicb_backpressure_slave_test` | M5 | INF-16~19 |
| 5-2 | `axicb_backpressure_master_test` | M5 | INF-16~19 |
| 5-3 | `axicb_reset_idle_test` | M5 | SCB-03~04 |
| 5-4 | `axicb_reset_mid_write_test` | M5 | SCB-03~04 |
| 5-5 | `axicb_reset_mid_read_test` | M5 | SCB-03~04 |
| 6-1 | `axicb_random_single_master_test` | M6 | M5 |
| 6-2 | `axicb_random_dual_master_contention_test` | M6 | M5 |
| 6-3 | `axicb_random_stress_test` | M6 | M5 |

---

## 七、长期 Roadmap（不进入 M0~M6）

| 类别 | 项目 | 说明 |
|---|---|---|
| Pipeline Register 参数化 | 改变 `*_REG_TYPE` 参数组合 (所有通道 bypass/simple/skid 的 3^5=243 种组合中选关键子集) | 需参数化 testbench |
| USER 信号透传 | `*USER_ENABLE=1`，验证 awuser/wuser/buser/aruser/ruser 端到端一致 | 当前 disable |
| M_SECURE 安全过滤 | `M_SECURE=1`，验证 prot[1]=1 的事务被 DECERR 拒绝 | 当前 `M_SECURE=0` |
| M_CONNECT 部分连接 | 非全连接配置 (`M_CONNECT != 2'b11`)，被禁止路径返回 DECERR | 当前全连接 |
| 3x3 / 4x4 扩展 | 更多端口的参数化验证 | 需修改 tb 顶层 |
| 性能测量 | 大流量长时间运行，测量吞吐量和延迟 | 非功能验证 |
