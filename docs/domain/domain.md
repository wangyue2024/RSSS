# RSSS 领域内核 (Domain) 模块技术规范与实操指南 v2.0

 **模块名称** : `rsss::domain`
 **核心定位** : 系统的“词汇表”与“物理法则”。
 **设计准则** : 零业务逻辑、零外部依赖 (除 `serde` 外)、极致的内存紧凑性、强类型安全。

## 1. 核心架构哲学 (Architecture Philosophy)

本模块是整个系统的叶子节点，必须严格遵守以下契约：

1. **无依赖性 (Dependency-Free)** : `domain` 绝对不允许引入 `engine`、`simulation` 或任何外部业务模块。
2. **强类型隔离 (Type Safety via NewType)** : 严禁在函数签名中直接使用 `i64` 传递价格或数量，必须使用包装类型，利用编译器消灭“价格加上数量”这种低级错误。
3. **缓存行亲和 (Cache-Line Affinity)** : 核心业务实体（如 `Order`）的大小必须是严格控制的，目标是对齐到 32 字节。
4. **彻底消灭浮点数 (Zero Floating-Point)** : 内部存储绝对禁止出现 `f32/f64`。

## 2. 目录结构规划 (Directory Structure)

```
src/
├── domain/             # 领域内核模块
│   ├── mod.rs          # 导出定义
│   ├── fixed.rs        # 定点数常数与安全算术逻辑
│   └── types.rs        # 核心数据结构 (Price, Vol, Order)
```

## 3. 核心知识与技术规范 (Technical Specifications)

### 3.1 定点数系统规范 (`fixed.rs`)

高频系统中的所有货币价值，在底层物理存储中全部映射为“微元 (Micros)”。

* **缩放因子 (Scaling Factor)** : `1_000_000` (10^6)。支持到小数点后 6 位，足以覆盖绝大多数股票和加密货币的精度要求。
* **物理边界 (Physical Bounds)** :
* `i64::MAX` 约等于 $9.22 \times 10^{18}$。
* 除以缩放因子后，系统最大可表达的金额为 $9.22 \times 10^{12}$ (9.22 万亿)。足够模拟任何单体账户或股票市值。
* **乘法溢出陷阱 (The Overflow Trap)** :
* 两个定点数相乘，规模会被放大 `Scale * Scale`，极易溢出 `i64`。
* **规范** : 所有的金额乘法（如 `Price * Volume` 计算交易额）必须在内部提升至 `i128`，除以 Scale 后，再转回 `i64`。

### 3.2 强类型包装规范 (`types.rs`)

使用 Rust 的元组结构体 (Tuple Struct) 实现 NewType 模式。

```
pub struct Price(pub i64);
pub struct Vol(pub u64); // 数量不为负
```

 **规范要求** : 必须通过 `derive` 宏自动实现 `Ord`, `Eq`, `Copy`, `Hash`, `Serialize` 等 Trait，使其在行为上完全等价于基础数字类型，但在编译期具有独立的类型身份。

### 3.3 Order 结构体内存布局规范 (Memory Layout)

这是高频系统的灵魂。现代 CPU 的缓存行 (Cache Line) 通常是 64 Bytes。我们将 `Order` 严格压榨到  **32 Bytes** ，确保 CPU 每次从内存抓取数据时，能完美塞入 2 个完整的订单，实现内存带宽的翻倍。

 **物理内存布局分析表** :

| 字段            | 类型                   | 大小 (Bytes) | 偏移量 (Offset) | 说明                            |
| :-------------- | :--------------------- | :----------- | :-------------- | :------------------------------ |
| `id`          | `u64`                | 8            | 0               | 全局唯一标识，兼作时间序列号    |
| `price`       | `Price` (`i64`)    | 8            | 8               | 定点数价格                      |
| `amount`      | `Vol` (`u64`)      | 8            | 16              | 订单数量 (剩余未成交量)         |
| `agent_id`    | `u32`                | 4            | 24              | 所属智能体 ID                   |
| `side`        | `Side` (`u8`)      | 1            | 28              | 买/卖方向                       |
| `kind`        | `OrderType` (`u8`) | 1            | 29              | 市价/限价                       |
| *(Padding)*   | `-`                  | 2            | 30              | 编译器自动填充，对齐到 8 的倍数 |
| **Total** |                        | **32** |                 | 完美的半缓存行大小              |

*(注：必须添加 `#[repr(C)]` 以确保编译器不随意重排内存)*

## 4. 实施脚手架 (Code Implementation)

请直接将以下代码复制到对应的文件中。

### 4.1 `src/domain/mod.rs`

```
pub mod fixed;
pub mod types;

// 扁平化导出，方便外部使用 `use rsss::domain::{Order, Price};`
pub use fixed::*;
pub use types::*;
```

### 4.2 `src/domain/fixed.rs`

