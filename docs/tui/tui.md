# TUI 模块技术文档

## 定位

基于 ratatui + crossterm 的终端实时界面，在 **Main Thread** 上以 10fps 渲染仿真状态。

## 架构

```
Main Thread (TUI)              Simulation Thread
      │                              │
      │  Arc<Mutex<UiState>>         │
      │◄─────────── read ────────────┤ write (每 Tick)
      │                              │
      │  10fps 渲染循环               │
      │  crossterm 键盘事件           │
```

- TUI 线程 **只读** `UiState`，每 100ms 锁一次
- Simulation 线程 **每 Tick 写一次** `UiState`，锁持有时间 < 10μs
- 锁竞争极低：TUI 10fps vs Simulation ~1000 tps

---

## 文件结构

```
src/tui/
├── state.rs   UiState + AgentUiRow + TradeUiRow
├── ui.rs      ratatui 布局渲染 (6 组件)
├── app.rs     TUI 主循环 (crossterm)
src/tui.rs     模块根 + re-export
```

---

## 界面布局

```
┌─ RSSS — Rust Stock Simulation System ────────────────────────┐
│ Tick: 500/1000 ( 50%)  │  847 tps  │  0.6s  │  Price: 99.72 │
├──────────────────────────┬───────────────────────────────────┤
│  价格走势 (Sparkline)     │  L2 盘口                         │
│  █▅▃▄▆███▇▅▃            │  ASK    99.85  ×  15   (红色)     │
│                          │  ASK    99.83  ×  10              │
│                          │  ─── Spread: 0.40 ───             │
│                          │  BID    99.43  ×  12   (绿色)     │
│                          │  BID    99.42  ×   8              │
├──────────────────────────┴───────────────────────────────────┤
│  Agent 排行              (按 equity 降序, 每 10 Tick 更新)    │
│  ID  Type      Cash      Stock   Equity    PnL               │
│   8  NOISE  13599.65       64  19982.21  +7079.37   (绿色)   │
│   0  MM     10000.00      100  19972.75      0.00            │
│  ...                                                          │
├──────────────────────────────────────────────────────────────┤
│  最近成交                                                     │
│  T 495  B #8→#13  @99.53 ×2     (绿色=买, 红色=卖)           │
│  T 487  S #8→#3   @99.74 ×3                                  │
├──────────────────────────────────────────────────────────────┤
│  Orders: 3232  │  Trades: 130  │  MA5: 99.73  RSI: 50       │
│  [q] Quit                                                     │
└──────────────────────────────────────────────────────────────┘
```

### 6 渲染组件

| 组件       | 位置      | 内容                                                           |
| :--------- | :-------- | :------------------------------------------------------------- |
| Header     | 顶部 1 行 | Tick 进度, tps, 耗时, 当前价, 成交数                           |
| Sparkline  | 左上      | 最近 200 个 Tick 的价格走势 (归一化 u64)                       |
| L2 盘口    | 右上      | 5 档买/卖价量, Spread, ASK 红色 / BID 绿色                     |
| Agent 排行 | 右中      | 按 equity 降序的 Agent 表 (ID, Type, Cash, Stock, Equity, PnL) |
| 最近成交   | 左下      | 最近 20 笔成交 (tick, 方向, maker→taker, @price ×amount)       |
| Footer     | 底部 1 行 | Orders/Trades/Cancels/SimRejects, MA5/MA20/RSI, [q] Quit       |

---

## 核心类型

### UiState

```rust
pub struct UiState {
    pub tick: i64,
    pub total_ticks: i64,
    pub elapsed_secs: f64,
    pub done: bool,                        // 仿真是否完成

    // Market State
    pub price: i64,                        // 当前价 (微元)
    pub volume: i64,                       // 本 Tick 成交量
    pub bid_prices: [i64; 5],              // L2 买盘 5 档价格
    pub bid_volumes: [i64; 5],
    pub ask_prices: [i64; 5],              // L2 卖盘 5 档价格
    pub ask_volumes: [i64; 5],
    pub ma_5: i64,
    pub ma_20: i64,
    pub rsi_14: i64,

    // Engine Stats
    pub total_orders: u64,                 // 累计订单数
    pub total_trades: u64,                 // 累计成交笔数
    pub total_cancels: u64,                // 累计撤单数
    pub sim_rejects: u64,                  // 仿真层拒绝数

    // Chart Data
    pub price_history: VecDeque<i64>,      // 最近 200 Tick 价格

    // Recent Trades
    pub recent_trades: VecDeque<TradeUiRow>, // 最近 20 笔

    // Top Agents
    pub agents: Vec<AgentUiRow>,           // 按 equity 排序
    pub num_scripts: usize,                // 策略脚本数
    pub script_names: Vec<String>,         // 策略名称列表
}
```

### AgentUiRow / TradeUiRow

```rust
pub struct AgentUiRow {
    pub id: u32,
    pub strategy_idx: usize,
    pub cash: i64,
    pub stock: i64,
    pub locked_cash: i64,                  // 挂单冻结资金
    pub locked_stock: i64,                 // 挂单冻结股票
    pub equity: i64,
    pub realized_pnl: i64,
}
pub struct TradeUiRow {
    pub tick: i64, pub maker_id: u32, pub taker_id: u32,
    pub price: i64, pub amount: i64, pub taker_side: i8,
}
```

---

## 键盘操作

| 按键        | 功能                |
| :---------- | :------------------ |
| `q` / `Esc` | 退出仿真 + 恢复终端 |
| `Enter`     | (仿真完成后) 退出   |

---

## 策略类型名映射

根据脚本加载顺序的 `idx % num_scripts`：

| idx  | 名称  | 对应脚本                 |
| :--- | :---- | :----------------------- |
| 0    | MM    | `01_market_maker.rhai`   |
| 1    | MOM   | `02_momentum.rhai`       |
| 2    | MR    | `03_mean_reversion.rhai` |
| 3    | NOISE | `04_noise_trader.rhai`   |
| 4    | RSI   | `05_rsi_contrarian.rhai` |

---

## 终端兼容性

- **crossterm** 后端: 支持 Windows Terminal, CMD, PowerShell, WSL, Linux/macOS 终端
- **Alternate Screen**: 进入全屏模式，退出时恢复原始终端
- **Raw Mode**: 禁用行缓冲，实现逐键输入
- **最小终端尺寸**: 建议 120×30 以获得最佳体验

---

## 非 TUI 模式 (`--no-tui`)

当指定 `--no-tui` 时，不启动 ratatui，改为：
- 每 100 Tick 输出一行进度：`[Tick 100/1000] price=99.72 trades=22 tps=1190`
- 仿真结束后输出完整统计 + Agent Top10 排行
- 不依赖 crossterm，可用于无交互环境 (CI/脚本)
