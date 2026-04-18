# AXI Crossbar Verification Plan

## 1. 文档定位

本文档是一份严格基于当前 `axi-crossbar` 仓库真实代码状态制定的验证计划。

这份计划的出发点不是“理论上一个 AXI crossbar 应该怎么验证”，而是：

- 当前仓库里真正会被编译、会被运行的内容是什么
- 当前 `smoke test` 实际覆盖到了什么
- 当前 VIP / scoreboard / coverage 还缺什么能力
- 在这些现实约束下，后续验证应该怎样一步一步、循序渐进地展开

---

## 2. 代码事实基线

### 2.1 当前真正参与编译和回归的内容

根据以下代码文件：

- [uvm/sim/Makefile](/home/host/Desktop/AXI_CROSSBAR/axi-crossbar/uvm/sim/Makefile:1)
- [uvm/env/axicb_pkg.sv](/home/host/Desktop/AXI_CROSSBAR/axi-crossbar/uvm/env/axicb_pkg.sv:1)
- [uvm/test/axicb_tests_lib.svh](/home/host/Desktop/AXI_CROSSBAR/axi-crossbar/uvm/test/axicb_tests_lib.svh:1)
- [uvm/seq_lib/axicb_virt_seq_lib.svh](/home/host/Desktop/AXI_CROSSBAR/axi-crossbar/uvm/seq_lib/axicb_virt_seq_lib.svh:1)

当前实际编译并可运行的验证内容只有：

- `axicb_base_test`
- `axicb_smoke_test`
- `axicb_base_virtual_sequence`
- `axicb_smoke_virtual_sequence`
- `axicb_single_write_sequence`
- `axicb_single_read_sequence`

当前 `Makefile` 中：

- 默认 `TESTNAME = axicb_smoke_test`
- `TESTS = smoke`

所以当前真实回归基线只有 `smoke`。

### 2.2 明确排除的旧 RAM testcase

以下文件虽然存在于仓库中，但**当前不参与编译，也不应该纳入当前 crossbar 验证状态统计**：

- `axiram_fixed_test.sv`
- `axiram_reset_test.sv`
- `axiram_narrow_test.sv`
- `axiram_pipeline_test.sv`
- `axiram_unaligned_test.sv`
- 对应 `axiram_*_virtual_sequence.sv`

原因很明确：

- 它们在 `axicb_tests_lib.svh` 中被注释掉了
- 它们在 `axicb_virt_seq_lib.svh` 中也被注释掉了
- `Makefile` 的 regression 列表里也没有它们

因此，**这份验证计划完全忽略这些旧 RAM testcase 的存在**，并以“除了 `smoke` 之外，其它 crossbar 测试点都尚未真正验证”为前提。

---

## 3. DUT 与环境现状

### 3.1 DUT 当前配置

根据 [uvm/testbench/axi_crossbar_tb.sv](/home/host/Desktop/AXI_CROSSBAR/axi-crossbar/uvm/testbench/axi_crossbar_tb.sv:1)，当前 DUT 是一个固定参数配置下的 `2x2 AXI crossbar`：

- 上游端口：2 个
  - `s00_axi`
  - `s01_axi`
- 下游端口：2 个
  - `m00_axi`
  - `m01_axi`
- 数据宽度：`32 bit`
- 地址宽度：`32 bit`
- 上游 ID 宽度：`8 bit`
- 下游 ID 宽度：`9 bit`
- 地址窗口：
  - `m00`: `0x0000_0000 ~ 0x0000_FFFF`
  - `m01`: `0x0001_0000 ~ 0x0001_FFFF`
- 每个下游端口 `M_ISSUE = 4`
- 每个上游端口 `THREADS = 2`
- 每个上游端口 `ACCEPT = 16`
- `AWUSER/WUSER/BUSER/ARUSER/RUSER` 当前配置下都不使能
- `SECURE` 当前不使能
- `M_REGIONS = 1`

### 3.2 当前验证环境已经具备的能力

