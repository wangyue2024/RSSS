# RSSS 撮合引擎 (Engine) 模块技术文档 v3.0

**模块名称** : `rsss::engine`
**源码路径** : `src/engine.rs` + `src/engine/{events,queue,book}.rs`
**核心定位** : 系统的"物理引擎"——接收 `Order`，输出 `Vec<MatchEvent>`，不产生任何副作用。

---

## 1. 架构约束

| 约束              | 说明                                           |
| :---------------- | :--------------------------------------------- |
| **零 IO**         | 不打印日志、不写磁盘、不修改 Agent 资金        |
| **Event-Sourced** | 所有状态变更通过 `MatchEvent` 事件流暴露给外部 |
| **价格-时间优先** | 同价位 FIFO，跨价位 BTreeMap 有序              |
| **零浮点**        | 全栈 `Price(i64)` / `Vol(u64)`，无 `f64`       |
| **确定性**        | 相同输入序列 → 相同输出事件流                  |

## 2. 文件结构

```
src/engine.rs           → 模块根，扁平化导出
src/engine/
├── events.rs           → MatchEvent, RejectReason
├── queue.rs            → LevelQueue (价格档位队列)
├── book.rs             → OrderBook, OrderMeta, GcReport
└── tests.rs            → 16 个单元测试
```

## 3. 数据结构

### 3.1 OrderBook

```rust
pub struct OrderBook {
    bids: BTreeMap<Price, LevelQueue>,    // 买盘 (升序存储)
    asks: BTreeMap<Price, LevelQueue>,    // 卖盘 (升序存储)
    order_index: HashMap<u64, OrderMeta>, // 倒排索引
}
```

- `bids` 取最高买价：`.keys().next_back()` → O(log N)
- `asks` 取最低卖价：`.keys().next()` → O(log N)
- `order_index` 支撑 O(1) 影子撤单

### 3.2 LevelQueue

```rust
pub struct LevelQueue {
    pub total_volume: Vol,          // 缓存总量 → L2 O(1) 读取
    pub orders: VecDeque<Order>,    // FIFO → 时间优先
}
```

**关键方法**：

| 方法                 | 语义                     | 修改 total_volume？ |
| :------------------- | :----------------------- | :------------------ |
| `push_back(order)`   | 新订单入队               | ✅ `+= order.amount` |
| `raw_pop_front()`    | 弹出队头（不扣量）       | ❌                   |
| `deduct_volume(vol)` | 手动扣减                 | ✅ `-= vol`          |
| `push_front(order)`  | Maker 部分成交后放回队头 | ✅ `+= order.amount` |

> `raw_pop_front` 不自动扣量的原因：影子撤单时已扣减 `total_volume`，幽灵订单被弹出时不应再扣。

### 3.3 OrderMeta

```rust
pub struct OrderMeta {
    pub price: Price,       // 定位 BTreeMap 档位
    pub side: Side,         // 定位 bids 或 asks
    pub amount: Vol,        // 撤单时扣减 total_volume
    pub agent_id: u32,      // 预留
}
```

### 3.4 MatchEvent

```rust
pub enum MatchEvent {
    Trade {
        maker_order_id: u64,
        taker_order_id: u64,
        maker_agent_id: u32,
        taker_agent_id: u32,
        price: Price,           // 以 Maker 挂单价成交
        amount: Vol,
    },
    Placed {
        order_id: u64,
        price: Price,           // 挂单价格
        remaining: Vol,         // 剩余量
        side: Side,             // 买/卖方向
    },
    Cancelled { order_id: u64 },
    Rejected { order_id: u64, reason: RejectReason },
}

pub enum RejectReason {
    OrderNotFound,
    InsufficientLiquidity,
}
```

## 4. 核心算法

### 4.1 process_order — 主流程

```
  ┌────────────────────────────────┐
  │ process_order(order) → events  │
  └────────┬───────────────────────┘
           ▼
  ┌─── taker.amount > 0 ? ────┐
  │ Yes                        │ No → return events
  ▼                            │
  attempt_match(taker, events) │
  │ true  → loop back ─────────┘
  │ false ↓
  ├─ Limit  → post_to_book + Placed
  └─ Market → IOC 丢弃 (或 Rejected 若无成交)
```

### 4.2 attempt_match — 单次撮合

```rust
fn attempt_match(&mut self, taker: &mut Order, events: &mut Vec<MatchEvent>) -> bool
```

1. **取最优对手价** — `keys().next().copied()` 解决 BTreeMap 借用冲突
2. **交叉判断** — 限价单: `Bid.price >= Ask.best`；市价单: 跳过
3. **幽灵跳过** — `raw_pop_front` + `order_index.contains_key` 循环
4. **空档位递归** — 整个 LevelQueue 全是幽灵 → `remove` 档位 → 递归下一档
5. **量计算** — `trade_amount = min(taker.amount, maker.amount)`
6. **Maker 更新** —

```
deduct_volume(maker.amount)     // 先扣全量
if remaining > 0:
    push_front(remaining_maker)  // 加回剩余量 (push_front 内部 +=)
    index[maker.id].amount = remaining
else:
    index.remove(maker.id)
    清理空 VecDeque 档位
```

> ⚠️ **关键细节**：必须先 `deduct_volume(maker.amount)` 扣掉 Maker 全量，再 `push_front` 加回剩余。不能只扣 `trade_amount`——`push_front` 内部会 `+= remaining`，两者合并后净效果正好等于 `−trade_amount`。

7. **Taker 更新** — `taker.amount -= trade_amount`
8. **事件发射** — `Trade { price: best_price, ... }`（以 Maker 价成交）

### 4.3 cancel_order — 影子撤单

