# RSSS 引擎模块 (Engine) 实操步骤与代码框架

> [!NOTE]
> **文件定位说明**：
> 本文件为一个**开发教程与 TDD 实现脚手架 (TDD Implementation Skeleton)**。它记录了引擎从 0 到 1 构建时的步骤、桩代码 (`unimplemented!()`) 及排雷指南。
> 对后续实际开发和引擎最终使用机制的学习，请参考核心参考文档 [`engine.md`](engine.md)。

本指南旨在将 `docs/engine_spec.md` 中的理论设计转化为实际的 Rust 代码工程。我们将采用 **TDD (测试驱动开发)** 的思路，先搭骨架，再填肌肉。

## 1. 目录结构规划 (Directory Structure)

在您的 Rust 项目 `src` 目录下，按照以下结构创建文件。将职责拆分到不同的文件，可以保持代码的极度清晰。

```
src/
├── domain/             # (已有) 存放 Price, Vol, Order 等核心类型定义
│   ├── mod.rs
│   └── types.rs
├── engine/             # 撮合引擎模块
│   ├── mod.rs          # 导出引擎对外 API
│   ├── events.rs       # 定义 MatchEvent (领域事件)
│   ├── queue.rs        # LevelQueue 的实现 (价格档位内的队列)
│   ├── book.rs         # OrderBook 核心撮合逻辑
│   └── tests.rs        # 单元测试 (TDD)
└── main.rs
```

## 2. 实施步骤与代码脚手架 (Step-by-Step Implementation)

### 步骤 1: 定义领域事件 (`src/engine/events.rs`)

这是引擎与外部世界（Agent, 资金账户）通信的唯一媒介。

```
// src/engine/events.rs
use crate::domain::types::{Price, Vol};

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MatchEvent {
    /// 撮合成交：同时携带 Order ID 和 Agent ID
    Trade {
        maker_order_id: u64,
        taker_order_id: u64,
        maker_agent_id: u32,
        taker_agent_id: u32,
        price: Price,
        amount: Vol,
    },
    /// 挂单成功：未能立即成交的部分进入盘口
    Placed { order_id: u64 },
    /// 撤单成功：基于影子撤单机制
    Cancelled { order_id: u64 },
    /// 订单拒绝
    Rejected { order_id: u64, reason: RejectReason },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RejectReason {
    OrderNotFound,
    InsufficientLiquidity,
    InvalidPrice,
}
```

### 步骤 2: 实现价格队列 (`src/engine/queue.rs`)

封装 `VecDeque`，维护 `total_volume`，这是保证 $O(1)$ 读取 L2 数据的关键。

```
// src/engine/queue.rs
use std::collections::VecDeque;
use crate::domain::types::{Order, Vol};

#[derive(Debug, Default, Clone)]
pub struct LevelQueue {
    pub total_volume: Vol,
    pub orders: VecDeque<Order>,
}

impl LevelQueue {
    pub fn new() -> Self {
        Self {
            total_volume: Vol(0),
            orders: VecDeque::new(),
        }
    }

    /// 订单排队
    pub fn push_back(&mut self, order: Order) {
        self.total_volume.0 += order.amount.0;
        self.orders.push_back(order);
    }

    /// 原始弹出：从队头取出一个订单，**不**自动扣减 total_volume
    /// 原因：影子撤单时已扣减过 total_volume，幽灵订单被 pop 时不应再次扣减
    /// 调用方根据订单是否为幽灵来决定是否扣量
    pub fn raw_pop_front(&mut self) -> Option<Order> {
        self.orders.pop_front()
    }

    /// 扣减有效订单的成交量 (与 raw_pop_front 配合使用)
    pub fn deduct_volume(&mut self, vol: Vol) {
        self.total_volume -= vol;
    }

    /// 将部分成交的订单放回队头
    pub fn push_front(&mut self, order: Order) {
        self.total_volume.0 += order.amount.0;
        self.orders.push_front(order);
    }

    pub fn is_empty(&self) -> bool {
        self.orders.is_empty()
    }
}
```

