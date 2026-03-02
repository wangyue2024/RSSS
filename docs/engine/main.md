# RSSS 撮合引擎 (Engine) 模块技术规范 v2.0

 **模块名称** : `rsss::engine`
 **核心定位** : 系统的“物理引擎”与“交易大厅”。
 **设计准则** : 纯函数式核心 (Pure Core)、零 IO、无锁设计、确定性撮合。

## 1. 核心架构哲学 (Architecture Philosophy)

本模块严格遵守以下设计约束：

1. **输入输出解耦** : 引擎不直接修改 `Agent` 的资金状态，不打印日志，不写磁盘。它只接收 `Order`，并输出确定的 `Vec<MatchEvent>`。外部世界（Simulation 模块）负责消费这些事件并结算资金。
2. **绝对的时间优先 (Strict Time-Priority)** : 相同价格下，`order.id` (通常隐含序列号) 越小，越早成交。
3. **内存可预测性** : 通过批量预分配和复用，减少运行时的内存碎片。

## 2. 核心数据结构 (Data Structures)

引擎以 `OrderBook` 为核心，摒弃 `BinaryHeap`，全面采用 **`BTreeMap` + 双向队列 (`VecDeque`)** 结构。

### 2.1 盘口结构 (The Book)

```
use std::collections::{BTreeMap, HashMap, VecDeque};

pub struct OrderBook {
    // 买盘：价格降序 (遍历时需 .rev() 或反向迭代)
    pub bids: BTreeMap<Price, LevelQueue>,
    // 卖盘：价格升序
    pub asks: BTreeMap<Price, LevelQueue>,
  
    // 订单倒排索引：用于 O(1) 定位撤单
    pub order_index: HashMap<u64, OrderMeta>, 
}

// 倒排索引的元数据
pub struct OrderMeta {
    pub price: Price,
    pub side: Side,
}
```

### 2.2 价格档位队列 (Level Queue)

```
pub struct LevelQueue {
    // 缓存该价格档位的总挂单量，保证 L2 Snapshot 的 O(1) 读取
    pub total_volume: Vol,     
    // FIFO 队列，保证 Time-Priority
    pub orders: VecDeque<Order>, 
}
```

### 2.3 领域事件 (Domain Events)

引擎的输出是一系列扁平的、可序列化的事件。

```
pub enum MatchEvent {
    // 成交事件：包含 Maker 和 Taker 的 ID、成交价和数量
    Trade { maker_id: u64, taker_id: u64, price: Price, amount: Vol },
    // 挂单成功 (进入 OrderBook)
    Placed { order_id: u64 },
    // 撤单成功
    Cancelled { order_id: u64 },
    // 订单被拒绝 (如市价单无流动性)
    Rejected { order_id: u64, reason: RejectReason },
}
```

## 3. 核心算法与生命周期 (Algorithms & Lifecycle)

### 3.1 下单逻辑 (Order Placement)

引擎处理新订单（Limit 或 Market）是一个**递归或循环尝试吃单**的过程：

1. **检查对手盘** :

* `Bid` 寻找 `asks.first_entry()` (最低卖价)。
* `Ask` 寻找 `bids.last_entry()` (最高买价)。

1. **交叉判断 (Cross Check)** :

* 如果 `Taker` 是限价单，且价格未能穿越 `Maker` 的最优价，进入挂单流程。
* 如果是市价单，无视价格限制，直接吃单。

1. **流动性消耗** :

* 从对手盘的 `LevelQueue.orders` 中 `pop_front()`。
* 生成 `MatchEvent::Trade`。
* 更新 `LevelQueue.total_volume`。
* 如果 Maker 被全吃，继续吃下一个 Maker。如果 Maker 还有剩余，将 Maker `push_front()` 放回原位。

1. **清理空档位** :

* 如果某个 `LevelQueue` 空了，**必须**将其从 `BTreeMap` 中 `remove`，防止内存泄漏和迭代器性能下降。

1. **挂单 (Post to Book)** :

* 如果 `Taker` 还有剩余量，且是限价单：
  * 插入 `order_index`。
  * 插入对应的 `BTreeMap` 档位。
  * 生成 `MatchEvent::Placed`。