当前环境已经具备：

- 双 master agent
- 双 slave agent
- virtual sequencer
- 一个 master-side end-to-end scoreboard
- 一个基础 coverage collector
- interface 级 AXI ready/valid 稳定性 assertion
- 基本的单事务 write/read 激励能力

### 3.3 当前验证环境还不具备或还不完整的能力

通过代码检查，当前环境存在这些明确缺口：

#### A. 只有 smoke 级 directed 流量

当前真正使用的 sequence 只有：

- [axicb_smoke_virtual_sequence.sv](/home/host/Desktop/AXI_CROSSBAR/axi-crossbar/uvm/seq_lib/axicb_smoke_virtual_sequence.sv:1)

尚无任何真正编译启用的 crossbar 专项 directed testcase。

#### B. 还没有 routing scoreboard

当前 [axicb_scoreboard.sv](/home/host/Desktop/AXI_CROSSBAR/axi-crossbar/uvm/env/axicb_scoreboard.sv:1) 只是 master-side end-to-end memory scoreboard。

它能检查：

- master 最终读回来的数据对不对

但它不能检查：

- 请求是否被路由到正确的下游 slave
- downstream ID 是否扩展正确
- response 是否从正确的下游回到了正确的上游 master

#### C. coverage 很初级

当前 [axicb_coverage.sv](/home/host/Desktop/AXI_CROSSBAR/axi-crossbar/uvm/env/axicb_coverage.sv:1) 只覆盖了：

- `READ/WRITE`
- `FIXED/INCR`
- 部分 burst len / size

它**没有覆盖**：

- source master
- target slave
- route
- address boundary
- ID 场景
- contention
- outstanding depth
- reset
- backpressure

#### D. ID 验证能力还没有真正启用

在 [axi_master_single_sequence.sv](/home/host/Desktop/AXI_CROSSBAR/axi-crossbar/uvm/vip/seq_lib/axi_master_single_sequence.sv:1) 中：

- `tr_id` 目前默认是 `'0`
- 注释里也明确写着 `smoke test only`

所以当前并没有真正验证：

- 非零 ID
- 多 ID 并发
- ID 扩展 / 还原

#### E. 下游 slave VIP 目前不支持系统化 backpressure / error injection

当前 responder 行为是：

- `AWREADY/ARREADY` 主动拉高等待握手
- `WREADY` 在需要接收时拉高
- `B/R` 默认返回 `OKAY`

也就是说，当前环境还没有真正具备：

- 可控 backpressure
- 可控 latency
- `SLVERR/DECERR` 注入

#### F. WRAP 还不能正式验证

在 [axi_slave_mem.sv](/home/host/Desktop/AXI_CROSSBAR/axi-crossbar/uvm/vip/axi_slave_mem.sv:43) 中：

- `calc_beat_addr()` 对 `WRAP` 还是 `TODO`

因此，虽然 AXI 类型定义里有 `WRAP`，但**当前环境还不具备可靠验证 WRAP 的能力**。

---

## 4. 当前真实验证状态

### 4.1 已完成

当前唯一真正完成的验证阶段是：

### Phase 0: Smoke Connectivity

当前 [axicb_smoke_virtual_sequence.sv](/home/host/Desktop/AXI_CROSSBAR/axi-crossbar/uvm/seq_lib/axicb_smoke_virtual_sequence.sv:1) 实际覆盖了：

- `master0 -> slave0`
- `master0 -> slave1`
- `master1 -> slave0`
- `master1 -> slave1`

对每条路径做的事情是：

- 2 到 10 笔随机单拍事务
- 地址落在目标 slave 的合法窗口内
- `INCR`
- `burst_len = 1 beat`
- `burst_size = 4 bytes`
- 地址 4B 对齐
- `WSTRB = 4'hF`
- write 后紧接 read
- 在上游 master 侧比较读回数据

### 4.2 Smoke 仍然没有覆盖的点

即使 `smoke` 已通过，下面这些仍然都还**没有真正验证**：

