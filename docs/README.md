# RSSS — Rust Stock Simulation System

多 Agent 股票微观结构仿真系统。使用 Rhai 脚本驱动 Agent 策略，基于整数撮合引擎实现零浮点仿真。

---

## 目录

- [快速开始](#快速开始)
- [命令行参数](#命令行参数)
- [项目结构](#项目结构)
- [6 模块详解](#6-模块详解)
- [编写 Agent 策略](#编写-agent-策略)
- [输出与分析](#输出与分析)
- [测试](#测试)
- [技术特性](#技术特性)

---

## 快速开始

### 环境要求

- Rust 1.75+ (2021 Edition)
- Windows / Linux / macOS

### 编译运行

```bash
# 编译
cargo build --release

# TUI 模式 (默认, 实时可视化)
cargo run --release -- scripts --ticks 5000 --agents 15

# 文本模式 (适合 CI/脚本)
cargo run --release -- scripts --ticks 5000 --agents 15 --no-tui

# 查看帮助
cargo run -- --help
```

### 最小示例

```bash
# 使用内置 5 个策略脚本，15 个 Agent，运行 1000 Tick
cargo run -- scripts --ticks 1000 --agents 15 --warmup 0

# 输出文件在 output/ 目录
ls output/
# market.csv  trades.csv  agents.csv
```

---

## 命令行参数

```
Usage: rsss [scripts_dir] [options]

位置参数:
  scripts_dir       策略脚本目录 (默认: scripts)

选项:
  --ticks N         总 Tick 数 (默认: 10000)
  --agents N        Agent 数量 (默认: 1000)
  --seed N          全局随机种子 (默认: 42)
  --warmup N        预热 Tick 数 (默认: 100)
  --cash N          初始现金, 单位: 元 (默认: 10000)
  --stock N         初始持股 (默认: 100)
  --fee N           手续费, 单位: 基点 (默认: 3 = 万分之三)
  --output DIR      CSV 输出目录 (默认: output)
  --no-tui          禁用 TUI, 使用文本进度模式
  --no-record       禁用 CSV 记录
  -h, --help        帮助
```

### 典型用法

```bash
# 大规模仿真: 1000 Agent × 10000 Tick
cargo run --release -- scripts --ticks 10000 --agents 1000

# 调试: 少量 Agent, 短 Tick, 文本模式
cargo run -- scripts --ticks 100 --agents 5 --no-tui

# 不同种子复现实验
cargo run --release -- scripts --ticks 5000 --agents 15 --seed 123
cargo run --release -- scripts --ticks 5000 --agents 15 --seed 456

# 只看 TUI, 不写文件
cargo run --release -- scripts --ticks 5000 --agents 15 --no-record

# 自定义手续费 (万五) + 更多资金
cargo run --release -- scripts --ticks 5000 --agents 15 --fee 5 --cash 50000
```

---

## 项目结构

```
RSSS/
├── Cargo.toml                 依赖配置
├── src/
│   ├── lib.rs                 库入口 (6 模块声明)
│   ├── main.rs                可执行入口 (3 线程架构)
│   ├── domain/                Layer 0: 基础类型
│   │   ├── types.rs           Price, Vol, Order, Side, OrderType
│   │   └── fixed.rs           calculate_cost, calculate_fee, 整数运算
│   ├── engine/                Layer 1: 撮合引擎
│   │   ├── book.rs            OrderBook (双向 BTreeMap)
│   │   ├── events.rs          MatchEvent, RejectReason
│   │   ├── queue.rs           LevelQueue (价格档位)
│   │   └── tests.rs           引擎单元测试
│   ├── scripting/             Layer 2: Rhai 脚本桥
│   │   ├── api.rs             MarketState, AccountView, AgentOrderBook, ActionMailbox
│   │   ├── engine_builder.rs  build_engine() + 函数注册
│   │   ├── math.rs            数学/统计工具函数
│   │   ├── rng.rs             AgentRng (确定性 Xoshiro256++)
│   │   ├── sandbox.rs         安全编译 + 校验
│   │   └── tests.rs           脚本集成测试
│   ├── simulation/            Layer 3: 仿真控制
│   │   ├── config.rs          SimConfig (仿真参数)
│   │   ├── agent.rs           AgentState (运行时状态)
│   │   ├── settlement.rs      结算 + 前置校验
│   │   ├── indicators.rs      技术指标引擎 (MA/RSI/VWAP...)
│   │   ├── world.rs           World (6 阶段 Tick 循环)
│   │   └── tests.rs           仿真集成测试
│   ├── record/                Layer 4: 数据记录
│   │   ├── types.rs           RecordConfig, RecordEvent
│   │   ├── writer.rs          RecordWriter (IO 线程)
│   │   └── recorder.rs        Recorder (仿真线程 handle)
│   └── tui/                   Layer 5: 终端界面
│       ├── state.rs           UiState, AgentUiRow, TradeUiRow
│       ├── ui.rs              ratatui 渲染 (6 组件)
│       └── app.rs             TUI 主循环
├── scripts/                   Agent 策略脚本
│   ├── 01_market_maker.rhai
│   ├── 02_momentum.rhai
│   ├── 03_mean_reversion.rhai
│   ├── 04_noise_trader.rhai
│   └── 05_rsi_contrarian.rhai
├── docs/                      技术文档
│   ├── domain/                类型与运算
│   ├── engine/                撮合引擎
│   ├── scripting/             脚本桥
│   ├── simulation/            仿真控制
│   ├── record/                数据记录
│   └── tui/                   终端界面
└── output/                    CSV 输出 (运行时生成)
```

### 代码统计

| 指标     | 数值                                                           |
| :------- | :------------------------------------------------------------- |
| 模块数   | 6                                                              |
| 源文件   | 22                                                             |
| 总代码行 | ~3500                                                          |
| 单元测试 | 95                                                             |
| 文档测试 | 3                                                              |
| 依赖     | 7 (rhai, rand, rayon, ratatui, crossterm, serde, rand_xoshiro) |

---

## 6 模块详解

### Layer 0: domain (基础类型)

- `Price` / `Vol`: `i64` 新类型，1 元 = 1,000,000 微元
- `Order`: 订单结构 (id, price, amount, agent_id, side, kind)
- `calculate_cost()` / `calculate_fee()`: 纯整数运算，乘法用 `i128` 防溢出

**详细文档**: [docs/domain/](docs/domain/)

### Layer 1: engine (撮合引擎)

- 双向 `BTreeMap` 订单簿 (价格优先 + 时间优先)
- 影子撤单 O(1) + 周期性 GC
- L2 快照 O(K)
- 支持限价单和市价单 (IOC)

**详细文档**: [docs/engine/](docs/engine/)

### Layer 2: scripting (Rhai 脚本桥)

- 零序列化: 数据通过 Copy / Arc 注入 Scope
- 安全沙箱: 每 Tick 最多 500,000 次操作
- RNG 包装为 Rhai CustomType
- 数学/统计工具函数库

**详细文档**: [docs/scripting/](docs/scripting/)

### Layer 3: simulation (仿真控制)

- 6 阶段 Tick 循环 (Pre-Calc → Parallel Decision → Collect → Shuffle → Execute → GC)
- Rayon 并行 Agent 决策
- 5 条严格拒绝规则
- 12 项增量技术指标

**详细文档**: [docs/simulation/](docs/simulation/)

### Layer 4: record (数据记录)

- 异步 IO 线程 + mpsc channel (容量 4096)
- 3 个 CSV 文件: market.csv, trades.csv, agents.csv
- 主线程零阻塞，背压自动限速

**详细文档**: [docs/record/record.md](docs/record/record.md)

### Layer 5: tui (终端界面)

- ratatui + crossterm 全屏 TUI
- 10fps 渲染: 价格走势, L2 盘口, Agent 排行, 成交流
- Arc<Mutex<UiState>> 共享，锁竞争极低

**详细文档**: [docs/tui/tui.md](docs/tui/tui.md)

---

## 编写 Agent 策略

### 脚本格式

每个 `.rhai` 文件必须定义 `on_tick()` 函数：

```rhai
// 顶层变量: 跨 Tick 持久化 (on_init 中初始化)
let my_spread = 0;

// on_tick: 每 Tick 调用一次
fn on_tick() {
    if !market.trading_enabled { return; }

    let price = market.price;
    // ... 策略逻辑 ...

    orders.submit_limit_buy(price - 100000, 5);  // 价格: 微元
}
```

### 可用 API

**只读数据** (每 Tick 自动注入):

| 对象        | 常用字段                                                               |
| :---------- | :--------------------------------------------------------------------- |
| `market`    | `.price`, `.volume`, `.tick`, `.trading_enabled`                       |
| `market`    | `.ma_5`, `.ma_20`, `.ma_60`, `.rsi_14`, `.atr_14`, `.vwap`, `.std_dev` |
| `market`    | `.bid_price(i)`, `.ask_price(i)`, `.bid_vol(i)`, `.ask_vol(i)` (i=0~4) |
| `market`    | `.history_price(i)`, `.history_volume(i)`, `.order_imbalance`          |
| `account`   | `.cash`, `.stock`, `.total_equity`, `.avg_cost`                        |
| `account`   | `.unrealized_pnl`, `.realized_pnl`                                     |
| `my_orders` | `.pending_count()`, `.pending_id(i)`, `.fill_count()`, `.fill_id(i)`   |

**交易动作**:

```rhai
orders.submit_limit_buy(price, amount)    // 返回 order_id
orders.submit_limit_sell(price, amount)
orders.submit_market_buy(amount)
orders.submit_market_sell(amount)
orders.submit_cancel(order_id)
```

**工具函数**:

```rhai
rand_int(rng, min, max)      // 随机整数 [min, max]
rand_bool(rng, pct)          // 随机布尔 (pct% 概率 true)
abs(x)  clamp(x, lo, hi)    micros(yuan)  // 元 → 微元
arr_sum(a)  arr_mean(a)  arr_std_dev(a)  arr_slope(a)
```

### Agent 分配规则

脚本按文件名排序加载，Agent ID 循环分配：

```
15 Agents + 5 Scripts:
  Agent 0,5,10 → 01_market_maker.rhai
  Agent 1,6,11 → 02_momentum.rhai
  Agent 2,7,12 → 03_mean_reversion.rhai
  Agent 3,8,13 → 04_noise_trader.rhai
  Agent 4,9,14 → 05_rsi_contrarian.rhai
```

每个 Agent 拥有独立的 RNG (`seed = hash(global_seed, agent_id)`)，即使使用相同脚本，参数也不同。

### 5 个内置策略

| 脚本                     | 策略     | 逻辑                                    |
| :----------------------- | :------- | :-------------------------------------- |
| `01_market_maker.rhai`   | 做市商   | 每 Tick 撤旧单 + 双边挂单, 库存偏移报价 |
| `02_momentum.rhai`       | 趋势跟随 | MA5/MA20 交叉信号, 信号翻转时下单       |
| `03_mean_reversion.rhai` | 均值回归 | 价格偏离 MA20 超阈值时反向下单          |
| `04_noise_trader.rhai`   | 噪声交易 | 随机方向 + 随机概率 + 随机量            |
| `05_rsi_contrarian.rhai` | RSI 逆势 | RSI 超卖买入, RSI 超买卖出              |

---

## 输出与分析

### CSV 文件

运行后 `output/` 目录下生成 3 个文件：

| 文件         | 内容           | 行数 (N tick × M agent) |
| :----------- | :------------- | :---------------------- |
| `market.csv` | 市场指标快照   | N                       |
| `trades.csv` | 成交明细       | 成交笔数                |
| `agents.csv` | Agent 状态快照 | N × M                   |

所有金额单位为**微元** (1 元 = 1,000,000)。

### Python 分析示例

```python
import pandas as pd
import matplotlib.pyplot as plt

# 价格走势
market = pd.read_csv("output/market.csv")
market["price_yuan"] = market["price"] / 1_000_000
market["price_yuan"].plot(title="Price")
plt.show()

# Agent 收益对比
agents = pd.read_csv("output/agents.csv")
final = agents[agents["tick"] == agents["tick"].max()]
final["equity_yuan"] = final["equity"] / 1_000_000
final.sort_values("equity_yuan", ascending=False).plot.bar(x="agent_id", y="equity_yuan")
plt.show()

# 成交量分布
trades = pd.read_csv("output/trades.csv")
trades["price_yuan"] = trades["price"] / 1_000_000
trades.groupby("tick")["amount"].sum().plot(title="Volume per Tick")
plt.show()
```

---

## 测试

### 快速检查

```bash
# 全部测试 (95 单元 + 3 文档)
cargo test

# 指定模块
cargo test domain::         # 32 测试
cargo test engine::         # 52 测试
cargo test scripting::      # 11 测试
cargo test simulation::     # 6 测试 (含确定性验证)
```

### 测试覆盖

| 模块       | 测试数 | 关键验证                                          |
| :--------- | :----- | :------------------------------------------------ |
| domain     | 32     | Price/Vol 算术, 溢出保护, 定点运算                |
| engine     | 52     | 限价/市价撮合, 影子撤单, GC, L2 快照              |
| scripting  | 11     | API 注入, RNG 确定性, 脚本沙箱, 操作限制          |
| simulation | 6      | World 构建, 空 Tick, 订单下达, 拒绝, 确定性, 预热 |
| doc tests  | 3      | calculate_cost, calculate_fee, micros_to_display  |

### 确定性验证

```bash
# 运行两次相同参数, 输出应完全一致
cargo run -- scripts --ticks 100 --agents 5 --seed 42 --no-tui --output output1
cargo run -- scripts --ticks 100 --agents 5 --seed 42 --no-tui --output output2
diff output1/agents.csv output2/agents.csv  # 应无差异
```

### 性能测试

```bash
# Release 模式
cargo run --release -- scripts --ticks 10000 --agents 100 --no-tui

# 预期性能: ~200-1000 tps (取决于 Agent 数量和策略复杂度)
```

---

## 技术特性

### 整数金融系统

```
1 元 = 1,000,000 微元 (i64)
精度: 0.000001 元 (0.01 分)
范围: ±9.2 × 10^12 元 (足够覆盖任何股票价格)
乘法: 提升 i128 防溢出
除法: 先乘后除保精度
```

### 3 线程架构

```
Main Thread ─── TUI 渲染 (10fps)
Simulation Thread ─── World::run_tick() 循环
IO Thread ─── CSV BufWriter (由 Recorder 管理)
```

### 确定性保证

- 全局 RNG: Xoshiro256++ (种子确定)
- Agent RNG: `seed = hash(global_seed, agent_id)` (per-agent 独立)
- 订单 Shuffle: Fisher-Yates + 全局 RNG
- 无浮点运算, 无线程竞争, 无非确定性系统调用

### 依赖

| crate               | 版本      | 用途                                |
| :------------------ | :-------- | :---------------------------------- |
| rhai                | 1.x       | 脚本引擎 (sync, no_float, only_i64) |
| rand + rand_xoshiro | 0.8 / 0.6 | 确定性随机数生成                    |
| rayon               | 1.11      | 并行 Agent 决策                     |
| ratatui             | 0.30      | 终端 TUI 框架                       |
| crossterm           | 0.29      | 终端控制后端                        |
| serde               | 1.0       | 序列化 (未来 Parquet 用)            |

---

## 详细文档索引

| 文档                | 路径                          |
| :------------------ | :---------------------------- |
| 总体架构            | docs/1.总纲.md                |
| 模块划分            | docs/2.模块划分.md            |
| 功能介绍            | docs/RSSS 功能介绍.md         |
| Domain 类型         | docs/domain/                  |
| Engine 撮合引擎     | docs/engine/                  |
| Scripting 脚本桥    | docs/scripting/               |
| Simulation 仿真控制 | docs/simulation/simulation.md |
| Record 数据记录     | docs/record/record.md         |
| TUI 终端界面        | docs/tui/tui.md               |
