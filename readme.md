# Rust 高频微观市场仿真系统 (RSSS) - 最终架构设计规范 v1.0

## 1. 项目愿景与面试定位 (Vision & Pitch)

### 1.1 项目定义

本项目是一个基于 **Rust** 的高性能、事件驱动型  **计算金融仿真系统 (Computational Finance Simulation)** 。
核心目标是在单机环境下，通过 **Hybrid Runtime (混合运行时)** 架构，模拟 1000+ 个 AI Agent 在微观市场结构下的连续博弈与涌现现象。

### 1.2 核心技术亮点 (Interview Highlights)

* **零拷贝架构 (Zero-Copy Architecture)** : 利用 `Arc<MarketState>` 与 Rust 的所有权机制，在 1000 个并发 Agent 间实现毫秒级快照分发，极大降低缓存未命中 (Cache Miss)。
* **确定性并发 (Deterministic Concurrency)** : 摒弃简单的多线程随机，采用 **Seedable RNG** (基于种子的随机数生成器)，确保在并行计算 (Rayon) 下，只要种子一致，回测结果 **比特级可复现 (Bit-wise Reproducible)** 。
* **定点数引擎 (Fixed-Point Engine)** : 摒弃 `f64`，底层核心全部采用 `i64` 微元 (Micros) 存储价格与金额，彻底消除 IEEE 754 浮点误差。
* **惰性删除 (Lazy Deletion)** : 在撮合引擎中，针对二叉堆 (Binary Heap) 删除中间元素 O(N) 的性能缺陷，采用 `HashMap` 标记 + 堆顶惰性清理策略，将撤单复杂度优化至  **O(log N)** 。

## 2. 系统架构 (System Architecture)

### 2.1 拓扑结构

采用 **Host-Guest (宿主-寄生)** 模式：

* **Host (Rust)** : 负责重计算（指标、撮合）、并发调度、内存管理。
* **Guest (Rhai)** : 负责轻逻辑（策略分支、状态流转）。
* **Glue (Math Lib)** : Rust 暴露 SIMD 加速的向量化算子给 Rhai，解决脚本计算慢的问题。

### 2.2 核心生命周期 (The Loop)

系统在一个长回合 (Session) 中连续运行，无“日/夜”分割。每一帧 (Tick) 严格遵循以下原子阶段：

1. **Pre-Calculation (重计算阶段)**
   * Rust 更新全局历史窗口。
   * 计算高耗时指标 (VWAP, Slope, Imbalance)。
   * **关键** : 将所有数据封装为只读的 `Arc<MarketSharedState>`。
2. **Decision (决策阶段 - 并行)**
   * 利用 `rayon` 线程池，1000 个 Agent 并行执行 `decide()`。
   * **Context** : 传入 `Arc<MarketSharedState>` (公) 和 `&mut AgentAccount` (私)。
   * **Output** : 生成 `AgentDecision` (包含订单请求)。
3. **Shuffle (熵增阶段)**
   * **关键** : 使用 Fisher-Yates 算法对所有决策进行随机打乱。
   * **目的** : 模拟物理网络延迟的不确定性，制造滑点 (Slippage) 和抢单失败的风险。
4. **Execution (执行阶段 - 串行)**
   * 撮合引擎处理订单 (Match/Cancel)。
   * **惰性删除** : 检查 `cancelled_orders` 集合。
   * **结算** : 扣除手续费，原子更新账户资金。

## 3. 核心领域模型 (Domain Models)

### 3.1 定点数与精度 (Fixed-Point Math)

为了金融计算的严谨性，所有价格与金额在 Rust 内部均使用 `i64`。

```
// 精度缩放因子: 10^6 (支持到小数点后 6 位)
pub const SCALING_FACTOR: i64 = 1_000_000;

// 示例转换
// 100.50 元 -> 100,500,000 micros
pub fn to_micros(price: f64) -> i64 { (price * SCALING_FACTOR as f64) as i64 }
pub fn from_micros(micros: i64) -> f64 { micros as f64 / SCALING_FACTOR as f64 }
```

### 3.2 撮合引擎 (Matching Engine)

采用 **双堆 (Dual-Heap) + 惰性删除** 结构。

```
pub struct OrderBook {
    // 卖单堆 (Min-Heap): 价格低的优先
    pub asks: BinaryHeap<AskOrder>, 
    // 买单堆 (Max-Heap): 价格高的优先
    pub bids: BinaryHeap<BidOrder>,
    // 撤单集合: 记录被撤单的 OrderID (惰性删除的关键)
    pub cancelled_orders: HashSet<u64>, 
}

impl OrderBook {
    // 核心逻辑: 只有当堆顶元素出现在 cancelled_orders 中时，才将其 pop 掉
    pub fn clean_top(&mut self) {
        while let Some(order) = self.bids.peek() {
            if self.cancelled_orders.contains(&order.id) {
                self.bids.pop();
            } else {
                break;
            }
        }
        // Asks 同理...
    }
}
```