- 非零 ID
- 多 ID 并发
- 多拍 burst
- `FIXED`
- `WRAP`
- narrow transfer
- unaligned transfer
- partial strobe
- 地址边界点
- 非法地址 / hole
- 两个 master 同时访问
- contention / arbitration
- outstanding / accept / thread limit
- 非阻塞 pipeline
- backpressure
- error response
- reset 中断事务
- response return correctness
- route transform correctness

因此，接下来的计划必须从这些空白点出发，而不是误以为旧 `axiram_*` case 已经覆盖了这些内容。

---

## 5. 验证策略总纲

针对当前这个 AXI crossbar，最合理的验证推进顺序是：

1. `smoke`
   - 先证明 4 条基本路径打通

2. `验证环境加固`
   - 先让 scoreboard / coverage / VIP 具备支持后续深度验证的能力

3. `单路径 directed 功能验证`
   - 先在没有竞争的情况下，把协议基本语义、数据语义、地址语义验证扎实

4. `路径与路由验证`
   - 再去验证 crossbar 作为 crossbar 的核心价值：decode、route、ID transform

5. `并发、仲裁、容量限制验证`
   - 再进入真正体现 interconnect 特性的场景

6. `鲁棒性与异常场景验证`
   - reset、backpressure、错误响应、随机流量

7. `coverage closure`
   - 最后用 constrained-random 和 coverage 收尾

这比“从协议点把 test 点平铺开”更适合你当前这个项目，因为它遵循了真实依赖关系：

- 没有先把环境能力补足，就不适合直接做深场景
- 没有先把单路径和路由语义做扎实，就不适合直接上大并发随机

---

## 6. 分阶段完整验证计划

下面的阶段顺序就是推荐的实际执行顺序。

## Phase 0: Smoke Connectivity

### 状态

- 已完成

### 目标

- 确认 4 条 `master -> slave` 路径都能完成最基础的 write/read 闭环

### 当前使用用例

- `axicb_smoke_test`

### 退出准则

- `smoke` 稳定通过
- 基础仿真流程、编译流程、DUT 连通性无阻塞

---

## Phase 1: 验证环境加固

### 状态

- 当前最应该先做

### 目标

- 让后续 deeper verification 的结果可信

### 这一阶段必须完成的工作

#### 1. Scoreboard 加固

当前 master-side scoreboard 继续保留，但需要修正/增强：

- 地址宽度必须完整使用 `ADDR_WIDTH`
- 日志和地址计算不能再残留 16-bit 假设
- partial transaction 不应错误写入参考内存
- 后续要支持 burst、narrow、unaligned 的正确建模

#### 2. 新增 routing scoreboard 设计

这是 crossbar 项目必须有的第二套 scoreboard。

它应该检查：

- 上游请求应去哪个下游 slave
- downstream ID 是否正确扩展
- downstream response 是否正确回到原始 upstream master

#### 3. Coverage 重构

当前 coverage 太初级，至少应新增：

- source master
- target slave
- route
- address boundary
- alignment
- ID scenario
- contention
- outstanding depth
- reset point
- backpressure mode

#### 4. VIP 能力增强

在进入后续阶段前，建议先把下列能力补齐：

- sequence 可配置非零 `tr_id`
- slave responder 可配置 latency
- slave responder 可配置 `READY`/`VALID` backpressure
- slave responder 可配置 `OKAY/SLVERR/DECERR`
- 参考内存和 scoreboard 支持 `WRAP`

#### 5. Assertion 扩展

当前 `axi_if.sv` 已有基础握手稳定性 assertion，这是好基础。

建议继续补：

- `WLAST` 合法性
- `RLAST` 合法性
- response 一定有历史 request 匹配
- outstanding 不下溢/不上溢
- reset 后队列清空
- response return path correctness

### 退出准则

- 新旧 scoreboard 分工明确
- coverage 模型升级完成
- VIP 具备后续阶段必须的注入能力
- assertion 基础框架 ready

---

