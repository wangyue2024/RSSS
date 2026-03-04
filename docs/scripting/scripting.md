# RSSS Scripting 接口层技术文档 v2.1

**模块名称** : `rsss::scripting`
**依赖** : `rsss::domain`, `rhai`, `rand`, `rand_xoshiro`
**核心定位** : Rust-Rhai 零序列化桥梁——将宿主数据以只读结构体直传脚本，收集 Agent 决策。

---

## 1. 设计原则

| 原则                | 实现                                                                      |
| :------------------ | :------------------------------------------------------------------------ |
| **零序列化**        | `Arc` 包装所有共享数据直注入 Scope，无 JSON/Dynamic 转换                  |
| **零浮点**          | Rhai 开启 `no_float`，所有值均为 `i64`，与 domain 模块一致                |
| **零重复计算**      | 指标在 Rust 侧算好（SIMD 友好），Rhai 只读标量结果                        |
| **Scope 即 Memory** | Agent 变量留在 Scope 中跨 Tick 存活，无需手动序列化                       |
| **函数式提交**      | Agent 通过 `orders.submit_limit_buy(price, amount)` 提交，返回 `order_id` |
| **确定性随机**      | 每 Agent 独立 seed RNG，并行不影响可复现性                                |

## 2. 文件结构

```
src/scripting.rs              → 模块根，扁平导出
src/scripting/
├── engine_builder.rs         → 构建全局唯一 Engine
├── api.rs                    → MarketState / AccountView / AgentOrderBook / ActionMailbox 类型注册
├── rng.rs                    → AgentRng 确定性随机数
├── math.rs                   → 数学函数 (mean, slope, std_dev 等)
├── sandbox.rs                → 安全约束 (ops 限制)
└── tests.rs                  → 集成测试
```

## 3. Rhai 配置

### 3.1 Cargo Feature Flags

```toml
[dependencies]
rhai = { version = "1", features = ["sync", "no_float", "only_i64"] }
rand = "0.8"
rand_xoshiro = "0.6"
```

- `sync` — Engine 为 `Send+Sync`，支持 Rayon 并行共享引用
- `no_float` — 禁用 `f64` → 与零浮点原则一致 + 性能提升
- `only_i64` — 仅保留 i64 整数

> 开发阶段保留安全检查。仿真发布时可加 `unchecked` 极限提速。

### 3.2 实例策略

```
1 个 Engine   (全局，注册所有类型+函数，Send+Sync，共享引用)
    ↓
N 个 Arc<AST> (每种策略编译一次，多 Agent 可共享)
    ↓
1000 个 Scope (每 Agent 一份，含私有变量、RNG、orders)
```

## 4. 数据结构

### 4.1 MarketState — 只读市场快照 (Arc)

```rust
/// 每 Tick 由主循环构建一次，Arc 包装后注入所有 Scope
#[derive(Clone)]
pub struct MarketState {
    // — 时空感知 —
    pub tick: i64,
    pub total_ticks: i64,
    pub trading_enabled: bool,
    pub fee_rate_bps: i64,          // 基点，如 3 = 万三

    // — 基础行情 —
    pub price: i64,                 // 最新成交价 (微元)
    pub volume: i64,                // 本 Tick 成交量

    // — 微观结构 —
    pub buy_volume: i64,            // Taker 买量
    pub sell_volume: i64,           // Taker 卖量

    // — 盘口 (前 5 档, 扁平化避免 Array clone) —
    pub bid_prices: [i64; 5],
    pub bid_volumes: [i64; 5],
    pub ask_prices: [i64; 5],
    pub ask_volumes: [i64; 5],
    pub order_imbalance: i64,       // × 10000 → [-10000, 10000]

    // — 预算技术指标 (全 i64 微元) —
    pub ma_5: i64,
    pub ma_20: i64,
    pub ma_60: i64,
    pub high_20: i64,
    pub low_20: i64,
    pub vwap: i64,
    pub std_dev: i64,
    pub atr_14: i64,
    pub rsi_14: i64,                // × 100 → 7050 = RSI 70.5

    // — 历史序列 (仅通过函数访问，不暴露 getter) —
    pub history_prices: Vec<i64>,   // 最近 256 Tick
    pub history_volumes: Vec<i64>,  // 最近 256 Tick
}
```

