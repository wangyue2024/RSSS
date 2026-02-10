# RSSS 接口与数据规范 (Interface & API Reference) v0.8

本文档定义了 Rust 宿主环境暴露给 Rhai 脚本的所有数据结构与函数库。

## 1. 市场共享状态 (`market` 对象)

Agent 通过 `market` 变量访问只读的全局市场快照。

### A. 时空感知与规则

* `market.tick` (int): 当前时间步。
* `market.total_ticks` (int): 本回合总长度。
* **[新增]** `market.trading_enabled` (bool):
  * `false`: 预热期，禁止下单，仅用于观察和初始化。
  * `true`: 交易期，允许下单。
* **[新增]** `market.fee_rate` (float): 交易费率（例如 `0.0003` 即万分之三）。
  * *提示* : Agent 在计算预期收益时必须包含此成本。

### B. 基础行情

* `market.price` (float): 最新成交价。
* `market.volume` (int): 本 Tick 总成交量。

### C. 资金流向 (Microstructure)

* `market.buy_volume` (int): 主动买入量 (Taker Buy)。
* `market.sell_volume` (int): 主动卖出量 (Taker Sell)。

### D. 盘口深度 (Level-2)

* `market.bids` (Array<[float, int]>): 买盘前 5 档。
* `market.asks` (Array<[float, int]>): 卖盘前 5 档。
* `market.order_imbalance` (float): 盘口压力指标 `[-1, 1]`。

### E. 预计算技术指标 (Indicators)

* `market.ma_5` / `ma_20` / `ma_60`
* `market.high_20` / `low_20`
* `market.vwap`
* `market.std_dev` / `atr_14` / `rsi_14`

### F. 原始历史

* `market.history_prices` (Array`<float>`): 最近 256 个价格。
* `market.history_volumes` (Array`<int>`): 最近 256 个成交量。

## 2. 账户私有状态 (`account` 对象)

### A. 资产

* `account.cash` (float): 现金余额。
* `account.stock` (int): 持仓股数 ( **初始化时可能不为 0** )。
* `account.total_equity` (float): 总资产估值 (扣除预估卖出手续费后的净值)。

### B. 绩效与反馈

* `account.unrealized_pnl` (float): 浮动盈亏。
* `account.avg_cost` (float): 持仓成本价。
* `account.last_order_status` (string/enum): 上一轮订单结果。

### C. 记忆体 (Memory)

* `account.custom_memory` (Map): 唯一的持久化存储。

## 3. 数学工具库 (`math` 模块)

*(同 v0.7，包含 sum, mean, std_dev, slope 等)*

## 4. 决策输出格式

*(同 v0.7，返回 Action, OrderType, Price, Amount)*