## Phase 2: 单路径基础功能验证

### 目标

- 在“无竞争、无复杂并发”的前提下，把 AXI 的基本数据语义验证扎实

### 覆盖重点

- 单拍 write/read
- 多拍 `INCR`
- 多拍 `FIXED`
- 地址对齐
- full strobe
- blocking response

### 建议新增 testcase

- `axicb_basic_single_beat_test`
- `axicb_basic_incr_burst_test`
- `axicb_basic_fixed_burst_test`

### 要点说明

- 这一阶段仍然只做单一路径，不引入 contention
- 路径应覆盖 4 个 master-slave 组合
- 每个组合都要覆盖：
  - write only
  - read only
  - write then read

### Checker 依赖

- master-side end-to-end scoreboard

### 退出准则

- 所有 4 条路径上的基本读写和 burst 行为都稳定通过

---

## Phase 3: 地址译码与路径验证

### 目标

- 验证地址决定路由是否正确

### 覆盖重点

- 每个地址窗口的起始地址
- 每个地址窗口的末尾地址
- 靠近边界的地址
- 不同 master 发往同一目标 slave
- 不同 master 发往不同目标 slave

### 建议新增 testcase

- `axicb_route_decode_test`
- `axicb_route_boundary_test`
- `axicb_cross_path_basic_test`

### 必须检查的内容

- 地址属于 `0x0000_xxxx` 时必须去 `m00`
- 地址属于 `0x0001_xxxx` 时必须去 `m01`
- 上游请求和下游观察到的事务必须一一对应

### Checker 依赖

- routing scoreboard 必须在这一阶段投入使用

### 退出准则

- decode/routing 在边界点和普通点都正确
- routing scoreboard 稳定无误报

---

## Phase 4: 数据语义增强验证

### 目标

- 验证 AXI 数据通道的细粒度语义

### 覆盖重点

- partial `WSTRB`
- narrow transfer
- unaligned `INCR`
- unaligned `FIXED`

### 说明

虽然仓库里有旧的 `axiram_*` 思路，但这些都不计入当前验证完成状态。
这一阶段应重新以 `axicb_*` 的 testcase 形式，为 crossbar 环境正式重建这些测试。

### 建议新增 testcase

- `axicb_partial_strobe_test`
- `axicb_narrow_incr_test`
- `axicb_unaligned_incr_test`
- `axicb_unaligned_fixed_test`

### 依赖

- scoreboard 对地址和 byte enable 的建模必须可靠

### 暂缓项

- `WRAP` 先不在本阶段做 closure
- 因为当前 `axi_slave_mem::calc_beat_addr()` 还不支持 `WRAP`

### 退出准则

- partial write / narrow / unaligned 都在 4 条路径上至少完成基本闭环验证

---

## Phase 5: ID 映射与响应回传验证

### 目标

- 验证 crossbar 的 ID transform 和 response return 机制

### 当前为何不能直接跳过这一阶段

因为 crossbar 和 RAM 最大的区别之一就是：

- 它必须把请求送对地方
- 也必须把响应送回对的人

而这一步当前尚未真正验证。

### 覆盖重点

- 非零 ID
- 不同 master 使用相同 upstream ID
- 同一 master 使用多个不同 ID
- downstream 观察到的扩展 ID 是否符合规则
- response 回来后 upstream ID 是否恢复正确

### 建议新增 testcase

- `axicb_id_basic_test`
- `axicb_same_id_diff_master_test`
- `axicb_multi_id_single_master_test`
- `axicb_response_return_test`

### 依赖

- sequence 需要开放 `tr_id` 控制
- routing scoreboard 需要具备 ID 匹配能力

### 退出准则

- ID 扩展、还原、返回路径全部验证通过

---

## Phase 6: 仲裁与并发验证

### 目标

- 验证 DUT 在真正的 interconnect 场景下仍然正确

### 覆盖重点

- 两个 master 同时访问同一个 slave
- 两个 master 同时访问不同 slave
- read/read 并发
- write/write 并发
- read/write 混合并发
- 长 burst 和短 burst 混合