**盘口访问**：注册 20 个独立 getter (`market.bid_price_0` ... `market.ask_vol_4`)。

**历史数据**：通过注册函数按索引访问，不触发 Vec clone：

```rhai
let old_price = history_price(market, 10);  // 10 Tick 前的价格
let len = history_len(market);
```

> **重要**：Scope 中注入 `Arc<MarketState>`，因此必须注册 `Arc<MarketState>` 为 Rhai 类型：
> ```rust
> engine.register_type_with_name::<Arc<MarketState>>("MarketState");
> engine.register_get("price", |s: &mut Arc<MarketState>| s.price);
> engine.register_get("tick",  |s: &mut Arc<MarketState>| s.tick);
> // ... 其他 getter
> ```
> Rhai 调 getter 时只 clone Arc (引用计数 +1, O(1))，不 clone 内部数据。
> `Arc<AgentOrderBook>` 同理。


### 4.2 AccountView — 轻量账户快照 (Copy)

```rust
/// 32 bytes, Copy = memcpy, 无堆分配
#[derive(Clone, Copy)]
pub struct AccountView {
    pub cash: i64,
    pub stock: i64,
    pub total_equity: i64,
    pub avg_cost: i64,
    pub unrealized_pnl: i64,
    pub realized_pnl: i64,
}
```

### 4.3 AgentOrderBook — 订单跟踪 (Arc)

```rust
/// 每 Agent 一份, Arc 包装零拷贝注入 Scope
#[derive(Clone)]
pub struct AgentOrderBook {
    /// 当前活跃挂单 (未成交、未撤)
    pub pending: Vec<PendingOrder>,
    /// 上一 Tick 的成交回报 (每 Tick 重建)
    pub last_fills: Vec<FillReport>,
    /// 全历史已完结订单 (成交/撤/拒绝)
    pub history: Vec<HistoricalOrder>,
}

#[derive(Clone, Copy)]
pub struct PendingOrder {
    pub order_id: i64,
    pub side: i64,              // 1 = buy, -1 = sell
    pub price: i64,             // 微元
    pub remaining: i64,         // 剩余未成交量
    pub placed_tick: i64,       // 挂单时的 Tick
}

#[derive(Clone, Copy)]
pub struct FillReport {
    pub order_id: i64,
    pub fill_price: i64,        // 成交价 (微元)
    pub fill_amount: i64,
    pub side: i64,
}

#[derive(Clone, Copy)]
pub struct HistoricalOrder {
    pub order_id: i64,
    pub side: i64,
    pub price: i64,
    pub amount: i64,            // 原始下单量
    pub filled: i64,            // 实际成交量
    pub status: i64,            // 0=fully_filled, 1=cancelled, 2=rejected
    pub placed_tick: i64,
    pub closed_tick: i64,
}
```

**Rhai 暴露方式**——按索引函数查询，零拷贝：

```rust
// 当前挂单
engine.register_fn("pending_count",       |ob: &mut AgentOrderBook| -> i64);
engine.register_fn("pending_id",          |ob: &mut AgentOrderBook, i: i64| -> i64);
engine.register_fn("pending_side",        |ob: &mut AgentOrderBook, i: i64| -> i64);
engine.register_fn("pending_price",       |ob: &mut AgentOrderBook, i: i64| -> i64);
engine.register_fn("pending_remaining",   |ob: &mut AgentOrderBook, i: i64| -> i64);
engine.register_fn("pending_placed_tick", |ob: &mut AgentOrderBook, i: i64| -> i64);

// 上 Tick 成交
engine.register_fn("fill_count",  |ob: &mut AgentOrderBook| -> i64);
engine.register_fn("fill_id",     |ob: &mut AgentOrderBook, i: i64| -> i64);
engine.register_fn("fill_price",  |ob: &mut AgentOrderBook, i: i64| -> i64);
engine.register_fn("fill_amount", |ob: &mut AgentOrderBook, i: i64| -> i64);
engine.register_fn("fill_side",   |ob: &mut AgentOrderBook, i: i64| -> i64);

// 历史订单
engine.register_fn("order_history_count",  |ob: &mut AgentOrderBook| -> i64);
engine.register_fn("order_history_id",     |ob: &mut AgentOrderBook, i: i64| -> i64);
engine.register_fn("order_history_status", |ob: &mut AgentOrderBook, i: i64| -> i64);
engine.register_fn("order_history_filled", |ob: &mut AgentOrderBook, i: i64| -> i64);
```