```
O(1) 三步:
  1. order_index.remove(id) → OrderMeta { price, side, amount }
  2. book[side].get_mut(price)
  3. queue.deduct_volume(meta.amount)
  └→ VecDeque 中的实体不动（变为幽灵），等撮合时跳过或 GC 清理
```

### 4.4 gc_phantom_orders — GC 回收

```rust
pub fn gc_phantom_orders(&mut self) -> GcReport
```

遍历每个 LevelQueue：
1. `orders.retain(|o| index.contains_key(o.id))`
2. 重算 `total_volume = Σ order.amount`
3. 空队列 → 从 BTreeMap 移除

**触发策略**（由 Simulation 层决定）：
- 每 N 个 Tick 定期调用
- 或 `phantom_count()` 超过阈值时触发

### 4.5 get_l2_snapshot — 行情快照

```rust
pub fn get_l2_snapshot(&self, depth: usize) -> (Vec<(Price, Vol)>, Vec<(Price, Vol)>)
```

- 买盘: `bids.iter().rev().take(depth)` → 最高价在前
- 卖盘: `asks.iter().take(depth)` → 最低价在前
- 复杂度 O(K)，返回 `(L2Side, L2Side)` 其中 `type L2Side = Vec<(Price, Vol)>`

### 4.6 EngineStats — 运行时统计

```rust
pub struct EngineStats {
    pub total_orders: u64,        // process_order 调用总次数
    pub total_trades: u64,        // Trade 事件数
    pub total_trade_volume: Vol,  // Trade.amount 累计
    pub total_cancels: u64,       // 成功撤单数
    pub total_rejects: u64,       // Rejected 事件数
    pub total_placed: u64,        // Placed 事件数
}
```

通过 `book.stats()` 获取引用。统计在 `process_order`、`cancel_order`、`attempt_match` 中自动更新，开销仅为整数加法。

## 5. 公开 API 一览

| 方法                     | 签名                 | 复杂度     |
| :----------------------- | :------------------- | :--------- |
| `new()`                  | `→ OrderBook`        | O(1)       |
| `with_capacity(n)`       | `→ OrderBook`        | O(1)       |
| `process_order(order)`   | `→ Vec<MatchEvent>`  | O(M·log N) |
| `cancel_order(id)`       | `→ MatchEvent`       | O(log N)   |
| `get_l2_snapshot(depth)` | `→ (L2Side, L2Side)` | O(K)       |
| `gc_phantom_orders()`    | `→ GcReport`         | O(N)       |
| `phantom_count()`        | `→ usize`            | O(L)       |
| `order_count()`          | `→ usize`            | O(1)       |
| `stats()`                | `→ &EngineStats`     | O(1)       |
| `best_bid()`             | `→ Option<Price>`    | O(log N)   |
| `best_ask()`             | `→ Option<Price>`    | O(log N)   |

> N = 档位数, M = 跨档次数, K = 快照深度, L = 档位总数

## 6. Rust 工程要点

### 6.1 BTreeMap 借用冲突

```rust
// ✅ 正确: 先 Copy 出 Price，释放不可变借用，再 get_mut
let best_price = self.asks.keys().next().copied();
if let Some(price) = best_price {
    let queue = self.asks.get_mut(&price).unwrap();
}
```

### 6.2 幽灵订单跳过模式

```rust
let maker = loop {
    let order = queue.raw_pop_front()?;   // 不扣量
    if self.order_index.contains_key(&order.id) {
        break order;                       // 有效
    }
    // 幽灵 → 丢弃，不再扣量（cancel 时已扣）
};
```

### 6.3 空档位递归穿透

当整个 LevelQueue 全是幽灵时，`raw_pop_front` 循环会把 VecDeque 掏空。此时 `remove` 该档位，递归调用 `attempt_match` 自动穿透到下一档。

## 7. 测试覆盖（16 个用例）

| #    | 用例                              | 覆盖                 |
| :--- | :-------------------------------- | :------------------- |
| 1    | `test_post_to_book`               | 挂单 + L2 聚合       |
| 2    | `test_post_multiple_price_levels` | 多档挂单排序         |
| 3    | `test_exact_match`                | 精确成交 + L2 清空   |
| 4    | `test_taker_crosses_better_price` | 以 Maker 价成交      |
| 5    | `test_partial_taker_remaining`    | Taker 剩余挂单       |
| 6    | `test_partial_maker_remaining`    | Maker 剩余留盘       |
| 7    | `test_time_priority`              | 同价 FIFO            |
| 8    | `test_market_order_sweep`         | 市价单多档击穿       |
| 9    | `test_market_order_no_liquidity`  | 市价单无对手盘拒绝   |
| 10   | `test_market_order_partial_ioc`   | 市价单 IOC 部分成交  |
| 11   | `test_shadow_cancellation`        | O(1) 影子撤单        |
| 12   | `test_cancel_nonexistent_order`   | 撤不存在的单         |
| 13   | `test_double_cancel`              | 重复撤单             |
| 14   | `test_ghost_order_skipped`        | 幽灵订单被跳过       |
| 15   | `test_gc_cleans_phantom_orders`   | GC 清理 + 空档位移除 |
| 16   | `test_phantom_count`              | 幽灵计数             |
| 17   | `test_no_cross_no_trade`          | 价格不交叉           |
| 18   | `test_mixed_scenario`             | 综合：撮合+撤单+挂单 |
| 19   | `test_engine_stats`               | 统计累计正确性       |
| 20   | `test_stats_rejects`              | 拒绝计数正确性       |

## 8. 待改进项

1.  **市价单滑点保护** — `Order` 加 `worst_price: Option<Price>`
2.  **自成交保护** — Maker/Taker 同 agent_id 时可选阻止或告警
3.  **`attempt_match` 递归 → 迭代** — 极端深度幽灵档位可能栈溢出
