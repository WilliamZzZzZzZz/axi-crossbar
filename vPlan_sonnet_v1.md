# AXI4 2×2 Non-blocking Crossbar — 验证计划 vPlan_sonnet_v1

> **DUT**: `axi_crossbar_wrap_2x2` | **方法学**: UVM 1.2 | **仿真器**: VCS
> **配置**: 2S×2M, DATA_WIDTH=32, ADDR_WIDTH=32, S_ID=8bit, M_ID=9bit
> **地址映射**: S0=`0x0000_0000~0x0000_FFFF`, S1=`0x0001_0000~0x0001_FFFF`
> **DUT 关键参数**: S_THREADS=2, S_ACCEPT=16, M_ISSUE=4, 全互连(CONNECT=2'b11)
> **编写日期**: 2026-04-27

---

## 一、验证现状基线

### 1.1 已完成的 Test 与 VSeq

| Test | VSeq | 核心验证点（勿重复） |
|---|---|---|
| `axicb_smoke_test` | `axicb_smoke_vseq` | 4路基础路由(m0/m1 × s0/s1)，边界地址，随机地址，单拍 W+R 数据完整性，Scoreboard INCR/FIXED 地址计算 |
| `axicb_decerr_single_test` | `axicb_decerr_single_vseq` | 单拍 DECERR：随机非法地址(0x0002_0000~0xFFFF_FFFF)，每路径[2..10]笔，all mst×{W,R}，downstream 信号级泄漏监控 |
| `axicb_decerr_burst_test` | `axicb_decerr_burst_vseq` | 多拍 DECERR：随机 4 种 burst_len，downstream 隔离，DECERR 后合法恢复写读 s0/s1 全部验证 |
| `axicb_decerr_dual_mst_test` | `axicb_decerr_dual_mst_vseq` | 双 master 并发 DECERR，一 DECERR 一合法，交叉 DECERR-W+合法-R / DECERR-R+合法-W（共 8 个子场景） |
| `axicb_decerr_id_test` | `axicb_decerr_id_vseq` | DECERR 后同 ID(0x10) 恢复合法访问 s0+s1，覆盖 single/4-beat/8-beat × m0/m1 |
| `axicb_decode_full_range_test` | `axicb_decode_full_range_vseq` | **S0** 地址空间 base/mid/boundary × mst{0,1} × {W,R}，信号级 upstream/downstream checker（AWADDR、9-bit ID 对齐） |

### 1.2 已就绪的基础设施

| 组件 | 已支持的关键能力 |
|---|---|
| `axicb_base_vseq` | `do_legal_write/read`：支持 awid/arid, every_beat_data/wstrb, burst 全参数；内置 bid/rid 一致性校验，bresp/rresp 校验 |
| `axicb_decerr_base_vseq` | `do_decerr_write/read`，`check_downstream_port`，`downstream_check_report` |
| `axicb_decode_base_vseq` | `upstream_decode_checker`，`downstream_decode_checker`，5 个 handshake wait task（含超时） |
| `axicb_scoreboard` | DECERR 过滤(`is_decerr_expected`)，ref_mem，INCR/FIXED beat 地址计算，字节级 strobe merge |
| `axicb_coverage` | `cg_trans_type`、`cg_burst`、`cg_comprehensive`、`cg_routing`、`cg_response` — 全部实例化并采样 |
| `axicb_single_write/read_seq` | `awid/arid`、`expect_decerr`、`wait_for_response`、`every_beat_data` 均已暴露至 vseq 层 |

### 1.3 当前覆盖率命中状态

| Covergroup | 已命中 | 确认缺失 |
|---|---|---|
| `cg_routing.CX_ROUTING` | m0/m1 × **s0** × W/R + m0/m1 × DECERR × W/R | m0/m1 × **s1** × W/R（4 bins 空白） |
| `cg_response.CX_RESP` | OKAY×W, OKAY×R, DECERR×W, DECERR×R | 全部命中 ✅ |
| `cg_burst.BURST_TYPE_X_LEN` | INCR × {1,4,8} beat | FIXED×any, WRAP×any, 2/16 beat INCR |
| `cg_burst.BURST_TYPE_X_SIZE` | INCR × 4B | FIXED×any, WRAP×any, SIZE_1B/2B |
| `cg_comprehensive.TYPE_X_BURST_X_LEN` | W/R × INCR × {1,4,8}beat | FIXED 分支、16beat 分支 |

---

## 二、验证缺口分析

### 2.1 功能特性缺口

| 优先级 | 特性 | 缺口描述 | 对应 Stage |
|---|---|---|---|
| P1 | 地址解码边界 | S1 地址空间(0x0001_0000~0x0001_FFFF) 从未被 decode checker 覆盖；S0/S1 交界(0x0000_FFFC vs 0x0001_0000)精确边界未验证 | A |
| P1 | ID 9-bit 扩展 | downstream M_ID=`{src_port[0], upstream_id[7:0]}` 的位拼接从未在 checker 层面对 S1 路径验证；同 upstream ID 跨 master 并发路由到同 slave 时的 downstream ID 区分未验证 | B |
| P1 | 并发非阻塞 | 读写物理通道分离(F-M01)从未在双通道同时施压；m0→s0 ∥ m1→s1 真并行从未 fork；m0∥m1 竞争同 slave 的 AW 仲裁从未触发 | C |
| P2 | Burst 全类型 | FIXED/WRAP burst 零覆盖；narrow(SIZE_1B/2B) 零覆盖；非对齐首拍地址零覆盖 | D |
| P2 | Thread Tracking | S_THREADS=2 上限从未测试；同 ID 锁定 dest 机制(ordering protection)从未测试 | E |

### 2.2 基础设施缺口（按需修复，不提前）

| 缺口 | 影响 Stage | 修复文件 |
|---|---|---|
| `axicb_decode_full_range_vseq` mid/boundary 块 hardcode `do_legal_write`，READ 路径无效 | 即刻（bug fix） | `axicb_decode_full_range_vseq.sv` |
| `do_legal_write/read` 的 `wait_for_response` 硬编码=1 | C、E | `axicb_base_vseq.sv` |
| Scoreboard 无 WRAP 地址计算 | D | `axicb_scoreboard.sv` |
| Slave mem 无 WRAP 地址计算 | D | `axi_slave_mem.sv` |
| 无 `cg_id` covergroup | B | `axicb_coverage.sv` |
| Slave 无响应延迟旋钮 | E | `axi_slave_responder.sv` |

---

## 三、剩余验证阶段

> **设计原则**：
> 1. 每个 vseq 覆盖一个完整的功能集群，最小化 vseq 总数；
> 2. vseq 内部通过参数化 task 和 fork-join 组合多个子场景，而非拆分为独立 vseq；
> 3. 每个 Stage 完成后同步更新 Coverage/Scoreboard，并作为出口检查项。

---

### Stage A：地址解码完整覆盖

**进入条件**：已有 6 个 Test 全部通过（当前基线）。

#### A.0 即刻 Bug Fix（编码前完成）

| 文件 | 修改内容 |
|---|---|
| `axicb_decode_full_range_vseq.sv` | `mid_addr_decode_test` 和 `boundary_addr_decode_test` 两个 begin 块中，将 hardcode 的 `do_legal_write` 替换为 `case(trans_type)` 分支（与 `base_addr_decode_test` 块保持一致），使 READ 路径真正生效 |

#### A.1 vseq：`axicb_decode_s1_vseq`

**继承**：`axicb_decode_base_vseq`（直接复用所有 checker task）

**body() 调用序列**：

```
mx_s1_decode_test(0, WRITE);    // m0 → S1 地址空间，写方向
mx_s1_decode_test(0, READ);     // m0 → S1 地址空间，读方向
mx_s1_decode_test(1, WRITE);    // m1 → S1 地址空间，写方向
mx_s1_decode_test(1, READ);     // m1 → S1 地址空间，读方向
s0_s1_boundary_test();          // S0/S1 精确边界验证
```

**`mx_s1_decode_test` 内部结构**（与 `mx_s0_decode_test` 完全对称）：
- 三个独立 begin...end 块，分别测试 `s1_base_addr(0x0001_0000)` / `s1_mid_addr(0x0001_8000)` / `s1_boundary_addr(0x0001_FFFC)`
- 每块内部：`fork...join` 并行 `do_legal_write/read` + `upstream_decode_checker` + `downstream_decode_checker`
- 每块就地独立判断 `ups_error || downs_error`，精准打印

**`s0_s1_boundary_test` 设计**：

| 步骤 | 行为 | 期望 |
|---|---|---|
| 1 | m0 写 `0x0000_FFFC`(S0末字)，数据 A | `upstream_decode_checker` 确认 bid 正确；`downstream_decode_checker` 确认握手在 `vif_slv00` 上，`bid[8]=0` |
| 2 | m0 写 `0x0001_0000`(S1首字)，数据 B | `downstream_decode_checker` 确认握手在 `vif_slv01` 上，`bid[8]=0` |
| 3 | m0 读回两地址 | 数据分别为 A 和 B，路由至不同 slave，互不污染 |
| 4 | m1 重复步骤 1-3 | `bid[8]=1` |

**对应 Test**：`axicb_decode_s1_test`（结构同已有 decode test，调用 `axicb_decode_s1_vseq`）

**Stage A 出口检查**：

| 项目 | 标准 |
|---|---|
| `cg_routing.CX_ROUTING` | m0×s1×W、m0×s1×R、m1×s1×W、m1×s1×R 四 bins 全部命中 |
| Scoreboard | `error_count == 0`，`check_count > 0` |
| decode_full_range_test 回归 | READ 路径不再 hardcode，mid/boundary 地址 READ 方向 checker 正常执行 |

---

### Stage B：ID 路由与 9-bit 扩展验证

**进入条件**：Stage A 通过。

#### B.0 Coverage 新增（编码 vseq 前完成）

| 文件 | 修改内容 |
|---|---|
| `axicb_coverage.sv` | 新增 `cg_id`：`CP_ID_VALUE { bins id_zero={8'h00}; bins id_ff={8'hFF}; bins id_mid = {[8'h01:8'hFE]}; }`；`CP_SRC_MASTER {bins m0={0}; bins m1={1};}`；`CX_ID_MASTER: cross CP_ID_VALUE, CP_SRC_MASTER`。在 `sample_all()` 中对 WRITE 采样 `tr.awid`，对 READ 采样 `tr.arid` |

#### B.1 vseq：`axicb_id_routing_vseq`

**继承**：`axicb_decode_base_vseq`（复用 `downstream_decode_checker`，可验证 9-bit ID）

**body() 内部三个主题**（顺序执行，不拆分 vseq）：

---

**主题 B-1：极值 ID 端到端验证**

对 ID ∈ {`8'h00`, `8'hFF`}，每个 ID 从 m0/m1 各发至 s0 和 s1（4条路径 × 2个ID = 8次事务）：

```
foreach id in {8'h00, 8'hFF}:
  foreach mst in {0, 1}:
    foreach slv_addr in {s0_mid_addr, s1_mid_addr}:
      fork...join:
        do_legal_write(mst, slv_addr, SINGLE, INCR, 4B, id)
        upstream_decode_checker(mst, WRITE, id, ups_err)        // 验证 bid == id
        downstream_decode_checker(mst, WRITE, slv_addr, id, downs_err)  // 验证 m_awid={mst[0],id}
      // 就地 error 判断并打印
      do_legal_read(mst, slv_addr, SINGLE, INCR, 4B, id)
      // do_legal_read 内置 rid == arid 校验
```

验证点：`8'h00` → downstream `{1'b0, 8'h00} = 9'h000` (m0) / `9'h100` (m1)；`8'hFF` → `9'h0FF` / `9'h1FF`。位拼接在极值处不发生溢出或截断。

---

**主题 B-2：同 upstream ID、不同 Master 并发访问同一 Slave**

```
fork
  begin  // m0: id=8'h55 → s0, addr=0x0000_A000, data=AAAA_1111
    do_legal_write(0, 0x0000_A000, SINGLE, INCR, 4B, 8'h55);
    do_legal_read(0, 0x0000_A000, SINGLE, INCR, 4B, 8'h55);
  end
  begin  // m1: id=8'h55 → s0, addr=0x0000_B000, data=BBBB_2222
    do_legal_write(1, 0x0000_B000, SINGLE, INCR, 4B, 8'h55);
    do_legal_read(1, 0x0000_B000, SINGLE, INCR, 4B, 8'h55);
  end
join
```

验证点：两者 upstream ID 同为 `8'h55`，但 downstream m_awid 分别为 `9'h055`(m0)和`9'h155`(m1)，crossbar 用高位区分源端口，B/R 响应不混淆。Scoreboard 验证 m0 读回自己写的数据，m1 同理。

---

**主题 B-3：中间值 ID 全路由矩阵**

id=`8'hAB`，遍历 m0/m1 × s0/s1（4条路径），每条路径 write+read，命中 `cg_id.CX_ID_MASTER` 的 id_mid bins。

**对应 Test**：`axicb_id_routing_test`

**Stage B 出口检查**：

| 项目 | 标准 |
|---|---|
| `cg_id.CX_ID_MASTER` | id_zero×m0、id_zero×m1、id_ff×m0、id_ff×m1、id_mid×m0、id_mid×m1 全部命中 |
| Scoreboard | `error_count == 0`（`do_legal_write/read` 内置 bid/rid 校验已覆盖 ID 还原） |

---

### Stage C：并发非阻塞与 AW 仲裁

**进入条件**：Stage B 通过。

#### C.0 基础设施修改（编码 vseq 前完成）

| 文件 | 修改内容 |
|---|---|
| `axicb_base_vseq.sv` | `do_legal_write` 增加 `input bit pipeline_mode = 0` 参数；当 `pipeline_mode=1` 时，内部 `wr_seq.wait_for_response = 0`，且不检查 bresp（立即返回，B 响应由 Scoreboard 异步捕获）。`do_legal_read` 同理 |

#### C.1 vseq：`axicb_concurrent_access_vseq`

**继承**：`axicb_base_vseq`

**body() 内部三个场景**（顺序执行，各场景之间 wait_cycles 隔离）：

---

**场景 C-1：不同 Slave 全并行（非阻塞黄金测试）**

```
fork
  begin  // m0 → s0: 10笔 INCR 4-beat burst, pipeline_mode=1
    for(i=0; i<10; i++)
      do_legal_write(0, 32'h0000_0000 + i*16, BURST_LEN_4BEATS, INCR, 4B, 8'h01, pipeline_mode=1);
    wait_cycles(300);
    for(i=0; i<10; i++)
      do_legal_read(0, 32'h0000_0000 + i*16, BURST_LEN_4BEATS, INCR, 4B, 8'h01);
  end
  begin  // m1 → s1: 10笔 INCR 4-beat burst, pipeline_mode=1
    for(i=0; i<10; i++)
      do_legal_write(1, 32'h0001_0000 + i*16, BURST_LEN_4BEATS, INCR, 4B, 8'h02, pipeline_mode=1);
    wait_cycles(300);
    for(i=0; i<10; i++)
      do_legal_read(1, 32'h0001_0000 + i*16, BURST_LEN_4BEATS, INCR, 4B, 8'h02);
  end
join
```

验证点：两 fork 分支访问不同 slave，物理路径（m00 arbiter / m01 arbiter）完全独立，不存在竞争，应接近同时完成。Scoreboard 验证 80 拍数据全部正确（4-beat × 10笔 × 2个 master）。

---

**场景 C-2：读写通道物理分离验证**

```
// 预写: m0 串行写 s0 地址 0x0000_C000~0x0000_C028 (10笔单拍), 数据 DATA_A[]
for(i=0; i<10; i++) do_legal_write(0, 32'h0000_C000+i*4, SINGLE, INCR, 4B, 8'h03);

fork
  begin  // 写通道: m0 写 s0 新地址 0x0000_D000~0x0000_D028 (DATA_B[])
    for(i=0; i<10; i++)
      do_legal_write(0, 32'h0000_D000+i*4, SINGLE, INCR, 4B, 8'h03, pipeline_mode=1);
  end
  begin  // 读通道: m0 读 s0 旧地址 0x0000_C000~0x0000_C028 (阻塞模式, 期望 DATA_A[])
    for(i=0; i<10; i++)
      do_legal_read(0, 32'h0000_C000+i*4, SINGLE, INCR, 4B, 8'h03);
  end
join
wait_cycles(200);
// 阻塞读回新地址验证 DATA_B[]
for(i=0; i<10; i++) do_legal_read(0, 32'h0000_D000+i*4, SINGLE, INCR, 4B, 8'h03);
```

验证点：DUT 读写通道物理分离（`axi_crossbar_rd` / `axi_crossbar_wr` 独立实例），m0 的写操作与读操作之间不相互阻塞。

---

**场景 C-3：同 Slave 写竞争（AW 仲裁触发）**

```
fork
  begin  // m0 → s0: 10笔单拍写, addr=0x0000_E000+
    for(i=0; i<10; i++) do_legal_write(0, 32'h0000_E000+i*4, SINGLE, INCR, 4B, 8'h04);
  end
  begin  // m1 → s0: 10笔单拍写, addr=0x0000_F000+
    for(i=0; i<10; i++) do_legal_write(1, 32'h0000_F000+i*4, SINGLE, INCR, 4B, 8'h05);
  end
join
// 阻塞读回全部 20 个地址，Scoreboard 验证数据正确
```

验证点：m00 端口 AW 仲裁器（`ARB_TYPE_ROUND_ROBIN=1, ARB_BLOCK=1, ARB_BLOCK_ACK=1`）同时收到 m0 和 m1 的请求，Round-Robin 交替授权。仲裁不影响最终功能正确性，Scoreboard 比对全部 20 笔数据。

**对应 Test**：`axicb_concurrent_access_test`

**Stage C 出口检查**：

| 项目 | 标准 |
|---|---|
| `cg_routing.CX_ROUTING` | 全部 8 个合法路由 bins 命中（m0/m1 × s0/s1 × W/R） |
| Scoreboard | `error_count == 0`，含写入 80+20+20 拍数据的比对 |
| 仿真日志 | 场景 C-1 两 fork 分支完成时间接近（观察 LOG 中时间戳对比，验证并行性） |

---

### Stage D：Burst 全类型覆盖

**进入条件**：Stage C 通过。

#### D.0 基础设施升级（代码量较大，独立 PR）

| 文件 | 修改内容 |
|---|---|
| `axicb_scoreboard.sv` | `calculate_beat_addr()` 增加 WRAP 分支：`wrap_bytes = burst_size_bytes * (awlen+1)`; `wrap_boundary = (base_addr / wrap_bytes) * wrap_bytes`; beat_i 地址 = `wrap_boundary + ((base_addr - wrap_boundary + i*burst_size_bytes) % wrap_bytes)` |
| `axi_slave_mem.sv` | 写/读地址计算函数中增加等价 WRAP 地址计算逻辑（与 Scoreboard 保持一致） |

验证 INF-D 正确性：在 Stage D vseq 跑通后，Scoreboard `error_count == 0` 即证明 WRAP 地址计算双方一致。

#### D.1 vseq：`axicb_burst_types_vseq`

**继承**：`axicb_base_vseq`。在单一 body() 中顺序覆盖以下 4 个子场景。

---

**子场景 D-1：INCR 长突发**

| awlen | 拍数 | Master | Slave | 地址 |
|---|---|---|---|---|
| 15 | 16 | m0 | s0 | `0x0000_0400` |
| 15 | 16 | m1 | s1 | `0x0001_0400` |
| 255 | 256 | m0 | s0 | `0x0000_1000` |

每条：`do_legal_write` 写入随机数据 → `do_legal_read` 读回 → Scoreboard 256 拍逐拍 compare。

验证点：`w_select_valid_reg` 在整个 burst 传输期间保持锁定（从 AW 握手到第 256 拍 `wlast`），W 通道路由不中断。

---

**子场景 D-2：FIXED Burst**

| awlen | 拍数 | Master | Slave | 地址 |
|---|---|---|---|---|
| 3 | 4 | m0 | s0 | `0x0001_2000` |
| 7 | 8 | m0 | s1 | `0x0001_3000` |

写入递增数据 `{A, B, C, D}`（4拍）→ FIXED 语义：同地址反复写，后拍覆盖前拍，最终存储最后一拍值 D。
读回单拍，期望 `rdata == D`。

注：Scoreboard 对 FIXED burst 的 `process_write` 中每拍 `word_addr` 相同，`ref_mem[word_addr]` 被覆盖 4 次，最终存 D——这是现有逻辑的自然行为，无需修改。

---

**子场景 D-3：WRAP Burst（依赖 INF-D）**

AXI4 规定 WRAP 的 awlen ∈ {1, 3, 7, 15}（即 2/4/8/16 拍）。

| awlen | awaddr | awsize | wrap_boundary | 地址序列（前4拍示例） |
|---|---|---|---|---|
| 3 (4拍) | `0x0000_4008` | SIZE_4BYTES | `0x0000_4000` | `0x4008` → `0x400C` → `0x4000` → `0x4004` |
| 7 (8拍) | `0x0000_6010` | SIZE_4BYTES | `0x0000_6000` | `0x6010` → `0x6014` → `0x6018` → `0x601C` → `0x6000` → ... |
| 15 (16拍) | `0x0000_7020` | SIZE_4BYTES | `0x0000_7000` | `0x7020` → ... → `0x7000` → ... |

每种：写 → 读回 → Scoreboard 按 WRAP 地址逐拍 compare（依赖 INF-D WRAP 地址计算）。

---

**子场景 D-4：Narrow Transfer 与非对齐首拍**

| 场景 | awsize | awlen | 地址 | wstrb 模式 |
|---|---|---|---|---|
| Narrow 1B INCR | SIZE_1BYTE | 3 (4拍) | `0x0001_5000` | `4'h1` → `4'h2` → `4'h4` → `4'h8` |
| Narrow 2B INCR | SIZE_2BYTES | 3 (4拍) | `0x0001_5100` | `4'h3` → `4'hC` → `4'h3` → `4'hC` |
| 非对齐首拍 | SIZE_4BYTES | 3 (4拍) | `0x0000_8001` | 首拍 `4'hE`（byte[1:3]有效），后续拍 `4'hF` |

验证点：Scoreboard `merge_data_with_strb` 按字节级合并，只有 strobe=1 的字节被更新；读回按相同地址 mask 比对。

**对应 Test**：`axicb_burst_types_test`

**Stage D 出口检查**：

| 项目 | 标准 |
|---|---|
| `cg_burst.BURST_TYPE_X_LEN` | FIXED×{4,8}beat、WRAP×{4,8,16}beat、INCR×{16,256}beat bins 命中 |
| `cg_burst.BURST_TYPE_X_SIZE` | INCR×SIZE_1B、INCR×SIZE_2B bins 命中 |
| Scoreboard | `error_count == 0`（WRAP 地址计算双方一致即证明 INF-D 正确） |

---

### Stage E：Thread Tracking 与 Ordering Protection

**进入条件**：Stage D 通过（INF-C1 的 pipeline_mode 已就绪）。

#### E.0 基础设施修改（必要前提）

| 文件 | 修改内容 |
|---|---|
| `axi_slave_responder.sv` | 新增 `int unsigned b_resp_delay = 0` 和 `r_resp_delay = 0` 参数；在响应握手前插入 `repeat(b_resp_delay) @(posedge aclk)`。参数通过 `uvm_config_db` 从 test 层注入 |

> **为何必须有 slave delay**：Thread Tracking 验证的核心是观察 DUT 在 thread slot 已满时对新 AW 的背压行为。若 slave 响应极快（0 latency），B 响应在第 3 笔 AW 发起前已返回，thread slot 已释放，测试无法触发背压条件。推荐配置 `b_resp_delay = 10 cycles`。

#### E.1 vseq：`axicb_thread_tracking_vseq`

**继承**：`axicb_base_vseq`

**body() 开头**：通过 `uvm_config_db::set` 配置 slave b_resp_delay = 10，结尾还原为 0。

---

**场景 E-1：Thread Slot 上限（S_THREADS=2）**

```
// 3笔写并发到 m0 → s0，3个不同 ID
fork
  do_legal_write(0, 32'h0000_1000, SINGLE, INCR, 4B, 8'h01);  // slot[0] 被占
  do_legal_write(0, 32'h0000_2000, SINGLE, INCR, 4B, 8'h02);  // slot[1] 被占
  do_legal_write(0, 32'h0000_3000, SINGLE, INCR, 4B, 8'h03);  // 无空闲 slot → awready=0 → 此 fork 分支阻塞
join
// fork 退出后读回 3 个地址验证
```

DUT 行为：`axi_crossbar_addr` 中 `thread_active` 满时，`!all_active` 为 0，新 AW 的 `s_aready = 0`，第 3 个序列的 `start_item/finish_item` 阻塞在驱动层。当 B 响应返回（10 cycle 后），某个 slot 释放，第 3 笔 AW 得以通过。fork 整体 join 后数据完整。

---

**场景 E-2：同 ID 锁定 Destination（Ordering Protection）**

```
// 步骤 1: m0 ID=0x10 → s0, pipeline_mode=1 (AW+W 发出后立即返回，不等 B)
do_legal_write(0, 32'h0000_F000, SINGLE, INCR, 4B, 8'h10, pipeline_mode=1);

// 步骤 2: m0 ID=0x10 → s1 (此时 B 尚未返回，slot 记录 ID=0x10 锁定 dest=s0)
// crossbar 检测到 thread_match=1 但 thread_dest != s1 → awready=0 → 阻塞在此
do_legal_write(0, 32'h0001_F000, SINGLE, INCR, 4B, 8'h10);

// 步骤 3: 读回两地址验证数据
do_legal_read(0, 32'h0000_F000, SINGLE, INCR, 4B, 8'h10);
do_legal_read(0, 32'h0001_F000, SINGLE, INCR, 4B, 8'h10);
```

验证点：步骤 2 的 AW 延迟 > b_resp_delay（10 cycles），说明确实被 DUT 阻塞等待 slot 释放。最终两地址数据正确，ID 还原无误。

---

**场景 E-3：正常 2-ID 并发（基准对照，验证不过度限制）**

```
// S_THREADS=2，2个不同 ID 并发应直接通过，无阻塞
fork
  do_legal_write(0, 32'h0000_4000, SINGLE, INCR, 4B, 8'h20);
  do_legal_write(0, 32'h0000_5000, SINGLE, INCR, 4B, 8'h21);
join
do_legal_read(0, 32'h0000_4000, SINGLE, INCR, 4B, 8'h20);
do_legal_read(0, 32'h0000_5000, SINGLE, INCR, 4B, 8'h21);
```

验证点：2 笔并发无阻塞（AW 延迟接近 0），为场景 E-1 的正常基准形成对比。

**对应 Test**：`axicb_thread_tracking_test`（注意：test 的 `build_phase` 需注入 slave delay 配置，或由 vseq 内部注入）

**Stage E 出口检查**：

| 项目 | 标准 |
|---|---|
| 场景 E-1 | 仿真 LOG 可见第 3 笔 AW 延迟 > 10 cycles（slave delay），证明 DUT 阻塞生效 |
| 场景 E-2 | 步骤 2 的 AW 延迟 > b_resp_delay，步骤 3 数据正确，ID 还原无误 |
| 场景 E-3 | 2 笔并发快速完成（AW 无阻塞），形成对照 |
| Scoreboard | `error_count == 0`（数据最终全部正确） |

---

### Stage F：随机回归与覆盖率收敛

**进入条件**：Stage A~E 全部通过。无新增 vseq，在现有 vseq 基础上注入随机性。

| 目标 | 实现方式 |
|---|---|
| `cg_burst` 全覆盖收敛 | 在 `axicb_burst_types_vseq.body()` 末尾增加随机化循环：`repeat(20)` 随机选择 burst_type×burst_len 组合，发 write+read |
| `cg_comprehensive` 全覆盖 | 在 `axicb_smoke_vseq` 或 `axicb_burst_types_vseq` 中随机化 WRITE/READ × INCR/FIXED × 各 len |
| 全 Test 回归无退化 | 按顺序跑全部 11 个 Test（包括新增 4 个），Scoreboard `error_count == 0` |

---

## 四、SVA 断言计划

独立于 vseq，绑定于 DUT 关键节点，仿真启动时自动生效。

| 编号 | 绑定位置 | 断言内容 | 验证的关键行为 |
|---|---|---|---|
| SVA-01 | `axi_crossbar_wr`（S侧地址解码失败路径） | `@(posedge clk) (aw_internal_valid && !match) \|=> ##[1:100] (b_decerr_valid)` | 地址解码失败必须最终产生 DECERR B 响应，无遗漏 |
| SVA-02 | `axi_crossbar_wr`（W通道路由锁） | `@(posedge clk) (w_select_valid && !wlast) \|=> !new_aw_accepted` | W burst 传输期间 AW 仲裁不得接受新 AW（防止 W 通道路由混淆） |
| SVA-03 | `axi_crossbar_rd`（DECERR 计数器） | `@(posedge clk) (decerr_len_reg > 0) \|=> ##1 (decerr_len_reg == ($past(decerr_len_reg) - 1) \|\| decerr_len_reg == $past(decerr_len_reg))` | DECERR 计数器只减不增（无跳变），精确控制 DECERR R 拍数 |
| SVA-04 | `arbiter.v`（grant 互斥） | `@(posedge clk) $onehot0(grant)` | 仲裁器任意时刻最多一个 grant 有效，防止多 master 同时获得授权 |
| SVA-05 | `axi_crossbar_wr`（9-bit ID 高位） | `@(posedge clk) (m_awvalid && m_awready) \|-> (m_awid[M_ID_WIDTH-1:S_ID_WIDTH] == src_port_idx)` | downstream AWID 的高位字段必须等于对应源端口编号，验证 ID 扩展逻辑 |

---

## 五、覆盖率退出标准

| Covergroup | 退出门槛 | 覆盖内容 |
|---|---|---|
| `cg_routing.CX_ROUTING` | **100%**（12 bins） | 2M × {s0, s1, DECERR} × 2T |
| `cg_response.CX_RESP` | **100%**（4 bins） | 当前已满足，回归保持 |
| `cg_burst.BURST_TYPE_X_LEN` | ≥ **90%** | FIXED/INCR/WRAP × 主要长度 |
| `cg_burst.BURST_TYPE_X_SIZE` | ≥ **80%** | 1B/2B/4B × FIXED/INCR |
| `cg_comprehensive.TYPE_X_BURST_X_LEN` | ≥ **85%** | W/R × burst_type × len |
| `cg_id.CX_ID_MASTER` | **100%**（6 bins） | {0x00, 0xFF, mid} × {m0, m1} |
| Scoreboard `error_count` | **= 0**（全部 Test 合并） | 数据完整性，ID 还原，DECERR 响应正确性 |
| Scoreboard `decerr_count` | **≥ 50** | 充分的 DECERR 路径统计 |

---

## 附录：Test 全览（预期最终状态）

| # | Test | VSeq | Stage | 核心验证点集群 |
|---|---|---|---|---|
| 1 | `axicb_smoke_test` | `axicb_smoke_vseq` | 已完成 | 4路路由，基础W+R |
| 2 | `axicb_decerr_single_test` | `axicb_decerr_single_vseq` | 已完成 | 单拍DECERR，downstream隔离 |
| 3 | `axicb_decerr_burst_test` | `axicb_decerr_burst_vseq` | 已完成 | 多拍DECERR，状态恢复 |
| 4 | `axicb_decerr_dual_mst_test` | `axicb_decerr_dual_mst_vseq` | 已完成 | 双master DECERR并发，交叉R/W |
| 5 | `axicb_decerr_id_test` | `axicb_decerr_id_vseq` | 已完成 | 同ID DECERR+合法恢复 |
| 6 | `axicb_decode_full_range_test` | `axicb_decode_full_range_vseq` | 已完成(+bugfix) | S0全域decode，upstream/downstream checker |
| 7 | `axicb_decode_s1_test` | `axicb_decode_s1_vseq` | Stage A | S1全域decode，S0/S1边界精确验证 |
| 8 | `axicb_id_routing_test` | `axicb_id_routing_vseq` | Stage B | 9-bit ID扩展，极值ID，同ID并发 |
| 9 | `axicb_concurrent_access_test` | `axicb_concurrent_access_vseq` | Stage C | 非阻塞并行，R/W通道分离，AW仲裁 |
| 10 | `axicb_burst_types_test` | `axicb_burst_types_vseq` | Stage D | INCR长突发，FIXED，WRAP，Narrow，非对齐 |
| 11 | `axicb_thread_tracking_test` | `axicb_thread_tracking_vseq` | Stage E | Thread slot上限，同ID dest锁定，正常对照 |