**Rhai 侧使用**：

```rhai
fn on_tick() {
    // 检查成交回报
    for i in 0..fill_count(my_orders) {
        trade_count += 1;
        total_filled += fill_amount(my_orders, i);
    }

    // 检查挂单，超时撤单
    for i in 0..pending_count(my_orders) {
        if market.tick - pending_placed_tick(my_orders, i) > 20 {
            orders.submit_cancel(pending_id(my_orders, i));
        }
    }
}
```

### 4.3 ActionMailbox — 决策收集器

```rust
#[derive(Clone)]
pub struct ActionMailbox {
    pub actions: Vec<AgentAction>,
    agent_id: u32,
    counter: u32,
}

#[derive(Clone, Debug)]
pub enum AgentAction {
    LimitBuy  { order_id: i64, price: i64, amount: i64 },
    LimitSell { order_id: i64, price: i64, amount: i64 },
    MarketBuy { order_id: i64, amount: i64 },
    MarketSell{ order_id: i64, amount: i64 },
    Cancel    { order_id: i64 },
}
```

**Order ID 生成**：位编码方案，全局唯一无碰撞：

```
order_id (i64) = (agent_id << 32) | counter
```

- Agent 7 的第 3 个订单 → `(7 << 32) | 3` = `30064771075`
- 仅凭 ID 即可反查 Agent: `agent_id = order_id >> 32`
- 无原子操作，无并行竞争

**所有 submit 函数返回 `order_id`**：

```rust
impl ActionMailbox {
    pub fn new(agent_id: u32) -> Self {
        Self { actions: Vec::new(), agent_id, counter: 0 }
    }

    fn next_id(&mut self) -> i64 {
        self.counter += 1;
        ((self.agent_id as i64) << 32) | (self.counter as i64)
    }

    pub fn submit_limit_buy(&mut self, price: i64, amount: i64) -> i64 {
        let id = self.next_id();
        self.actions.push(AgentAction::LimitBuy { order_id: id, price, amount });
        id
    }
    pub fn submit_limit_sell(&mut self, price: i64, amount: i64) -> i64 {
        let id = self.next_id();
        self.actions.push(AgentAction::LimitSell { order_id: id, price, amount });
        id
    }
    pub fn submit_market_buy(&mut self, amount: i64) -> i64 {
        let id = self.next_id();
        self.actions.push(AgentAction::MarketBuy { order_id: id, amount });
        id
    }
    pub fn submit_market_sell(&mut self, amount: i64) -> i64 {
        let id = self.next_id();
        self.actions.push(AgentAction::MarketSell { order_id: id, amount });
        id
    }
    pub fn submit_cancel(&mut self, order_id: i64) {
        self.actions.push(AgentAction::Cancel { order_id });
    }
}
```

**Rhai 侧使用**：

```rhai
// on_tick 内
let my_id = orders.submit_limit_buy(market.price + 100_000, 50);
active_order_id = my_id;  // 保存在 Scope 中，下一 Tick 可撤单
```

### 4.5 AgentRng — 确定性随机数 (Scope 常驻)

