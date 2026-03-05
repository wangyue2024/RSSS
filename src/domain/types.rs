//! 核心数据类型定义
//!
//! 定义了 RSSS 系统的所有"名词"：Price, Vol, Side, OrderType, Order。
//! 遵循 NewType 模式，利用编译期类型检查防止价格与数量混用。

use serde::{Deserialize, Serialize};
use std::fmt;
use std::ops::{Add, AddAssign, Sub, SubAssign};

use super::fixed::SCALING_FACTOR;

// ============================================================================
// NewType Definitions
// ============================================================================

/// 价格类型 (定点数, 微元 Micros)
///
/// 内部以 `i64` 存储，缩放因子 10^6。
/// 例如：100.50 元 = `Price(100_500_000)`
///
/// 允许负值，用于表示价格差 (spread) 等计算结果。
#[derive(
    Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Default, Hash, Serialize, Deserialize,
)]
pub struct Price(pub i64);

/// 数量类型
///
/// 内部以 `u64` 存储，天然非负。
/// 代表订单数量、成交量等。
#[derive(
    Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Default, Hash, Serialize, Deserialize,
)]
pub struct Vol(pub u64);

// ============================================================================
// Price: 运算符与方法
// ============================================================================

impl Price {
    /// 零价格常量
    pub const ZERO: Price = Price(0);

    /// 获取内部微元值
    #[inline]
    pub fn as_micros(self) -> i64 {
        self.0
    }

    /// 取绝对值
    #[inline]
    pub fn abs(self) -> Price {
        Price(self.0.abs())
    }
}

impl Add for Price {
    type Output = Self;
    #[inline]
    fn add(self, other: Self) -> Self {
        Self(self.0 + other.0)
    }
}

impl Sub for Price {
    type Output = Self;
    #[inline]
    fn sub(self, other: Self) -> Self {
        Self(self.0 - other.0)
    }
}

impl AddAssign for Price {
    #[inline]
    fn add_assign(&mut self, other: Self) {
        self.0 += other.0;
    }
}

impl SubAssign for Price {
    #[inline]
    fn sub_assign(&mut self, other: Self) {
        self.0 -= other.0;
    }
}

impl fmt::Display for Price {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let integer = self.0 / SCALING_FACTOR;
        let decimal = (self.0 % SCALING_FACTOR).abs();
        write!(f, "{}.{:06}", integer, decimal)
    }
}

// ============================================================================
// Vol: 运算符与方法
// ============================================================================

impl Vol {
    /// 零数量常量
    pub const ZERO: Vol = Vol(0);

    /// 获取内部值
    #[inline]
    pub fn as_u64(self) -> u64 {
        self.0
    }

    /// 安全减法：返回 Option 而非 panic
    #[inline]
    pub fn checked_sub(self, other: Self) -> Option<Vol> {
        self.0.checked_sub(other.0).map(Vol)
    }

    /// 取两者中较小的
    #[inline]
    pub fn min(self, other: Self) -> Vol {
        Vol(self.0.min(other.0))
    }
}

impl Add for Vol {
    type Output = Self;
    #[inline]
    fn add(self, other: Self) -> Self {
        Self(self.0 + other.0)
    }
}

impl Sub for Vol {
    type Output = Self;
    #[inline]
    fn sub(self, other: Self) -> Self {
        Self(
            self.0
                .checked_sub(other.0)
                .expect("FATAL: Volume underflow - matching engine bug"),
        )
    }
}

impl AddAssign for Vol {
    #[inline]
    fn add_assign(&mut self, other: Self) {
        self.0 += other.0;
    }
}

impl SubAssign for Vol {
    #[inline]
    fn sub_assign(&mut self, other: Self) {
        // 使用 saturating_sub 防止 cancel+fill 竞争导致的下溢
        // (同一 Tick 内 Shuffle 后, cancel 可能作用于已被 fill 消耗的 total_volume)
        self.0 = self.0.saturating_sub(other.0);
    }
}

impl fmt::Display for Vol {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

// ============================================================================
// Enums
// ============================================================================

/// 订单方向
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[repr(u8)]
pub enum Side {
    /// 买入
    Bid = 0,
    /// 卖出
    Ask = 1,
}

/// 订单类型
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[repr(u8)]
pub enum OrderType {
    /// 限价单
    Limit = 0,
    /// 市价单
    Market = 1,
}

// ============================================================================
// Order
// ============================================================================

/// 核心订单实体
///
/// 采用 `#[repr(C)]` 强制 C 风格内存对齐，确保结构体精确占据 **32 Bytes**，
/// 可在一条 64 字节的 CPU 缓存行中塞入 2 个完整订单。
///
/// **字段语义**:
/// - `amount` 在撮合过程中代表 **剩余未成交量**（Taker 被部分吃单后会原地修改）。
///   一旦挂入盘口，代表 Maker 的剩余挂单量。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[repr(C)]
pub struct Order {
    /// 全局唯一标识，兼作时间序列号 (越小越早)
    pub id: u64, // 8 bytes, offset 0
    /// 定点数价格 (micros)
    pub price: Price, // 8 bytes, offset 8
    /// 订单数量 (剩余未成交量)
    pub amount: Vol, // 8 bytes, offset 16
    /// 所属智能体 ID
    pub agent_id: u32, // 4 bytes, offset 24
    /// 买/卖方向
    pub side: Side, // 1 byte,  offset 28
    /// 市价/限价
    pub kind: OrderType, // 1 byte,  offset 29
                         // padding: 2 bytes, offset 30-31
}

// ============================================================================
// Tests
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    // --- Price tests ---