### 步骤 3: 核心撮合引擎骨架 (`src/engine/book.rs`)

这是整个系统最复杂的地方。我已经为您搭建了符合借用检查器（Borrow Checker）习惯的函数签名。

```
// src/engine/book.rs
use std::collections::{BTreeMap, HashMap};
use crate::domain::types::{Order, OrderType, Price, Side, Vol};
use super::events::{MatchEvent, RejectReason};
use super::queue::LevelQueue;

/// 倒排索引元数据：存储挂单时的价格、方向和数量
pub struct OrderMeta {
    pub price: Price,
    pub side: Side,
    pub amount: Vol,  // 撤单时用于扣减 total_volume
}

pub struct OrderBook {
    pub bids: BTreeMap<Price, LevelQueue>, // 买盘
    pub asks: BTreeMap<Price, LevelQueue>, // 卖盘
    pub order_index: HashMap<u64, OrderMeta>, // 撤单索引
}

impl OrderBook {
    pub fn new() -> Self {
        Self {
            bids: BTreeMap::new(),
            asks: BTreeMap::new(),
            order_index: HashMap::new(),
        }
    }

    /// 核心入口：接收订单，返回事件列表
    pub fn process_order(&mut self, order: Order) -> Vec<MatchEvent> {
        let mut events = Vec::new();
        let mut taker = order;
        // [To-Do]: 
        // 1. 循环调用 attempt_match 直到无成交量或无对手盘
        // 2. 如果还有剩余：
        //    - 限价单: 挂单 (post_to_book)
        //    - 市价单: 剩余量直接抛弃 (IOC)
        unimplemented!()
    }

    /// 执行影子撤单
    pub fn cancel_order(&mut self, order_id: u64) -> MatchEvent {
        // [To-Do]:
        // 1. 从 order_index 中 remove 取出 OrderMeta { price, side, amount }
        // 2. 根据 side 找到对应的 BTreeMap (bids 或 asks)
        // 3. 根据 price 找到 LevelQueue
        // 4. 扣减 queue.total_volume -= meta.amount (不操作 VecDeque)
        // 5. 返回 Cancelled / Rejected { reason: OrderNotFound }
        unimplemented!()
    }

    /// 获取 L2 快照 (极速)
    pub fn get_l2_snapshot(&self, depth: usize) -> (Vec<(Price, Vol)>, Vec<(Price, Vol)>) {
        // [To-Do]: 使用 bids.iter().rev() 和 asks.iter()
        unimplemented!()
    }

    /// GC 回收：清理幽灵订单
    pub fn gc_phantom_orders(&mut self) -> GcReport {
        // [To-Do]:
        // 1. 遍历所有 LevelQueue
        // 2. retain 仅保留 order_index 中存在的订单
        // 3. 重算 total_volume
        // 4. 清理空的价格档位
        unimplemented!()
    }

    /// 快速统计幽灵订单数
    pub fn phantom_count(&self) -> usize {
        let total_in_queues: usize = self.bids.values().map(|q| q.orders.len()).sum::<usize>()
            + self.asks.values().map(|q| q.orders.len()).sum::<usize>();
        total_in_queues - self.order_index.len()
    }

    // --- 私有辅助函数 ---

    /// 挂单逻辑
    fn post_to_book(&mut self, order: Order) {
        // [To-Do]: 插入 order_index (OrderMeta { price, side, amount })，插入对应 BTreeMap
    }

    /// 尝试进行一次撮合循环
    /// events: 用于收集产生的 Trade 事件
    /// 返回值：是否需要继续撮合
    fn attempt_match(&mut self, taker: &mut Order, events: &mut Vec<MatchEvent>) -> bool {
        // [To-Do]: 
        // 1. 查找最优对手价 (best_ask / best_bid)
        // 2. 交叉验证 (Cross Check)
        // 3. 幽灵订单清理 (Ghost Order GC): 
        //    从 LevelQueue raw_pop_front() 后，检查 id 是否在 order_index 中
        //    有效订单: deduct_volume + 生成 Trade
        //    幽灵订单: 直接丢弃，不扣量
        // 4. 生成 Trade 事件 push 到 events
        unimplemented!()
    }
}

pub struct GcReport {
    pub cleaned_count: usize,
    pub remaining_orders: usize,
    pub removed_levels: usize,
}
```