### 建议新增 testcase

- `axicb_dual_master_same_slave_write_test`
- `axicb_dual_master_same_slave_read_test`
- `axicb_dual_master_same_slave_mixed_test`
- `axicb_dual_master_diff_slave_parallel_test`

### 这一阶段重点关注的问题

- arbitration fairness
- starvation
- wrong-route under contention
- response mis-return under contention

### 退出准则

- contention 场景下 routing scoreboard 和 end-to-end scoreboard 都稳定通过

---

## Phase 7: Outstanding / Thread / Accept / Pipeline 验证

### 目标

- 验证参数化容量限制和流量堆积场景

### 基于当前 DUT 参数，应重点验证

- `M00_ISSUE = 4`
- `M01_ISSUE = 4`
- `S00_THREADS = 2`
- `S01_THREADS = 2`
- `S00_ACCEPT = 16`
- `S01_ACCEPT = 16`

### 覆盖重点

- 对单个下游 slave 逐步增加 outstanding 深度
- 命中 issue limit 之后 DUT 是否正确 backpressure
- 多 ID 并发时 thread limit 行为
- 非阻塞连续发流量时是否丢事务

### 建议新增 testcase

- `axicb_outstanding_limit_test`
- `axicb_thread_limit_test`
- `axicb_accept_depth_test`
- `axicb_pipeline_nonblocking_test`

### 依赖

- sequence 需要系统化支持 `wait_for_response = 0`
- scoreboard / checker 要能处理事务完成顺序与发起顺序不同的情况

### 退出准则

- 所有容量限制相关场景通过
- 无 deadlock / no-progress / counter corruption

---

## Phase 8: Reset 与恢复验证

### 目标

- 验证 reset 打断事务和恢复后的行为

### 覆盖重点

- idle reset
- mid-AW reset
- mid-W reset
- AW/W 已进但 B 未返时 reset
- mid-AR reset
- mid-R reset
- contention 中 reset
- reset 后重新发事务

### 建议新增 testcase

- `axicb_reset_idle_test`
- `axicb_reset_mid_write_test`
- `axicb_reset_mid_read_test`
- `axicb_reset_under_contention_test`
- `axicb_post_reset_recovery_test`

### 重点检查

- DUT 输出回到空闲态
- monitor / responder / scoreboard 队列清空
- 无 ghost response
- reset 后功能能恢复

### 退出准则

- reset 类场景收敛

---

## Phase 9: Backpressure、Latency 与异常响应验证

### 目标

- 验证慢下游、慢上游和异常响应场景

### 覆盖重点

- slave 对 `AW/W/AR` 施加 backpressure
- master 对 `B/R` 施加 backpressure
- 长 latency 响应
- `SLVERR`
- `DECERR`
- 非法地址 / 无路由地址

### 建议新增 testcase

- `axicb_aw_backpressure_test`
- `axicb_w_backpressure_test`
- `axicb_ar_backpressure_test`
- `axicb_b_r_backpressure_test`
- `axicb_slverr_test`
- `axicb_decerr_test`
- `axicb_illegal_addr_test`

### 依赖

- slave responder 需要支持 backpressure 和 error injection

### 暂缓说明

如果这些注入能力还没有补完，这一阶段先不做 closure，但必须在验证计划中保留。

### 退出准则

- backpressure / latency / error path 全部验证通过

---

## Phase 10: WRAP 与完整协议补点

### 目标

- 完成 AXI burst 类型层面的完整性验证

### 当前为什么单独列阶段

因为当前环境对 `WRAP` 没有完整支持，直接把它和前面的基础功能混在一起会破坏计划的逻辑顺序。

### 需要先补的能力

- `axi_slave_mem::calc_beat_addr()` 支持 `WRAP`
- scoreboard 支持 `WRAP`
- directed sequence 能正确构造 `WRAP` 访问

### 建议新增 testcase