    #[test]
    fn test_price_construction_and_display() {
        let p = Price(100_500_000); // 100.50 元
        assert_eq!(p.as_micros(), 100_500_000);
        assert_eq!(format!("{}", p), "100.500000");
    }

    #[test]
    fn test_price_negative_display() {
        let p = Price(-50_300_000); // -50.30 元
        assert_eq!(format!("{}", p), "-50.300000");
    }

    #[test]
    fn test_price_arithmetic() {
        let a = Price(100_000_000); // 100.00
        let b = Price(50_500_000); //  50.50
        assert_eq!(a + b, Price(150_500_000)); // 150.50
        assert_eq!(a - b, Price(49_500_000)); //  49.50
    }

    #[test]
    fn test_price_ordering() {
        let low = Price(99_000_000);
        let high = Price(101_000_000);
        assert!(low < high);
        assert_eq!(low.max(high), high);
    }

    #[test]
    fn test_price_zero() {
        assert_eq!(Price::ZERO, Price(0));
        assert_eq!(Price::ZERO.as_micros(), 0);
    }

    #[test]
    fn test_price_abs() {
        assert_eq!(Price(-100_000_000).abs(), Price(100_000_000));
        assert_eq!(Price(100_000_000).abs(), Price(100_000_000));
    }

    // --- Vol tests ---

    #[test]
    fn test_vol_arithmetic() {
        let mut v = Vol(100);
        v += Vol(50);
        assert_eq!(v, Vol(150));
        v -= Vol(30);
        assert_eq!(v, Vol(120));
    }

    #[test]
    fn test_vol_sub_operator() {
        let a = Vol(100);
        let b = Vol(30);
        assert_eq!(a - b, Vol(70));
    }

    #[test]
    fn test_vol_underflow_saturates() {
        let mut v = Vol(10);
        v -= Vol(20); // 应该饱和到 0, 不 panic
        assert_eq!(v, Vol(0));
    }

    #[test]
    fn test_vol_checked_sub() {
        assert_eq!(Vol(100).checked_sub(Vol(30)), Some(Vol(70)));
        assert_eq!(Vol(10).checked_sub(Vol(20)), None);
    }

    #[test]
    fn test_vol_min() {
        assert_eq!(Vol(100).min(Vol(50)), Vol(50));
        assert_eq!(Vol(30).min(Vol(80)), Vol(30));
    }

    // --- Enum tests ---

    #[test]
    fn test_side_discriminant() {
        assert_eq!(Side::Bid as u8, 0);
        assert_eq!(Side::Ask as u8, 1);
    }

    #[test]
    fn test_order_type_discriminant() {
        assert_eq!(OrderType::Limit as u8, 0);
        assert_eq!(OrderType::Market as u8, 1);
    }

    // --- Order tests ---

    #[test]
    fn test_order_memory_layout() {
        assert_eq!(
            std::mem::size_of::<Order>(),
            32,
            "Order struct must be exactly 32 bytes to fit nicely in CPU cache lines"
        );
    }

    #[test]
    fn test_order_construction() {
        let order = Order {
            id: 1,
            price: Price(100_000_000),
            amount: Vol(50),
            agent_id: 42,
            side: Side::Bid,
            kind: OrderType::Limit,
        };
        assert_eq!(order.id, 1);
        assert_eq!(order.price, Price(100_000_000));
        assert_eq!(order.amount, Vol(50));
        assert_eq!(order.agent_id, 42);
        assert_eq!(order.side, Side::Bid);
        assert_eq!(order.kind, OrderType::Limit);
    }

    #[test]
    fn test_order_copy_semantics() {
        let order = Order {
            id: 1,
            price: Price(100_000_000),
            amount: Vol(50),
            agent_id: 0,
            side: Side::Ask,
            kind: OrderType::Market,
        };
        let copy = order; // Copy, not move
        assert_eq!(order, copy); // 原始值仍可用
    }

    // --- Serde tests ---

    #[test]
    fn test_price_serde_roundtrip() {
        let price = Price(100_500_000);
        let json = serde_json::to_string(&price).unwrap();
        let deserialized: Price = serde_json::from_str(&json).unwrap();
        assert_eq!(price, deserialized);
    }

    #[test]
    fn test_order_serde_roundtrip() {
        let order = Order {
            id: 42,
            price: Price(100_500_000),
            amount: Vol(100),
            agent_id: 7,
            side: Side::Bid,
            kind: OrderType::Limit,
        };
        let json = serde_json::to_string(&order).unwrap();
        let deserialized: Order = serde_json::from_str(&json).unwrap();
        assert_eq!(order, deserialized);
    }
}