```
/// 定点数核心常量与工具
/// 采用 6 位小数精度
pub const SCALING_FACTOR: i64 = 1_000_000;

/// 将外部系统的浮点数转化为内部的定点数微元
#[inline]
pub fn to_micros(value: f64) -> i64 {
    (value * SCALING_FACTOR as f64) as i64
}

/// 将内部的定点数微元转化为外部可读的浮点数
#[inline]
pub fn from_micros(micros: i64) -> f64 {
    micros as f64 / SCALING_FACTOR as f64
}

/// 安全计算成交额 (Cost)
/// 公式: (Price * Volume) / Scale
/// 内部采用 i128 防止乘法瞬间溢出 i64 边界
#[inline]
pub fn calculate_cost(price: i64, volume: u64) -> i64 {
    let p = price as i128;
    let v = volume as i128;
    let cost = (p * v) / (SCALING_FACTOR as i128);
    cost as i64
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_fixed_conversion() {
        assert_eq!(to_micros(100.50), 100_500_000);
        assert_eq!(from_micros(100_500_000), 100.50);
    }

    #[test]
    fn test_safe_cost_calculation() {
        let price = to_micros(100.0); // 100,000,000
        let vol = 50;                 // 50 股
        let cost = calculate_cost(price, vol);
        assert_eq!(from_micros(cost), 5000.0);
    }
}
```

### 4.3 `src/domain/types.rs`

*(注意：请确保在 `Cargo.toml` 中添加了 `serde = { version = "1.0", features = ["derive"] }`)*

```
use serde::{Deserialize, Serialize};
use std::ops::{Add, AddAssign, Sub, SubAssign};
use crate::domain::fixed::{from_micros, to_micros};

// --- NewType Definitions ---

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Default, Hash, Serialize, Deserialize)]
pub struct Price(pub i64);

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Default, Hash, Serialize, Deserialize)]
pub struct Vol(pub u64);

// 为 Price 提供便捷的方法与运算符重载
impl Price {
    #[inline] pub fn from_f64(val: f64) -> Self { Self(to_micros(val)) }
    #[inline] pub fn to_f64(self) -> f64 { from_micros(self.0) }
}

impl Add for Price {
    type Output = Self;
    #[inline] fn add(self, other: Self) -> Self { Self(self.0 + other.0) }
}

impl Sub for Price {
    type Output = Self;
    #[inline] fn sub(self, other: Self) -> Self { Self(self.0 - other.0) }
}

// 为 Vol 提供便捷的方法与运算符重载
impl AddAssign for Vol {
    #[inline] fn add_assign(&mut self, other: Self) { self.0 += other.0; }
}

impl SubAssign for Vol {
    #[inline] fn sub_assign(&mut self, other: Self) {
        // 使用 assert 防止由于撮合逻辑 Bug 导致的负成交量
        debug_assert!(self.0 >= other.0, "Volume cannot be negative");
        self.0 -= other.0;
    }
}

// --- Enums ---

/// 订单方向
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[repr(u8)]
pub enum Side {
    Bid = 0, // 买入
    Ask = 1, // 卖出
}

/// 订单类型
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[repr(u8)]
pub enum OrderType {
    Limit = 0,  // 限价单
    Market = 1, // 市价单
}

// --- Core Structs ---

/// 核心订单实体
/// 采用 #[repr(C)] 强制 C 风格内存对齐，确保结构体精确占据 32 Bytes
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[repr(C)]
pub struct Order {
    pub id: u64,          // 8 bytes
    pub price: Price,     // 8 bytes
    pub amount: Vol,      // 8 bytes
    pub agent_id: u32,    // 4 bytes
    pub side: Side,       // 1 byte
    pub kind: OrderType,  // 1 byte
    // padding: 2 bytes
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_order_memory_layout() {
        // 断言验证内存设计的正确性：必须是 32 字节
        assert_eq!(
            std::mem::size_of::<Order>(),
            32,
            "Order struct must be exactly 32 bytes to fit nicely in CPU cache lines"
        );
    }
}
```

## 5. 常见问题排雷 (Pitfalls to Avoid)

1. **`PartialOrd` 排序陷阱** :
   Rust 的 `#[derive(Ord)]` 是根据结构体或元组字段**从上到下**的顺序派生的。对于 `Price(pub i64)`，它会自动按内部 `i64` 比较大小。因此，不需要手动去实现复杂的 `cmp` 逻辑。
2. **`serde` 序列化性能** :
   在将事件抛给 IO 线程写 CSV 时，虽然内部是定点数，但导出的 JSON/CSV 中 `price` 字段会显示为大整数。如果需要在日志中看到可读的 `100.5`，建议在 `simulation` 的输出层 (Presenter Layer) 进行格式化， **不要为了可读性去污染 Domain 内部的结构** 。