### 3.3 经济模型配置 (Configuration)

* **Transaction Fee** : 全局手续费率 (e.g., 万分之三)。
* **Warm-up Period** : 预热期 (前 N Tick)，允许计算指标，禁止交易。
* **Base Position** : 初始化时随机分配给 Agent 的底仓。

## 4. 接口规范 (API Reference for Rhai)

为了方便脚本编写，Rust 暴露给 Rhai 的数据通常会自动转换为 `f64`，但底层必须是 `i64`。

### 4.1 市场共享状态 (`market`)

```
struct MarketSharedState {
    // [时空]
    pub tick: u64,
    pub total_ticks: u64,
    pub trading_enabled: bool, // 是否在交易期 (非预热期)
    pub fee_rate: f64,         // 费率 (小数，如 0.0003)

    // [行情 - 由 i64 转换而来]
    pub price: f64,
    pub volume: u64,
  
    // [微观结构]
    pub buy_volume: u64,      // 主动买量
    pub sell_volume: u64,     // 主动卖量
  
    // [盘口深度]
    pub bids: Vec<(f64, i64)>, // Top 5 [(Price, Vol)]
    pub asks: Vec<(f64, i64)>, // Top 5
    pub order_imbalance: f64,  // 盘口压力 [-1, 1]

    // [预计算指标]
    pub ma_5: f64,
    pub ma_20: f64,
    pub ma_60: f64,
    pub high_20: f64,
    pub low_20: f64,
    pub vwap: f64,
    pub std_dev: f64,
    pub atr_14: f64,

    // [原始数据 - RingBuffer]
    pub history_prices: Vec<f64>,
    pub history_volumes: Vec<u64>,
}
```

### 4.2 账户私有状态 (`account`)

```
struct AgentAccount {
    pub cash: f64,           // 现金
    pub stock: i64,          // 持仓 (可能包含初始底仓)
    pub total_equity: f64,   // 总权益 (面试点: Mark-to-Market 估值)
  
    pub unrealized_pnl: f64, // 浮动盈亏
    pub realized_pnl: f64,   // 已实现盈亏
    pub avg_cost: f64,       // 持仓成本

    pub last_order_status: String, // "Filled", "Partial", "Rejected", "None"
    pub custom_memory: Map,        // 持久化存储
}
```

### 4.3 数学工具库 (`math`)

提供 Rust 原生实现的向量化算子，替代脚本循环。

* `math.sum`, `math.mean`, `math.std_dev`, `math.slope` (线性回归)
* `math.v_add`, `math.v_sub`, `math.dot` (点积)

## 5. Agent 行为规范 (Agent Spec)

这是指导 DeepSeek 生成策略的核心逻辑模板。

### 5.1 惰性初始化 (Lazy Setup Pattern)

Agent 必须在脚本开头检查自身是否初始化，以设定个性化参数。

```
// [Step 0] 惰性初始化
if !account.custom_memory.contains("initialized") {
    account.custom_memory.put("initialized", true);
    // 个性化配置
    account.custom_memory.put("risk_tolerance", 0.02); // 2% 止损
    account.custom_memory.put("target_pos", 0);
    return #{ action: Action.Hold, ... };
}
```

### 5.2 预热期合规 (Compliance)

```
// [Step 1] 预热期检查
if !market.trading_enabled {
    // 此时可以计算长期指标，但绝不能下单
    return #{ action: Action.Hold, ... };
}
```

### 5.3 决策逻辑示例

```
// [Step 2] 策略计算
// 使用 math 库进行计算
let slope = math.slope(market.history_prices);

// 考虑手续费的套利检查
let potential_profit = (market.vwap - market.price) / market.price;
if potential_profit > market.fee_rate * 1.5 {
    // ...
}

// [Step 3] 返回决策
return #{
    action: Action.Buy,
    order_type: OrderType.Limit,
    price: market.price,
    amount: 100
};
```

## 6. 开发路线图 (Implementation Roadmap)

### Phase 1: 核心骨架 (The Skeleton)

1. **Project Setup** : 配置 `Cargo.toml` (rhai, rayon, serde, statrs)。
2. **Domain** : 实现 `FixedPoint` (i64) 转换逻辑。
3. **Engine** : 实现 `OrderBook`，包含 **双堆** 和 **惰性删除** 逻辑。

### Phase 2: 运行时桥接 (The Bridge)

1. **Binding** : 将 `MarketState` 和 `AgentAccount` 注册到 Rhai。
2. **Math Lib** : 实现 `src/math.rs`，暴露统计函数。

### Phase 3: 主循环与并发 (The Loop)

1. **Simulation** : 实现 `run_session` 主循环。
2. **Concurrency** : 使用 `rayon::par_iter` 并行执行 Agent 脚本。
3. **Determinism** : 实现基于 Seed 的随机洗牌。

### Phase 4: 策略生成与回测 (The Experiment)

1. **Prompt Engineering** : 使用文档中的规范生成 10 类 Agent。
2. **Visualization** : (可选) TUI 终端可视化。
