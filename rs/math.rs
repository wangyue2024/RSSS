use rhai::{Module, FnNamespace};
use statrs::statistics::Statistics; // 引入 Rust 社区的高性能统计库

// 注册数学模块的核心函数
pub fn create_module() -> Module {
    let mut module = Module::new();

    // 1. 基础聚合 (利用 Rust Iterator 的原生速度)
    // 脚本调用: math.sum(list)
    module.set_native_fn("sum", |arr: Vec<f64>| -> f64 {
        arr.iter().sum()
    });

    // 脚本调用: math.mean(list)
    module.set_native_fn("mean", |arr: Vec<f64>| -> f64 {
        if arr.is_empty() { 0.0 } else { arr.iter().sum::<f64>() / arr.len() as f64 }
    });

    // 2. 高级统计 (利用 statrs 库)
    // 脚本调用: math.variance(list)
    module.set_native_fn("variance", |arr: Vec<f64>| -> f64 {
        if arr.len() < 2 { return 0.0; }
        // 直接调用 statrs 库的优化实现，速度极快
        arr.variance() 
    });

    // 脚本调用: math.std_dev(list)
    module.set_native_fn("std_dev", |arr: Vec<f64>| -> f64 {
        if arr.len() < 2 { return 0.0; }
        arr.std_dev()
    });

    // 3. 线性回归斜率 (Slope) - 量化策略核心指标
    // 脚本调用: math.slope(list)
    module.set_native_fn("slope", |arr: Vec<f64>| -> f64 {
        let n = arr.len() as f64;
        if n < 2.0 { return 0.0; }

        // 使用最小二乘法计算斜率
        // 这里手动实现是为了避免引入过于沉重的 linreg 库，但这依然是编译级的 C++ 速度
        let sum_x: f64 = (0..arr.len()).map(|i| i as f64).sum();
        let sum_y: f64 = arr.iter().sum();
        let sum_xy: f64 = arr.iter().enumerate().map(|(i, &y)| i as f64 * y).sum();
        let sum_xx: f64 = (0..arr.len()).map(|i| (i * i) as f64).sum();

        let numerator = n * sum_xy - sum_x * sum_y;
        let denominator = n * sum_xx - sum_x * sum_x;

        if denominator == 0.0 { 0.0 } else { numerator / denominator }
    });

    // 4. 向量运算 (简化版 SIMD)
    // 脚本调用: math.v_add(list1, list2)
    module.set_native_fn("v_add", |a: Vec<f64>, b: Vec<f64>| -> Vec<f64> {
        // 如果长度不等，取最短的
        a.iter().zip(b.iter()).map(|(x, y)| x + y).collect()
    });

    // 脚本调用: math.v_sub(list1, list2)
    module.set_native_fn("v_sub", |a: Vec<f64>, b: Vec<f64>| -> Vec<f64> {
        a.iter().zip(b.iter()).map(|(x, y)| x - y).collect()
    });

    module
}