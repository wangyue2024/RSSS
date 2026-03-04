//! 数学函数库
//!
//! 全部注册为 Rhai 顶层函数，Rust 侧高性能实现。
//! 输入 `rhai::Array` (= `Vec<Dynamic>`)，内部解析为 `i64` 后计算。

use rhai::{Array, INT};

// ============================================================================
// 数组函数
// ============================================================================

/// 数组求和
pub fn arr_sum(arr: Array) -> INT {
    arr.iter().filter_map(|v| v.as_int().ok()).sum()
}

/// 数组均值 (整数除法，向零截断)
pub fn arr_mean(arr: Array) -> INT {
    let (sum, count) = arr
        .iter()
        .filter_map(|v| v.as_int().ok())
        .fold((0_i64, 0_i64), |(s, c), v| (s + v, c + 1));
    if count == 0 {
        0
    } else {
        sum / count
    }
}

/// 数组最小值
pub fn arr_min(arr: Array) -> INT {
    arr.iter()
        .filter_map(|v| v.as_int().ok())
        .min()
        .unwrap_or(0)
}

/// 数组最大值
pub fn arr_max(arr: Array) -> INT {
    arr.iter()
        .filter_map(|v| v.as_int().ok())
        .max()
        .unwrap_or(0)
}

/// 数组标准差 (总体标准差, 整数近似)
///
/// σ = sqrt(Σ(xi - mean)² / n)
/// 结果为 i64，精度与输入单位一致（微元输入 → 微元输出）
pub fn arr_std_dev(arr: Array) -> INT {
    let values: Vec<i64> = arr.iter().filter_map(|v| v.as_int().ok()).collect();
    let n = values.len() as i64;
    if n <= 1 {
        return 0;
    }
    let mean = values.iter().sum::<i64>() / n;
    // 用 i128 避免平方溢出
    let variance = values
        .iter()
        .map(|&v| {
            let diff = (v - mean) as i128;
            diff * diff
        })
        .sum::<i128>()
        / n as i128;
    // 整数平方根 (Newton's method)
    isqrt_i128(variance) as INT
}

/// 线性回归斜率 (最小二乘法)
///
/// 对序列 y[0..n] 拟合 y = a + b*x，返回斜率 b。
/// x 隐式为 0, 1, 2, ..., n-1。
///
/// b = (n * Σ(x*y) - Σx * Σy) / (n * Σ(x²) - (Σx)²)
///
/// 结果为 i64，表示"每个索引步的 y 变化量"。
pub fn arr_slope(arr: Array) -> INT {
    let values: Vec<i64> = arr.iter().filter_map(|v| v.as_int().ok()).collect();
    let n = values.len() as i128;
    if n <= 1 {
        return 0;
    }

    let mut sum_x: i128 = 0;
    let mut sum_y: i128 = 0;
    let mut sum_xy: i128 = 0;
    let mut sum_x2: i128 = 0;

    for (i, &y) in values.iter().enumerate() {
        let x = i as i128;
        let y = y as i128;
        sum_x += x;
        sum_y += y;
        sum_xy += x * y;
        sum_x2 += x * x;
    }

    let denom = n * sum_x2 - sum_x * sum_x;
    if denom == 0 {
        return 0;
    }
    let numer = n * sum_xy - sum_x * sum_y;
    (numer / denom) as INT
}

// ============================================================================
// 标量工具函数
// ============================================================================

/// 绝对值
pub fn abs_val(x: INT) -> INT {
    x.abs()
}

/// 裁剪到 [lo, hi] 范围
pub fn clamp_val(x: INT, lo: INT, hi: INT) -> INT {
    x.max(lo).min(hi)
}

/// 构造微元: `micros(100, 500_000)` = `100_500_000`
pub fn micros(yuan: INT, frac: INT) -> INT {
    yuan * 1_000_000 + frac
}

// ============================================================================
// 内部工具
// ============================================================================

/// 整数平方根 (Newton's method for i128)
fn isqrt_i128(n: i128) -> i64 {
    if n <= 0 {
        return 0;
    }
    if n <= i64::MAX as i128 {
        return isqrt_i64(n as i64);
    }
    // Fallback for very large values
    let mut x = (n as f64).sqrt() as i128;
    loop {
        let nx = (x + n / x) / 2;
        if nx >= x {
            break;
        }
        x = nx;
    }
    x as i64
}

/// 整数平方根 (Newton's method for i64)
fn isqrt_i64(n: i64) -> i64 {
    if n <= 0 {
        return 0;
    }
    let mut x = (n as f64).sqrt() as i64;
    // 校正浮点近似
    loop {
        let nx = (x + n / x) / 2;
        if nx >= x {
            break;
        }
        x = nx;
    }
    x
}

#[cfg(test)]
mod tests {
    use super::*;
    use rhai::Dynamic;

    fn make_arr(vals: &[i64]) -> Array {
        vals.iter().map(|&v| Dynamic::from(v)).collect()
    }

    #[test]
    fn test_arr_sum() {
        assert_eq!(arr_sum(make_arr(&[1, 2, 3, 4, 5])), 15);
        assert_eq!(arr_sum(make_arr(&[])), 0);
    }

    #[test]
    fn test_arr_mean() {
        assert_eq!(arr_mean(make_arr(&[10, 20, 30])), 20);
        assert_eq!(arr_mean(make_arr(&[7, 8])), 7); // 整数截断
        assert_eq!(arr_mean(make_arr(&[])), 0);
    }

    #[test]
    fn test_arr_min_max() {
        assert_eq!(arr_min(make_arr(&[5, 3, 8, 1, 9])), 1);
        assert_eq!(arr_max(make_arr(&[5, 3, 8, 1, 9])), 9);
        assert_eq!(arr_min(make_arr(&[])), 0);
    }

    #[test]
    fn test_arr_std_dev() {
        // 全部相同 → 标准差 0
        assert_eq!(arr_std_dev(make_arr(&[5, 5, 5, 5])), 0);
        // [0, 10] → mean=5, variance=25, std=5
        assert_eq!(arr_std_dev(make_arr(&[0, 10])), 5);
    }

    #[test]
    fn test_arr_slope() {
        // 完美线性: y = 10*x → slope = 10
        assert_eq!(arr_slope(make_arr(&[0, 10, 20, 30])), 10);
        // 水平线 → slope = 0
        assert_eq!(arr_slope(make_arr(&[5, 5, 5, 5])), 0);
        // 单点 → 0
        assert_eq!(arr_slope(make_arr(&[42])), 0);
    }

    #[test]
    fn test_scalar_fns() {
        assert_eq!(abs_val(-42), 42);
        assert_eq!(abs_val(42), 42);
        assert_eq!(clamp_val(150, 0, 100), 100);
        assert_eq!(clamp_val(-5, 0, 100), 0);
        assert_eq!(clamp_val(50, 0, 100), 50);
        assert_eq!(micros(100, 500_000), 100_500_000);
    }
}