```rust
use rand::SeedableRng;
use rand::Rng;
use rand_xoshiro::Xoshiro256PlusPlus;

#[derive(Clone)]
pub struct AgentRng {
    inner: Xoshiro256PlusPlus,
}

impl AgentRng {
    pub fn new(global_seed: u64, agent_id: u32) -> Self {
        let agent_seed = global_seed
            .wrapping_mul(6364136223846793005)
            .wrapping_add(agent_id as u64);
        Self {
            inner: Xoshiro256PlusPlus::seed_from_u64(agent_seed),
        }
    }

    pub fn rand_int(&mut self, lo: i64, hi: i64) -> i64 {
        self.inner.gen_range(lo..=hi)
    }

    pub fn rand_bool(&mut self, pct: i64) -> bool {
        self.inner.gen_range(0..100) < pct
    }
}
```

**确定性保证**：

```
Agent 0 (seed = f(global, 0)): rand_int 序列 = [7, 23, 91, ...]
Agent 1 (seed = f(global, 1)): rand_int 序列 = [55, 3, 67, ...]
```

每个 Agent 的 RNG 完全独立。即使 Rayon 并行执行顺序不同，各自的随机序列不变 → **比特级可复现** ✅

**注入方式**——仅 init 时注入一次，跨 Tick 保留：

```rust
// Agent 初始化时（非每 Tick）
scope.push("rng", AgentRng::new(global_seed, agent_id));
```

**Rhai 侧使用**：

```rhai
fn on_tick() {
    if !rand_bool(rng, 30) { return; }     // 30% 概率执行
    let noise = rand_int(rng, -500_000, 500_000);
    orders.submit_limit_buy(market.price + noise, 10);
}
```

## 5. Agent 生命周期

### 5.1 脚本结构约定

> ⚠️ **关键**：Rhai 的 `call_fn` 会**自动回卷 Scope**，函数内 `let` 声明的变量在函数返回后消失。
> 因此 Agent 的私有状态必须声明为**顶层代码**，不能放在函数里。

```rhai
// ===== 顶层代码 = 初始化 (仅执行一次) =====
let my_target = 100;
let trade_count = 0;
let active_order_id = -1;

// ===== 函数定义 =====
/// 每 Tick 被调用
/// 可直接读写顶层声明的变量
fn on_tick() {
    trade_count += 1;
    if market.price > my_target { /* ... */ }
}
```

### 5.2 Rust 侧 Agent 结构

```rust
struct Agent {
    id: u32,
    ast: Arc<AST>,
    scope: Scope<'static>,
    rng: AgentRng,
    order_book: AgentOrderBook,
    initialized: bool,
}

impl Agent {
    fn tick(&mut self, engine: &Engine, market: Arc<MarketState>, account: AccountView) {
        // 1. 注入只读数据
        self.scope.set_value("market", market);                         // Arc clone O(1)
        self.scope.set_value("account", account);                       // Copy 48B
        self.scope.set_value("my_orders", Arc::new(self.order_book.clone())); // Arc 包装
        self.scope.set_value("orders", ActionMailbox::new(self.id));    // 空邮箱

        // 2. 首次：执行顶层代码 (初始化 Agent 私有变量) + 注入 RNG
        if !self.initialized {
            self.scope.push("rng", self.rng.clone());
            let _ = engine.run_ast_with_scope(&mut self.scope, &self.ast);
            self.initialized = true;
        }

        // 3. 每 Tick：调用 on_tick 函数
        if let Err(e) = engine.call_fn::<()>(&mut self.scope, &self.ast, "on_tick", ()) {
            eprintln!("Agent {} script error: {}", self.id, e);
        }

        // 4. 回收 RNG 状态 (保持确定性序列连续)
        if let Some(updated_rng) = self.scope.get_value::<AgentRng>("rng") {
            self.rng = updated_rng;
        }
    }

    fn take_actions(&mut self) -> Vec<AgentAction> {
        self.scope.get_value::<ActionMailbox>("orders")
            .map(|m| m.actions)
            .unwrap_or_default()
    }
}
```

### 5.3 Scope 变量表