- `axicb_wrap_basic_test`
- `axicb_wrap_boundary_test`
- `axicb_wrap_under_contention_test`

### 退出准则

- `WRAP` 场景功能和路由都通过

---

## Phase 11: Constrained-Random Regression 与 Coverage Closure

### 目标

- 用随机流量收敛 corner case

### 随机化维度

- source master
- target slave
- trans type
- burst len
- burst size
- burst type
- alignment
- ID
- outstanding depth
- backpressure mode
- latency
- reset insertion

### 建议新增 testcase

- `axicb_random_basic_test`
- `axicb_random_contention_test`
- `axicb_random_limit_test`
- `axicb_random_reset_test`
- `axicb_random_full_feature_test`

### 回归建议

- 日常小回归：固定种子 + 少量随机种子
- 每晚回归：数十到数百 seed
- closure 回归：大规模随机

### 退出准则

- functional coverage 达标
- code coverage 达标或 waiver 完成
- 无新增高优先级 bug

---

## 7. 每一阶段的推荐交付物

为了让整个计划有清晰的工程节奏，每阶段都建议至少交付以下内容：

### 每阶段必须交付

- 对应 testcase
- 对应 sequence
- 对应 scoreboard/checker/assertion 增量
- 对应 coverage 增量
- 对应 bug 列表 / issue 记录
- 对应回归结果

### 每阶段结束时必须回答的问题

- 这阶段打算验证的东西是否真的被验证到了？
- 环境有没有能力支撑这阶段的结论？
- coverage 是否真实反映了这阶段的完成度？
- 是否还有 blocker 影响下一阶段？

---

## 8. 推荐的 testcase 建设顺序

为了尽量循序渐进，建议你按下面顺序真正写用例：

1. 保留并稳定 `axicb_smoke_test`
2. `axicb_basic_single_beat_test`
3. `axicb_basic_incr_burst_test`
4. `axicb_basic_fixed_burst_test`
5. `axicb_route_boundary_test`
6. `axicb_partial_strobe_test`
7. `axicb_narrow_incr_test`
8. `axicb_unaligned_incr_test`
9. `axicb_id_basic_test`
10. `axicb_dual_master_same_slave_*`
11. `axicb_outstanding_limit_test`
12. `axicb_reset_*`
13. `axicb_backpressure_*`
14. `axicb_slverr/decerr/illegal_addr_test`
15. `axicb_wrap_*`
16. `axicb_random_*`

这个顺序的核心思想是：

- 先从简单、确定、可 debug 的 directed case 入手
- 再逐步增加协议复杂度
- 最后再上随机和 closure

---

## 9. 当前阶段的直接下一步

如果以“`smoke` 已完成”为当前起点，那么下一步不应该直接去做大而全的随机验证，而应该按下面顺序开展：

1. 完成 `Phase 1` 环境加固
2. 新建并跑通 `axicb_basic_single_beat_test`
3. 新建并跑通 `axicb_basic_incr_burst_test`
4. 新建 `routing scoreboard`
5. 开始做 `route boundary + non-zero ID`

也就是说：

**你现在最应该做的不是继续扩展 smoke，而是把环境先升级到“能够支持深验证”的状态，然后从基础 directed 用例重新建立一套真正属于 crossbar 项目的 testcase 矩阵。**

---

## 10. 最终结论

基于当前仓库真实状态，可以得出非常明确的结论：

- 当前真正完成的验证只有 `smoke`
- 旧的 `axiram_*` testcase 不能算进当前 crossbar 验证完成度
- 当前环境还不具备直接开展完整 crossbar closure 的能力
- 最合理的路线不是“把所有协议点罗列出来”，而是：
  - 先 `smoke`
  - 再 `环境加固`
  - 再 `基础 directed`
  - 再 `路由 / ID`
  - 再 `并发 / 限制`
  - 再 `reset / backpressure / error`
  - 最后 `random + coverage closure`

这才是一份符合当前项目真实状态、同时也符合数字验证工程实际流程的完整验证计划。