* 如果是市价单：剩余量直接抛弃 (IOC 机制)，生成 `MatchEvent::Cancelled`。

### 3.2 影子撤单机制 (Shadow Cancellation)

传统的撤单需要在队列中做 $O(N)$ 的搜索和删除，本系统采用 $O(1)$ ** 影子撤单** ：

1. **收到撤单请求** `Cancel(order_id)`。
2. 从 `order_index` 中查找并 `remove` 掉这个 `order_id`。如果找不到，返回 `Rejected`。
3. 根据索引中的 `Price` 找到 `BTreeMap` 中的 `LevelQueue`。
4. **关键优化** ： **不从 `VecDeque` 中移除实体订单** 。
5. **仅扣减总量** ：`queue.total_volume -= order.amount`。
6. 返回 `MatchEvent::Cancelled`。

 **垃圾回收 (Garbage Collection) / 幽灵订单处理** ：
当撮合循环进行到 `queue.orders.pop_front()` 时，获取到一个 Maker 订单。

* **校验** ：检查这个 Maker 的 `id` 是否还在 `order_index` 中。
* **丢弃** ：如果不在，说明这是一个“幽灵订单”（已经被影子撤单），直接无视它，继续 `pop_front()` 下一个。

*优势：将撤单的耗时操作完全分摊到了撮合阶段，且使得 L2 行情读取依然 100% 准确。*

### 3.3 极速行情快照 (L2 Snapshot)

由于采用了 `BTreeMap` 且 `LevelQueue` 维护了 `total_volume`，获取 Top 5 行情极其轻量：

1. `asks.iter().take(5)`
2. `bids.iter().rev().take(5)`
   复杂度：$O(K)$ (K 为深度，通常为 5 或 10)。无需任何内存分配和排序操作。

## 4. 关键技术规范与性能防线 (Technical Defenses)

### 4.1 内存对齐防线

`Order` 结构体必须维持在 **32 Bytes** 且满足 `#[repr(C)]` 或自然对齐，以保证 `VecDeque` 在 CPU 缓存行（Cache Line）中的极高命中率。禁止向 `Order` 中添加 `String` 或臃肿的容器。

### 4.2 数值安全防线

引擎内部 **禁止出现任何浮点数 (`f32`/`f64`)** 。
所有金额与价格计算必须使用强类型 `Price(i64)` 和 `Vol(u64)`。撮合中不会发生价格相乘，仅发生数量相减，因此不存在算术溢出风险，但需使用 `debug_assert!` 确保不会出现 `Volume < 0` 的情况。

### 4.3 零分配原则 (Zero-Allocation on Hot Path)

除了订单首次挂入 `BTreeMap` 时可能触发 `VecDeque` 的扩容外，撮合过程（Matching）本身不应该触发任何堆内存分配。

* 返回的 `Vec<MatchEvent>` 建议在外层按 Tick 预先 `Vec::with_capacity`。

## 5. 异常处理与测试断言 (Edge Cases & Testing)

开发引擎时，必须实现以下单元测试覆盖：

1. **同价时间优先 (Time Priority)** ：挂入 A(100元), B(100元)。吃单 150 元，断言 A 完全成交，B 部分成交。
2. **市价单击穿 (Market Order Sweep)** ：市价单吃穿多个价格档位，断言生成的 Trade 事件价格依次变化，且空档位被正确清除。
3. **幽灵撤单撮合 (Ghost Order Matching)** ：挂单 A，撤单 A，立即市价吃单。断言市价单不会与 A 成交，且 A 从队列中被静默回收。
4. **自成交保护 (Wash Trade)** ：(可选) 如果 Maker 和 Taker 的 `agent_id` 相同，记录警告事件或阻止成交（取决于仿真的经济学规则设定）。
5. **不变量断言 (Invariants)** ：在每次撮合结束后，`debug_assert!` 买一价必须严格小于卖一价 (Best Bid < Best Ask)。

*文末：本规范作为 RSSS Phase 1 的实施蓝图。所有接口契约锁定，后续代码生成与人工编写均需严格遵守此文档。*
