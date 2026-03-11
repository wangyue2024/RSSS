# Record 模块技术文档

## 定位

将仿真数据通过异步 IO 线程写入 CSV 文件，**主线程零阻塞**。

## 架构

```
Simulation Thread                  IO Thread
      │                                │
      │  tx.send(RecordEvent)          │
      ├───────────────────────────────►│
      │  mpsc::sync_channel(4096)      │  rx.recv() → match → BufWriter
      │                                │
      │  RecordEvent::Done             │
      ├───────────────────────────────►│  flush() → break
```

- **背压**: channel 容量 4096。当 IO 线程写入速度跟不上仿真速度时，channel 满，`tx.send()` 阻塞仿真线程，自动限速。
- **无锁**: 仿真线程只调 `tx.send()`，IO 线程只调 `rx.recv()`，无共享内存。

---

## 文件结构

```
src/record/
├── types.rs      RecordConfig + RecordEvent enum
├── writer.rs     RecordWriter (IO 线程)
├── recorder.rs   Recorder (仿真线程 handle)
src/record.rs     模块根 + re-export
```

---

## 核心类型

### RecordConfig

```rust
pub struct RecordConfig {
    pub enabled: bool,       // 是否启用记录
    pub output_dir: String,  // 输出目录 (默认 "output")
}
```

### RecordEvent

通过 channel 发送的事件，4 种变体：

| 变体            | 频率               | 内容                                                     |
| :-------------- | :----------------- | :------------------------------------------------------- |
| `MarketTick`    | 每 Tick 1 条       | tick, price, volume, bid/ask, MA, RSI, VWAP... (17 字段) |
| `Trade`         | 每笔成交           | tick, maker_id, taker_id, price, amount, taker_side      |
| `AgentSnapshot` | 每 Tick × 每 Agent | tick, agent_id, cash, stock, locked_cash, locked_stock, equity, realized_pnl, unrealized_pnl, pending_orders |
| `Done`          | 仿真结束           | 无数据，触发 flush + 退出                                |

---

## 输出文件

### market.csv

每 Tick 1 行，17 列：

```csv
tick,price,volume,buy_vol,sell_vol,bid1_px,bid1_vol,ask1_px,ask1_vol,ma5,ma20,ma60,rsi14,atr14,vwap,stddev,imbalance
0,100000000,0,0,0,99841197,12,100037720,4,100000000,100000000,100000000,5000,0,100000000,0,0
```

- 所有价格/金额为微元 (1 元 = 1,000,000)
- RSI 为百分比 × 100 (5000 = 50.00%)
- imbalance 为万分比 (5000 = 50%)

### trades.csv

每笔成交 1 行：

```csv
tick,maker_id,taker_id,price,amount,taker_side
6,8,3,100037720,3,1
```

- `taker_side`: 1 = 买方主动 (买入), -1 = 卖方主动 (卖出)

### agents.csv

每 Tick × 每 Agent 1 行：

```csv
tick,agent_id,cash,stock,locked_cash,locked_stock,equity,realized_pnl,unrealized_pnl,pending_orders
0,0,10000000000,100,0,0,20000000000,0,0,0
```

**估算数据量** (10,000 Ticks × 100 Agents):
- market.csv ≈ 1 MB
- trades.csv ≈ 根据成交频率，通常 < 5 MB
- agents.csv ≈ 100 MB

---

## API

### Recorder (仿真线程侧)

```rust
// 创建 + 自动启动 IO 线程
let recorder = Recorder::new(&config)?;

// 记录市场快照
recorder.record_market_tick(tick, price, volume, ...);

// 记录成交
recorder.record_trade(tick, maker_id, taker_id, price, amount, side);

// 记录所有 Agent 快照
recorder.record_agent_snapshots(&agents, tick, market_price);

// 发送 Done + 等待 IO 线程结束
recorder.finish();
```

### RecordWriter (IO 线程侧, 内部使用)

```rust
let writer = RecordWriter::new("output/")?;  // 创建目录 + 打开文件 + 写 header
writer.run(rx);  // 主循环: recv → match → write → flush on Done
```

---

## 集成方式

在 `main.rs` 的仿真循环中，每 Tick 结束后调用：

```rust
// Phase 7: Recording (每 Tick)
if let Some(ref rec) = recorder {
    rec.record_market_tick(...);
    rec.record_agent_snapshots(&world.agents, tick, price);
    for &(maker, taker, px, amt, side) in &world.last_tick_trades {
        rec.record_trade(tick, maker, taker, px, amt, side);
    }
}
// 仿真结束
if let Some(rec) = recorder { rec.finish(); }
```

---

## 性能

| 场景                     | 主线程开销                | IO 线程负载            |
| :----------------------- | :------------------------ | :--------------------- |
| 15 Agent × 500 Tick      | < 1ms/tick (channel send) | ~2ms total flush       |
| 1000 Agent × 10,000 Tick | ~0.1ms/tick               | ~30s 写 1GB agents.csv |
| channel 满时             | 阻塞等待 IO               | 背压生效               |

IO 线程使用 `BufWriter` (默认 8KB 缓冲)，syscall 频率远低于每行一次。