### 步骤 4: 暴露模块接口 (`src/engine/mod.rs`)

将内部的组件有序地暴露给外部的 `simulation` 模块。

```
// src/engine/mod.rs
pub mod events;
pub mod queue;
pub mod book;

#[cfg(test)]
mod tests;

// 重新导出常用结构，方便外部调用
pub use events::MatchEvent;
pub use book::OrderBook;
```

## 3. 开发排雷指南 (Rust-Specific Traps)

在填充 `book.rs` 的 `[To-Do]` 时，您肯定会遇到 Rust 的“借用检查器”报错。请牢记以下模式：

### 陷阱 1: Mutating BTreeMap values while iterating

 **症状** : `cannot borrow self.asks as mutable because it is also borrowed as immutable`。当你用 `best_ask()` 拿到一个价格的引用，然后试图修改对应的 `LevelQueue` 时会报错。
 **解法** :
先取出 `Price` (因为 `Price` 实现了 `Copy`)，放弃掉对 `BTreeMap` 的不可变借用，然后再使用 `get_mut(&price)` 去修改。

```
// 错误写法
// let (price, queue) = self.asks.first_key_value().unwrap(); 
// queue.pop_front(); // 报错！

// 正确写法
let best_price = self.asks.keys().next().copied(); 
if let Some(price) = best_price {
    let queue = self.asks.get_mut(&price).unwrap();
    // 现在可以安全地修改 queue 了
}
```

### 陷阱 2: Empty Queue 清理延迟

 **症状** : L2 数据出现 `Volume = 0` 的挂单价格，或者引擎变慢。
 **解法** : 每次对 `queue` 进行 `pop_front()` 操作后，**必须**检查 `queue.is_empty()`。如果为空，立刻使用 `self.asks.remove(&price)` 将这个档位从 BTreeMap 中连根拔起。

### 陷阱 3: 幽灵订单未丢弃

 **症状** : 已经撤销的单子突然被撮合成交了！
 **解法** : 严格执行影子撤单 GC。

```
let mut maker_order = loop {
    let order = queue.raw_pop_front()?; // 如果队列空了，退出
    if self.order_index.contains_key(&order.id) {
        // 有效订单：扣减成交量 (影子撤单未触及此订单)
        break order;
    }
    // 幽灵订单：影子撤单时已扣减 total_volume，此处直接丢弃，不再扣量
};
```

## 4. TDD 推荐测试用例顺序

请在 `src/engine/tests.rs` 中按以下顺序编写测试，这将帮助你逐一击破逻辑难点：

1. `test_post_to_book()`: 下两个买单，验证 `get_l2_snapshot` 是否正确聚合量。
2. `test_exact_match()`: 下一个 100 块的买单，再下一个 100 块的卖单，验证是否输出 `MatchEvent::Trade` 且 L2 清空。
3. `test_partial_match()`: 测试数量不匹配时的吃单（留有余额）。
4. `test_shadow_cancellation()`: 下单 -> 取消单 -> `assert!(order_index.is_empty())` -> 验证 L2 总量被扣减。
5. `test_ghost_order_skipped()`: 下单A -> 下单B -> 取消下单A -> 对手盘市价吃单 -> 断言 B 被吃，A 被直接丢弃。
6. `test_gc_cleans_phantom_orders()`: 下单A -> 撤单A -> 调用 `gc_phantom_orders()` -> 断言 `phantom_count() == 0` 且 VecDeque 已清空。
7. `test_phantom_count()`: 下 5 个单，撤 3 个 -> 断言 `phantom_count() == 3`。
