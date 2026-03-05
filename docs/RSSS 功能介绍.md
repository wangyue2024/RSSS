# RSSS 项目功能介绍 — 当前状态

**版本** : v0.1.0 (2026-03-05)
**语言** : Rust 2021 Edition
**定位** : 多 Agent 股票微观结构仿真系统

---

## 1. 系统架构

```
┌────────────────────────────────────────────────────────────────┐
│                          main.rs                               │
│   CLI 入口: 加载脚本 → 构建 World → 运行 → 输出统计            │
└────────────┬───────────────────────────────────────────────────┘
             │
┌────────────▼───────────────────────────────────────────────────┐
│  simulation  (上帝模块)                                        │
│  ┌──────────┐  ┌──────────┐  ┌────────────┐  ┌─────────────┐  │
│  │ config   │  │  agent   │  │ settlement │  │ indicators  │  │
│  └──────────┘  └──────────┘  └────────────┘  └─────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  world.rs — 6 阶段 Tick 循环 (主控)                      │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────┬──────────────────┬────────────────┬──────────────┘
             │                  │                │
┌────────────▼───┐  ┌──────────▼──────┐  ┌──────▼───────────────┐
│  engine        │  │  scripting      │  │  domain              │
│  撮合引擎      │  │  Rhai 脚本桥    │  │  类型与常量           │
│  - OrderBook   │  │  - API 注册     │  │  - Price / Vol       │
│  - MatchEvent  │  │  - Engine 构建  │  │  - calculate_cost    │
│  - L2 Snapshot │  │  - Math / RNG   │  │  - calculate_fee     │
│  - 影子撤单+GC │  │  - 安全沙箱     │  │  - SCALING_FACTOR    │
└────────────────┘  └─────────────────┘  └──────────────────────┘
```

**模块总计**: 4 模块, 19 源文件, ~3000 行代码, **95 单元测试 + 3 文档测试**

---

## 2. 核心特性

### 2.1 整数金融系统 (零浮点)

所有金融值使用 `i64` 微元 (1 元 = 1,000,000 微元):
- 无浮点精度损失, 无 NaN/Inf 风险
- 乘法运算提升 `i128` 防溢出
- Rhai 引擎配置 `no_float` + `only_i64`

### 2.2 确定性仿真 (比特级可复现)

| 环节      | 机制                                                |
| :-------- | :-------------------------------------------------- |
| Agent RNG | `seed = hash(global_seed, agent_id)` → Xoshiro256++ |
| 订单顺序  | Fisher-Yates Shuffle + 全局 Xoshiro256++            |
| 撮合      | Phase 5 严格串行, 无并行竞争                        |
| 指标      | 纯整数运算, 无浮点依赖                              |

**已验证**: 同种子两次运行, 所有 Agent 的 cash/stock/pnl 完全一致。

### 2.3 Rayon 并行决策

Phase 2 使用 `par_iter_mut()` 并行执行 Agent 脚本:
- 每个 Agent 独立拥有 `&mut AgentState`
- `Arc<MarketState>` 零拷贝共享只读市场数据
- `rhai::Engine` 是 `Send + Sync`, 共享 `&Engine`

### 2.4 撮合引擎

- **双向 BTreeMap** 订单簿 (价格优先, 时间优先)
- **影子撤单** O(1): 标记删除 + 幽灵订单
- **周期性 GC** 批量清理幽灵订单
- **L2 快照** O(K): 取 K 档盘口数据
- 支持限价单和市价单 (IOC)

### 2.5 Rhai 脚本沙箱

Agent 策略用 Rhai 脚本语言编写:
- **零序列化**: 数据通过 `Arc` / `Copy` 直接注入 Scope
- **状态持久化**: 顶层变量跨 Tick 保持
- **安全约束**: 每 Tick 最多 500,000 次操作
- **编译时校验**: 脚本必须包含 `on_tick()` 函数

### 2.6 订单前置校验 (严格拒绝制度)

| 条件                             | 拒绝原因          |
| :------------------------------- | :---------------- |
| `amount ≤ 0`                     | ZeroAmount        |
| `price ≤ 0` (限价)               | InvalidPrice      |
| `stock < amount` (卖)            | InsufficientStock |
| `cash < price × amount` (限价买) | InsufficientCash  |
| `cash ≤ 0` (市价买)              | InsufficientCash  |

### 2.7 技术指标引擎

每 Tick O(1) 增量更新, 12 项指标:

| 指标        | 算法                 |
| :---------- | :------------------- |
| MA 5/20/60  | 增量累加器           |
| High/Low 20 | 窗口遍历             |
| VWAP        | Σ(p×v)/Σv, i128 分子 |
| Std Dev 20  | 方差 → Newton isqrt  |
| RSI 14      | 指数移动平均         |
| ATR 14      | EMA of True Range    |
| 历史价格/量 | VecDeque 滑动窗口    |

---

## 3. Agent 可用接口

### 3.1 只读数据 (每 Tick 自动注入)

```
market.price / .volume / .tick / .trading_enabled
market.ma_5 / .ma_20 / .ma_60 / .rsi_14 / .atr_14 / .vwap / .std_dev
market.bid_price(i) / .ask_price(i) / .bid_vol(i) / .ask_vol(i)  (i=0~4)
market.history_price(i) / .history_volume(i)
market.order_imbalance / .high_20 / .low_20

account.cash / .stock / .total_equity / .avg_cost
account.unrealized_pnl / .realized_pnl

my_orders.pending_count() / .pending_id(i) / .pending_price(i) / ...
my_orders.fill_count() / .fill_id(i) / .fill_price(i) / ...
my_orders.history_count() / .history_id(i) / .history_status(i) / ...
```