```
每 Tick 覆盖:                  初始化时注入，跨 Tick 保留:
  market     → Arc<MarketState>     rng       → AgentRng
  account    → AccountView (Copy)   顶层 let  → i64/Array/Map/...
  my_orders  → Arc<AgentOrderBook>
  orders     → ActionMailbox (空)
```

## 6. 数学函数库

顶层注册，Rust 高性能实现：

```rust
// 数组函数
engine.register_fn("arr_sum",     math::arr_sum);      // Array → i64
engine.register_fn("arr_mean",    math::arr_mean);     // Array → i64
engine.register_fn("arr_min",     math::arr_min);      // Array → i64
engine.register_fn("arr_max",     math::arr_max);      // Array → i64
engine.register_fn("arr_std_dev", math::arr_std_dev);  // Array → i64
engine.register_fn("arr_slope",   math::arr_slope);    // Array → i64

// 标量工具
engine.register_fn("abs_val",     math::abs_val);      // i64 → i64
engine.register_fn("clamp_val",   math::clamp_val);    // (i64, i64, i64) → i64
engine.register_fn("micros",      math::micros);       // (yuan, frac) → i64

// 历史查询
engine.register_fn("history_price",  ...);  // (MarketState, idx) → i64
engine.register_fn("history_volume", ...);  // (MarketState, idx) → i64
engine.register_fn("history_len",    ...);  // (MarketState) → i64
```

## 7. 安全防线

### 7.1 操作次数限制

```rust
engine.on_progress(|ops| {
    if ops > 500_000 { Some("Exceeded 500K ops".into()) }
    else { None }
});
```

### 7.2 只读沙箱

- `Arc<MarketState>` / `AccountView` / `Arc<AgentOrderBook>` — 仅 getter，无 setter
- `orders` (ActionMailbox) — 唯一可变交互点
- `rng` (AgentRng) — 仅 `rand_int` / `rand_bool` 推进状态

### 7.3 编译校验 (Pre-Flight)

```rust
fn compile_agent_script(engine: &Engine, source: &str) -> Result<AST, String> {
    let ast = engine.compile(source)?;
    // 必须有 on_tick 函数
    if !ast.iter_functions().any(|f| f.name == "on_tick") {
        return Err("Missing fn on_tick()".into());
    }
    Ok(ast)
}
```

### 7.4 同 Tick 下单+撤单语义

同一 `on_tick` 内 submit + cancel 同一 order_id：由于所有 action 经 Shuffle 送入引擎，
cancel 可能先于 submit 到达（→ OrderNotFound），也可能后于 submit（→ 正常撤单）。
**这符合真实市场语义**——订单到达交易所的顺序不确定。

## 8. 每 Tick 完整数据流

```
┌──────────────────── Tick T ────────────────────────────────────┐
│                                                                │
│  [1. Pre-Calculation — 主线程]                                 │
│      清空所有 AgentOrderBook.last_fills                        │
│      更新历史窗口, 计算指标                                     │
│      market = Arc::new(MarketState { ... })                    │
│      for agent: AccountView = 计算(cash, stock, pnl)           │
│                                                                │
│  [2. Decision — Rayon 并行]                                    │
│      agents.par_iter_mut(|agent| {                             │
│          scope ← market (Arc clone O(1))                       │
│          scope ← account (Copy 48B)                            │
│          scope ← my_orders (Arc<AgentOrderBook> O(1))          │
│          scope ← orders (空 ActionMailbox)                     │
│          if !initialized: run_ast_with_scope (顶层代码)        │
│          call_fn("on_tick")                                    │
│      })                                                        │
│                                                                │
│  [3. Collect — 主线程]                                         │
│      all_actions = agents.flat_map(take_actions)               │
│                                                                │
│  [4. Shuffle — 主线程]                                         │
│      Fisher-Yates (global seed RNG)                            │
│                                                                │
│  [5. Execution — 主线程, 串行]                                 │
│      for (agent_id, action) in all_actions:                    │
│          order = convert(action)                               │
│          events = engine.process_order(order)                  │
│          for event in events:                                  │
│            Trade → agents[maker/taker].order_book:             │
│                      pending 扣减 remaining                    │
│                      last_fills.push(FillReport)               │
│                      remaining==0 → 移入 history               │
│            Placed → agents[taker].order_book.pending.push()    │
│            Cancelled → pending 移入 history (status=1)         │
│            Rejected → 记入 history (status=2)                  │
│          结算: cash ± cost ± fee, stock ± amount               │
│                                                                │
│  [6. Record — IO 线程]                                         │
│      async channel → BufWriter → disk                          │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

## 9. 示例脚本

```rhai
// ===== 做市策略 + 挂单管理 =====

