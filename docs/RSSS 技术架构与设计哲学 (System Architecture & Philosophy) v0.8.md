
# RSSS 技术架构与设计哲学 (System Architecture & Philosophy) v0.8

## 1. 核心设计理念

本项目旨在构建一个**高性能、高保真、强博弈**的计算金融仿真环境。
核心架构决策基于以下原则：

1. **宿主-寄生架构 (Host-Guest)** :

* **Rust (Host)** : 负责重计算（指标、撮合）、并发调度、内存管理。利用 Rust 的 Zero-Overhead Abstraction 确保纳秒级延迟。
* **Rhai (Guest)** : 负责轻逻辑（策略分支、状态流转）。利用脚本语言的灵活性实现策略的热更新与多样性。

1. **连续时间流 (Continuous Flow)** :

* 摒弃传统仿真中“日/开盘/收盘”的离散分割。
* 采用单一长回合 (Single Session) 机制（Tick 0 -> Tick Max）。

1. **随机序列执行 (Randomized Sequential Execution)** :

* 引入 Fisher-Yates 洗牌机制，模拟网络延迟与抢单滑点。

## 2. 经济模型 (Economic Model)

为了增强博弈的真实性，系统引入以下约束：

* **交易成本 (Friction)** : 每一笔成交均收取固定比例的手续费（如万分之三）。这将迫使 Agent 寻找高盈亏比的机会，而非进行无意义的噪音交易。
* **初始禀赋 (Endowment)** :
* **资金 (Cash)** : 每个 Agent 初始拥有一定量的现金。
* **底仓 (Base Position)** : 为了解决系统启动时的流动性问题（有钱无票），部分或所有 Agent 在 Tick 0 时将随机持有一定数量的股票。

## 3. 生命周期与阶段 (Lifecycle Phases)

系统运行分为两个阶段，由 `market.trading_enabled` 标志控制：

1. **预热期 (Warm-up Phase / Pre-Market)** :

* **时长** : Tick 0 到 Tick N (例如前 200 Tick)。
* **行为** :
  * Rust 主程序正常更新行情、计算指标 (MA, RSI 等)。
  *  **禁止交易** : 撮合引擎拒绝所有新订单。
  *  **目的** : 让技术指标“走稳”，填充历史数据窗口，并允许 Agent 初始化内部状态。

1. **交易期 (Trading Phase)** :

* **时长** : Tick N 到 Tick Max。
* **行为** : 开放撮合，全功能运行。

## 4. 核心生命周期 (The Loop)

每一帧 (Tick) 严格遵循以下四个原子阶段：

1. **Pre-Calculation (重计算阶段)**
   * Rust 更新全局历史窗口。
   * Rust 计算高耗时指标。
   * 生成原子快照 `Arc<MarketSharedState>`。
2. **Decision (决策阶段 - 并行)**
   * 1000 个 Agent 并行执行。
   * **惰性初始化** : Agent 首次运行时执行 `setup` 逻辑。
   * 输出：`AgentDecision`。
3. **Shuffle (熵增阶段)**
   * 随机打乱订单顺序。
4. **Execution (执行阶段 - 串行)**
   * 撮合引擎处理订单。
   * **扣除手续费** : `Cost = Price * Amount * (1 + FeeRate)`。
   * 实时更新盘口与账户。