### 3.2 交易动作

```
orders.submit_limit_buy(price, amount)   → order_id
orders.submit_limit_sell(price, amount)  → order_id
orders.submit_market_buy(amount)         → order_id
orders.submit_market_sell(amount)        → order_id
orders.submit_cancel(order_id)
```

### 3.3 工具函数

```
rand_int(rng, min, max)    rand_bool(rng, pct)
abs(x)  clamp(x, lo, hi)  micros(yuan)
arr_sum(a) arr_mean(a) arr_min(a) arr_max(a) arr_std_dev(a) arr_slope(a)
```

---

## 4. 预热机制 (Warmup)

```
Tick 0 ... warmup_ticks-1:
  ✓ Agent on_tick 正常执行, 可观察 market 数据
  ✓ market.trading_enabled == false
  ✓ Agent 的 submit_* 调用会被收集
  ✗ Phase 5 跳过所有订单 → 不进入引擎 → 无 cash/stock 变动

Tick warmup_ticks ... total_ticks-1:
  ✓ trading_enabled = true, 订单正常执行
```

**当前脚本中的处理**: 所有策略脚本第一行检查 `if !market.trading_enabled { return; }`。

**当前状态**: 上次测试运行 `--warmup 0` (无预热), 第一个 Tick 即开始交易。做市商在 Tick 0 挂出双边报价, 为其他策略提供初始流动性。

---

## 5. 策略运行结果分析 (5000 Ticks, 15 Agents)

### 5.1 总体统计

```
总订单: 32,383    成交: 1,361 笔 (3,559 股)    撤单: 29,857
拒绝: 500,165 (引擎层 — 主要是撤销不存在的订单)
Sim 层拒绝: 0     价格: 100.00 → 98.31 元
```

### 5.2 五种策略表现

| #    | 策略           | Agent ID | 行为                                  | 表现                                                             |
| :--- | :------------- | :------- | :------------------------------------ | :--------------------------------------------------------------- |
| 1    | **做市商**     | 0, 5, 10 | 每 Tick 撤旧单+双边挂单, 库存偏移报价 | 中性: 赚价差但承受库存风险, equity ≈ 19,830~19,850               |
| 2    | **趋势跟随**   | 1, 6, 11 | MA5/MA20 交叉买卖                     | 亏损: 低波动下信号稀少, 追涨杀跌亏手续费, equity ≈ 19,720~19,770 |
| 3    | **均值回归**   | 2, 7, 12 | 偏离 MA20 超阈值反向交易              | **未交易**: 波动未达阈值, equity = 19,832 (仅受价格变化影响)     |
| 4    | **噪声交易者** | 3, 8, 13 | 随机以 5~20% 概率买卖                 | **分化**: #8 大赚 (+9,937 PnL), #3 小亏, 完全取决于随机方向      |
| 5    | **RSI 逆势**   | 4, 9, 14 | RSI 超卖买/超买卖                     | **未交易**: RSI 在 15 Agent 低波动市场始终接近 50, 不触发        |

### 5.3 关键观察

1. **做市商是流动性源头** — 29,857 次撤单 = 每 Tick ~6 次 (3 个做市商各撤~2 单)
2. **噪声交易者是价格驱动力** — 提供随机方向性订单, 与做市商成交
3. **信号类策略 (趋势/RSI/均值) 几乎静默** — 15 Agent 的微市场波动太小, 指标信号极少触发
4. **总 equity 在下降** — 从 300,000 → ~297,600, 差额 ≈ 1,361 × 2 × fee, 即**手续费总消耗**
5. **做市商的引擎拒绝数极高** (500,165) — 因为每 Tick 撤销上一 Tick 的挂单, 但这些挂单可能已成交/已撤, cancel 找不到 → `OrderNotFound`

---

## 6. CLI 用法

```bash
rsss [scripts_dir] [options]

Options:
  --ticks N      总 Tick 数 (默认 10000)
  --agents N     Agent 数量 (默认 1000)
  --seed N       全局随机种子 (默认 42)
  --warmup N     预热 Tick 数 (默认 100)
  --cash N       初始现金 (元, 默认 10000)
  --stock N      初始持股 (默认 100)
  --fee N        手续费基点 (默认 3 = 万三)
  -h, --help     帮助
```

**示例**: `cargo run --release -- scripts --ticks 5000 --agents 15 --warmup 0 --seed 42`

---

## 7. 尚未实现的功能

| 模块                             | 优先级 | 状态                         |
| :------------------------------- | :----- | :--------------------------- |
| 市商流动性增强 / 做市商专属配置  | 🔴 高   | 需讨论: 做市商更多资金/持仓  |
| record (数据持久化)              | 🟡 中   | 原架构规划, 支持 CSV/Parquet |
| generator (LLM 策略生成)         | 🟢 低   | 调用 DeepSeek API 生成 Rhai  |
| tui (终端可视化)                 | 🟢 低   | ratatui 实时盘口/K线         |
| 部分激活 (每 Tick 激活 N% Agent) | 🟢 低   | 模拟真实市场延迟             |
| 多资产支持                       | 🟢 低   | 架构暂为单资产               |