fn init() {
    let spread_target = 200_000;    // 0.20 元价差
    let order_size = 20;
    let buy_order_id = -1;
    let sell_order_id = -1;
}

fn on_tick() {
    if !market.trading_enabled { return; }

    // 检查成交: 有成交则重置订单 ID
    for i in 0..fill_count(my_orders) {
        let fid = fill_id(my_orders, i);
        if fid == buy_order_id  { buy_order_id = -1; }
        if fid == sell_order_id { sell_order_id = -1; }
    }

    let mid = (market.bid_price_0 + market.ask_price_0) / 2;
    let noise = rand_int(rng, -50_000, 50_000);

    // 挂买单
    if buy_order_id == -1 {
        let price = mid - spread_target / 2 + noise;
        buy_order_id = orders.submit_limit_buy(price, order_size);
    }

    // 挂卖单
    if sell_order_id == -1 && account.stock >= order_size {
        let price = mid + spread_target / 2 + noise;
        sell_order_id = orders.submit_limit_sell(price, order_size);
    }

    // 挂超时撤单 (挂了 10 Tick 还没成交)
    for i in 0..pending_count(my_orders) {
        if market.tick - pending_placed_tick(my_orders, i) > 10 {
            let pid = pending_id(my_orders, i);
            orders.submit_cancel(pid);
            if pid == buy_order_id  { buy_order_id = -1; }
            if pid == sell_order_id { sell_order_id = -1; }
        }
    }
}
```

## 10. 公开 API 一览

### 只读 Getter — MarketState

| Getter                                   | 类型 | 说明             |
| :--------------------------------------- | :--- | :--------------- |
| `market.tick`                            | i64  | 当前 Tick        |
| `market.total_ticks`                     | i64  | 总 Tick 数       |
| `market.trading_enabled`                 | bool | 是否可交易       |
| `market.fee_rate_bps`                    | i64  | 手续费 (基点)    |
| `market.price`                           | i64  | 最新成交价 (µ)   |
| `market.volume`                          | i64  | 本 Tick 成交量   |
| `market.buy_volume` / `sell_volume`      | i64  | Taker 买/卖量    |
| `market.bid_price_0..4` / `bid_vol_0..4` | i64  | 买盘前 5 档      |
| `market.ask_price_0..4` / `ask_vol_0..4` | i64  | 卖盘前 5 档      |
| `market.order_imbalance`                 | i64  | 盘口压力 ×10000  |
| `market.ma_5/20/60`                      | i64  | 均线 (µ)         |
| `market.high_20` / `low_20`              | i64  | 20 Tick 高低 (µ) |
| `market.vwap`                            | i64  | VWAP (µ)         |
| `market.std_dev` / `atr_14`              | i64  | 波动率 / ATR (µ) |
| `market.rsi_14`                          | i64  | RSI ×100         |

### 只读 Getter — AccountView

| Getter                                    | 类型 | 说明       |
| :---------------------------------------- | :--- | :--------- |
| `account.cash`                            | i64  | 现金 (µ)   |
| `account.stock`                           | i64  | 持仓股数   |
| `account.total_equity`                    | i64  | 总资产 (µ) |
| `account.avg_cost`                        | i64  | 成本价 (µ) |
| `account.unrealized_pnl` / `realized_pnl` | i64  | 盈亏 (µ)   |

### 只读函数 — AgentOrderBook (`my_orders`)

| 函数                                 | 返回 | 说明                     |
| :----------------------------------- | :--- | :----------------------- |
| `pending_count(my_orders)`           | i64  | 活跃挂单数               |
| `pending_id(my_orders, i)`           | i64  | 第 i 个挂单 ID           |
| `pending_side(my_orders, i)`         | i64  | 方向 (1=买,-1=卖)        |
| `pending_price(my_orders, i)`        | i64  | 挂单价 (µ)               |
| `pending_remaining(my_orders, i)`    | i64  | 剩余量                   |
| `pending_placed_tick(my_orders, i)`  | i64  | 挂单 Tick                |
| `fill_count(my_orders)`              | i64  | 上 Tick 成交数           |
| `fill_id(my_orders, i)`              | i64  | 成交订单 ID              |
| `fill_price(my_orders, i)`           | i64  | 成交价 (µ)               |
| `fill_amount(my_orders, i)`          | i64  | 成交量                   |
| `fill_side(my_orders, i)`            | i64  | 方向                     |
| `order_history_count(my_orders)`     | i64  | 历史订单总数             |
| `order_history_id(my_orders, i)`     | i64  | 历史订单 ID              |
| `order_history_status(my_orders, i)` | i64  | 0=全部成交 1=已撤 2=拒绝 |
| `order_history_filled(my_orders, i)` | i64  | 实际成交量               |

### 下单函数 — ActionMailbox (`orders`)

| 函数                                      | 参数     | 返回           | 说明     |
| :---------------------------------------- | :------- | :------------- | :------- |
| `orders.submit_limit_buy(price, amount)`  | i64, i64 | i64 (order_id) | 限价买入 |
| `orders.submit_limit_sell(price, amount)` | i64, i64 | i64 (order_id) | 限价卖出 |
| `orders.submit_market_buy(amount)`        | i64      | i64 (order_id) | 市价买入 |
| `orders.submit_market_sell(amount)`       | i64      | i64 (order_id) | 市价卖出 |
| `orders.submit_cancel(order_id)`          | i64      | void           | 撤单     |

### 随机数 — AgentRng (`rng`)

| 函数                    | 参数     | 返回 | 说明              |
| :---------------------- | :------- | :--- | :---------------- |
| `rand_int(rng, lo, hi)` | i64, i64 | i64  | [lo, hi] 均匀分布 |
| `rand_bool(rng, pct)`   | i64      | bool | pct% 概率为 true  |

### 数学函数

| 函数                          | 签名        | 说明         |
| :---------------------------- | :---------- | :----------- |
| `arr_sum(arr)`                | Array → i64 | 求和         |
| `arr_mean(arr)`               | Array → i64 | 均值         |
| `arr_min/max(arr)`            | Array → i64 | 极值         |
| `arr_std_dev(arr)`            | Array → i64 | 标准差       |
| `arr_slope(arr)`              | Array → i64 | 线性回归斜率 |
| `abs_val(x)`                  | i64 → i64   | 绝对值       |
| `clamp_val(x, lo, hi)`        | i64³ → i64  | 裁剪         |
| `micros(yuan, frac)`          | i64² → i64  | 构造微元     |
| `history_price(market, idx)`  | i64 → i64   | 历史价格     |
| `history_volume(market, idx)` | i64 → i64   | 历史成交量   |
| `history_len(market)`         | → i64       | 历史窗口长度 |

## 11. 待改进项

1. **Agent 错误隔离** — 脚本报错后是否永久禁用该 Agent？当前仅跳过本 Tick
2. **Agent 性能剖析** — 记录每 Agent 平均执行耗时，识别慢脚本
3. **热更新** — 运行中替换 Agent AST 实现策略热加载
4. **多股票支持** — 当前设计为单标的，扩展为多标的需 MarketState 数组化
5. **debug_log** — 注册 `debug_log(msg)` 供 Agent 调试用，可在仿真时关闭
