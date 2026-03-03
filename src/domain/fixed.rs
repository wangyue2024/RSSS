//! 定点数核心常量与安全算术工具
//!
//! 全系统采用 i64 微元 (Micros) 存储价格与金额。
//! 缩放因子 10^6，支持到小数点后 6 位。
//!
//! **零浮点原则**: 本模块不提供任何 f64 入口。
//! 价格直接以整数微元构造：`Price(100_500_000)` 代表 100.50 元。

use super::types::{Price, Vol};

// ============================================================================
// Constants
// ============================================================================

/// 缩放因子: 10^6
///
/// 所有价格和金额的物理存储值 = 逻辑值 × SCALING_FACTOR
///
/// | 逻辑价格 | 物理存储 (micros) |
/// |---------|-------------------|
/// | 100.50  | 100_500_000       |
/// | 0.001   | 1_000             |
/// | 1.0     | 1_000_000         |
pub const SCALING_FACTOR: i64 = 1_000_000;

/// 手续费计算用的基点缩放 (1 bps = 万分之一)
pub const BPS_DIVISOR: i64 = 10_000;

// ============================================================================
// Arithmetic Functions
// ============================================================================

/// 安全计算成交额 (Cost = Price × Volume)
///
/// `Vol` 是原始股数（非微元），所以 cost = price_micros × volume，
/// 结果仍是微元单位的 `Price`。
/// 内部提升至 `i128` 防止 `i64` 乘法溢出。
///
/// # 示例
///
/// ```
/// use rsss::domain::{Price, Vol, calculate_cost};
///
/// let price = Price(100_000_000); // 100.00 元
/// let vol = Vol(50);              // 50 股
/// let cost = calculate_cost(price, vol);
/// assert_eq!(cost, Price(5_000_000_000)); // 5000.00 元
/// ```
#[inline]
pub fn calculate_cost(price: Price, volume: Vol) -> Price {
    let p = price.0 as i128;
    let v = volume.0 as i128;
    Price((p * v) as i64)
}

/// 两个微元值相乘 (用于 Price × Price 类计算，如费率应用)
///
/// 两个微元值相乘会使缩放因子翻倍 (Scale²)，
/// 因此结果需要除以 SCALING_FACTOR 还原到正确的微元精度。
/// 内部使用 `i128` 防止溢出。
#[inline]
pub fn mul_micros(a: i64, b: i64) -> i64 {
    let result = (a as i128 * b as i128) / (SCALING_FACTOR as i128);
    result as i64
}

/// 计算手续费 (Fee = Price × Volume × fee_bps / BPS_DIVISOR / Scale)
///
/// fee_bps 以基点 (Basis Points) 表示，如 3 = 万分之三。
/// 全 i128 中间计算，无精度损失。
///
/// # 示例
///
/// ```
/// use rsss::domain::{Price, Vol, calculate_fee};
///
/// let cost = Price(5_000_000_000); // 5000.00 元的成交额
/// let fee = calculate_fee(cost, 3); // 万分之三
/// assert_eq!(fee, Price(1_500_000)); // 1.50 元手续费
/// ```
#[inline]
pub fn calculate_fee(cost: Price, fee_bps: i64) -> Price {
    let c = cost.0 as i128;
    let fee = (c * fee_bps as i128) / (BPS_DIVISOR as i128);
    Price(fee as i64)
}

// ============================================================================
// Display Utilities
// ============================================================================

/// 将微元值转为人类可读字符串 (仅用于日志/TUI，不用于计算)
///
/// # 示例
///
/// ```
/// use rsss::domain::micros_to_display;
///
/// assert_eq!(micros_to_display(100_500_000), "100.500000");
/// assert_eq!(micros_to_display(-50_300_000), "-50.300000");
/// assert_eq!(micros_to_display(0), "0.000000");
/// ```
pub fn micros_to_display(micros: i64) -> String {
    if micros < 0 {
        format!(
            "-{}.{:06}",
            (-micros) / SCALING_FACTOR,
            (-micros) % SCALING_FACTOR
        )
    } else {
        format!("{}.{:06}", micros / SCALING_FACTOR, micros % SCALING_FACTOR)
    }
}

// ============================================================================
// Tests
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_scaling_factor() {
        assert_eq!(SCALING_FACTOR, 1_000_000);
    }

    // --- calculate_cost ---

    #[test]
    fn test_cost_basic() {
        // 100.00 元 × 50 股 = 5000.00 元
        let cost = calculate_cost(Price(100_000_000), Vol(50));
        assert_eq!(cost, Price(5_000_000_000));
    }

    #[test]
    fn test_cost_fractional_price() {
        // 99.50 元 × 200 股 = 19900.00 元
        let cost = calculate_cost(Price(99_500_000), Vol(200));
        assert_eq!(cost, Price(19_900_000_000));
    }

    #[test]
    fn test_cost_single_share() {
        // 100.00 元 × 1 股 = 100.00 元
        let cost = calculate_cost(Price(100_000_000), Vol(1));
        assert_eq!(cost, Price(100_000_000));
    }

    #[test]
    fn test_cost_zero_volume() {
        let cost = calculate_cost(Price(100_000_000), Vol(0));
        assert_eq!(cost, Price(0));
    }

    #[test]
    fn test_cost_large_values_no_overflow() {
        // 9,000,000.00 元 × 1,000,000 股
        // = 9_000_000_000_000.00 元 (约 9 万亿)
        // 这在 i64 范围内（最大 ~9.22 × 10^12 元），不会溢出
        let cost = calculate_cost(Price(9_000_000_000_000), Vol(1_000_000));
        assert_eq!(cost, Price(9_000_000_000_000_000_000));
    }

    // --- calculate_fee ---

    #[test]
    fn test_fee_basic() {
        // 5000.00 元成交额 × 万分之三 = 1.50 元
        let fee = calculate_fee(Price(5_000_000_000), 3);
        assert_eq!(fee, Price(1_500_000));
    }

    #[test]
    fn test_fee_zero_bps() {
        let fee = calculate_fee(Price(5_000_000_000), 0);
        assert_eq!(fee, Price(0));
    }

    #[test]
    fn test_fee_small_amount() {
        // 10.00 元成交额 × 万分之三 = 0.003 元 = 3000 micros
        let fee = calculate_fee(Price(10_000_000), 3);
        assert_eq!(fee, Price(3_000));
    }

    // --- micros_to_display ---

    #[test]
    fn test_display_positive() {
        assert_eq!(micros_to_display(100_500_000), "100.500000");
    }

    #[test]
    fn test_display_negative() {
        assert_eq!(micros_to_display(-50_300_000), "-50.300000");
    }

    #[test]
    fn test_display_zero() {
        assert_eq!(micros_to_display(0), "0.000000");
    }

    #[test]
    fn test_display_sub_one() {
        assert_eq!(micros_to_display(500_000), "0.500000");
    }

    #[test]
    fn test_display_small_fraction() {
        assert_eq!(micros_to_display(1), "0.000001");
    }
}
