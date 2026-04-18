【角色设定】
你现在是一位拥有 10 年前端数字 IC 验证经验的资深架构师。我是一名正在寻找验证工作的初级验证工程师，需要你的指导来完善我的进阶项目。

【项目背景与输入】
我目前正在基于 UVM 方法学验证一个 2x2 AXI4 Non-blocking Crossbar (非阻塞互连矩阵)。
（注：设计源码来源于 Github 开源项目 verilog-axi by Alex Forencich）

DUT 核心特性（请基于提供的 RTL 代码分析）：

支持 2 个 AXI Master 端口和 2 个 AXI Slave 端口的交叉互连。

完全非阻塞（Non-blocking），读通道（AR/R）与写通道（AW/W/B）物理分离，支持多主多从的并发传输。

支持基于 ID 的乱序返回保护逻辑（Transaction ordering protection），并在内部进行了 ID 位宽扩展（Master 端 8-bit -> Slave 端 9-bit）。

每个端口具备独立的地址解码（Address Decode）、准入控制以及解码错误处理（DECERR）。

包含独立的仲裁器（arbiter.v）和优先级编码器，处理并发冲突。

包含可配置的打拍寄存器（Skid buffers / Pipeline registers）。

对 QoS、Region 和 User 边带信号仅做物理透传（Passthrough）。

当前测试平台（Testbench）现状：

纯 UVM 架构，包含 2 个 Master Agent 和 2 个 Slave Agent。

顶层连线已完成，接口位宽已参数化对齐。

目前已经成功跑通了最基础的 Smoke Test（单主单从的基础连通性测试），证明底层 VIP 的 Driver/Monitor 基本可用。

【任务需求】
请你基于上述背景和本地项目文件夹中的源码，为我编写一份企业级的、详尽的 AXI Crossbar 验证计划 (Verification Plan)。

【输出格式要求】
请按照以下 4 个章节进行结构化输出：

一、 验证特性提取 (Feature Extraction)
列出 DUT 必须被验证的协议特性和内部微架构特性。

二、 测试用例矩阵 (Testcase Matrix)
请以表格的形式列出具体的 Testcase 和 Virtual Sequence，必须包含以下维度，并简述每个用例的设计思路和期望结果：

基础路由测试 (Basic Routing)

并发与非阻塞测试 (Concurrency & Non-blocking)

仲裁与冲突测试 (Arbitration & Collision)

乱序与多 Outstanding 测试 (Out-of-Order)

边界与异常测试 (Corner cases & Error Handling，如非法地址、非对齐、极窄突发等)

三、 覆盖率收集计划 (Coverage Plan)

功能覆盖率 (Functional Coverage/Covergroups)：列出需要收集的交叉覆盖点（Cross Coverage），例如端口交叉请求、读写并发等。

断言覆盖率 (SVA)：列举 3-5 个必须绑定在 DUT 内部关键节点（如 Arbiter、FIFO）的系统级断言（SystemVerilog Assertions）。

四、 记分板设计建议 (Scoreboard Architecture)
简述针对这个支持乱序和并发的 2x2 矩阵，我的 Scoreboard 参考模型（Reference Model）应该采用什么样的数据结构来进行路由预测和比对。