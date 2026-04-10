# AXI Crossbar Smoke Test 需求说明

## 1. 文档目的
本文件用于说明当前 `axi_crossbar` 项目中 **smoke test** 需要实现的最基本功能与验证目标。

该 smoke test 的目标不是覆盖 AXI 协议全部 corner case，也不是完成复杂仲裁与压力测试，而是用于确认：
- 当前 UVM 测试平台已经基本接通
- master VIP、slave VIP、monitor、DUT 之间连接正确
- crossbar 的最基本读写路径工作正常
- slave responder 与 memory model 能正确配合
- 基本 reset、写入、读回、响应链路没有阻塞或死锁

---

## 2. smoke test 的核心目标
smoke test 必须完成以下最基础验证：

1. **Reset 后系统可进入空闲状态**
2. **上游 master 能成功发起最简单写事务**
3. **写事务能通过 crossbar 路由到预期下游 slave**
4. **下游 slave responder 能接收请求并将数据写入 slave mem**
5. **上游 master 能对同一地址发起最简单读事务**
6. **读事务能正确通过 crossbar 返回**
7. **master 读回的数据必须等于之前写入的数据**
8. **B/R 响应必须正常返回，系统不能超时、死锁**

---

## 3. smoke test 范围约束
为了让 smoke test 聚焦于“平台连通性”和“最基本功能正确性”，本阶段必须刻意简化场景：

- 只做 **aligned address** 访问
- 只做 **single-beat transaction**
- `AWLEN = 0`
- `ARLEN = 0`
- `AWSIZE = ARSIZE = 2`（32-bit data width，对应 4 byte）
- `AWBURST = ARBURST = INCR`
- `BRESP = RRESP = OKAY`
- `QOS = 0`
- `USER = 0`
- 不做 WRAP burst
- 不做 unaligned transfer
- 不做 backpressure
- 不做 error injection
- 不做 reset 中断事务
- 不做并发竞争仲裁测试

本阶段的目的仅是：**先验证系统最小闭环成立。**

---

## 4. smoke test 至少应覆盖的基本路径
因为 DUT 是 2x2 crossbar，因此 smoke test 至少应覆盖：

### 4.1 从两个上游 master 发起事务
- `master0`
- `master1`

### 4.2 到两个下游 slave 出口
- `slave0`
- `slave1`

### 4.3 最小连通性路径
建议至少验证以下四条路径：

1. `master0 -> slave0`
2. `master0 -> slave1`
3. `master1 -> slave0`
4. `master1 -> slave1`

每条路径都应完成：
- 1 次 single-beat write
- 1 次 single-beat read
- 读回数据比对

这样可以证明：
- 两个 master 输入口都已接通
- 两个 slave 输出口都已接通
- crossbar 基本地址路由有效
- slave mem 可写可读

---

## 5. smoke test 中必须检查的内容
### 5.1 Reset 检查
- reset 期间，master/slave 端负责驱动的 VALID 信号必须满足协议要求
- reset 释放后，系统能够恢复到可发起事务状态
- reset 后不能立即出现异常死锁

### 5.2 写事务检查
- `AW/W/B` 通道能完整完成一笔最简单写事务
- `WLAST` 在 single-beat 写中行为正确
- slave mem 中对应地址的数据被正确更新
- `BRESP == OKAY`

### 5.3 读事务检查
- `AR/R` 通道能完整完成一笔最简单读事务
- `RLAST` 在 single-beat 读中行为正确
- 返回数据等于之前写入 slave mem 的数据
- `RRESP == OKAY`

### 5.4 路由检查
- 给定地址必须被 crossbar 路由到预期 slave 端口
- 非目标 slave 不应错误接收该事务

### 5.5 超时检查
- 写响应 `B` 必须在限定时间内返回
- 读响应 `R` 必须在限定时间内返回
- 若超时，应直接报错并判定 smoke test 失败

### 5.6 监控链路检查
- monitor 至少应能观察到完整 write transaction
- monitor 至少应能观察到完整 read transaction
- 这表示 VIP 的观测链路也已基本接通

---

## 6. smoke test 的推荐执行顺序
建议 smoke test 按以下顺序执行：

### Step 1: 全局 reset
- 拉起 reset
- 等待若干时钟
- 释放 reset
- 检查系统进入空闲态

### Step 2: `master0 -> slave0`
- 发起 single-beat write
- 发起 single-beat read
- 比较读回值

### Step 3: `master0 -> slave1`
- 发起 single-beat write
- 发起 single-beat read
- 比较读回值

### Step 4: `master1 -> slave0`
- 发起 single-beat write
- 发起 single-beat read
- 比较读回值

### Step 5: `master1 -> slave1`
- 发起 single-beat write
- 发起 single-beat read
- 比较读回值

---

## 7. smoke test 通过标准
当且仅当满足以下条件时，smoke test 判定通过：

1. reset 后系统成功恢复
2. 四条基本路由路径全部完成最小 write-read 闭环
3. 所有写事务返回 `BRESP = OKAY`
4. 所有读事务返回 `RRESP = OKAY`
5. 所有读回数据与写入数据一致
6. 无 handshake 死锁
7. 无事务超时
8. monitor 能观察到完整事务

---

## 8. 本阶段明确不要求完成的内容
以下内容**不属于 smoke test 目标**，请不要在本阶段扩展：

- multi-beat burst 验证
- unaligned transfer
- WRAP burst
- backpressure 场景
- 多 master 同时竞争同一 slave
- 仲裁公平性验证
- QoS/USER/REGION 专项验证
- error response 注入
- reset 中断未完成事务
- 协议 corner case 全覆盖
- full functional coverage
- stress/random regression

这些内容应放在后续 feature test / corner test / stress test 中单独验证。

---

## 9. 对 Claude 的明确实现要求
请基于上述 smoke test 目标，帮助实现：

1. 最简单 smoke test 的 testcase / sequence 结构
2. 事务发送顺序与路径覆盖方案
3. 读写数据选择策略
4. 必要的 timeout 检查
5. 基本结果比对逻辑
6. 失败时的错误信息设计

实现时请始终遵守一个原则：

**先保证最基本路径跑通，再考虑扩展复杂场景。**
