//! 技术指标增量计算引擎
//!
//! 维护滑动窗口与增量累加器，每 Tick O(1) 更新。

use std::collections::VecDeque;

/// 指标计算引擎
pub struct IndicatorEngine {
    window: usize,
    pub prices: VecDeque<i64>,
    pub volumes: VecDeque<i64>,

    // 增量 MA 累加器
    sum_5: i64,
    sum_20: i64,
    sum_60: i64,

    // VWAP
    vwap_numer: i128,                    // Σ(price × volume)
    vwap_denom: i64,                     // Σ(volume)
    vwap_history: VecDeque<(i128, i64)>, // (numer, denom) per tick

    // RSI 指数移动平均
    avg_gain_14: i64, // ×10000 精度
    avg_loss_14: i64,
    rsi_count: i64,

    // ATR
    atr_14_sum: i64,
    atr_count: i64,

    // 缓存
    last_price: i64,
}

impl IndicatorEngine {
    pub fn new(initial_price: i64, window: usize) -> Self {
        Self {
            window,
            prices: VecDeque::with_capacity(window + 1),
            volumes: VecDeque::with_capacity(window + 1),
            sum_5: 0,
            sum_20: 0,
            sum_60: 0,
            vwap_numer: 0,
            vwap_denom: 0,
            avg_gain_14: 0,
            avg_loss_14: 0,
            rsi_count: 0,
            atr_14_sum: 0,
            atr_count: 0,
            last_price: initial_price,
            vwap_history: VecDeque::with_capacity(window + 1),
        }
    }

    /// 推入新的 Tick 数据
    pub fn push(&mut self, price: i64, volume: i64) {
        // 用 prices 队列末尾作为前值（上一次 push 的价格），
        // 而非 self.last_price（会被 Trade 事件中途更新导致 change=0）
        let prev = self.prices.back().copied().unwrap_or(self.last_price);

        // 更新 MA 累加器
        self.sum_5 += price;
        self.sum_20 += price;
        self.sum_60 += price;

        if self.prices.len() >= 5 {
            self.sum_5 -= self.prices[self.prices.len() - 5];
        }
        if self.prices.len() >= 20 {
            self.sum_20 -= self.prices[self.prices.len() - 20];
        }
        if self.prices.len() >= 60 {
            self.sum_60 -= self.prices[self.prices.len() - 60];
        }

        // VWAP 累加
        let n = price as i128 * volume as i128;
        let d = volume;
        if volume > 0 {
            self.vwap_numer += n;
            self.vwap_denom += d;
        }
        self.vwap_history.push_back((n, d));

        // RSI: 增量移动平均
        let change = price - prev;
        let gain = if change > 0 { change } else { 0 };
        let loss = if change < 0 { -change } else { 0 };

        if self.rsi_count < 14 {
            self.avg_gain_14 += gain;
            self.avg_loss_14 += loss;
            self.rsi_count += 1;
            if self.rsi_count == 14 {
                // 初始化: 简单均值
                self.avg_gain_14 /= 14;
                self.avg_loss_14 /= 14;
            }
        } else {
            // 指数移动平均: avg = (prev * 13 + new) / 14
            self.avg_gain_14 = (self.avg_gain_14 * 13 + gain) / 14;
            self.avg_loss_14 = (self.avg_loss_14 * 13 + loss) / 14;
        }

        // ATR: |high - low| 近似为 |price - prev|
        let tr = (price - prev).abs();
        if self.atr_count < 14 {
            self.atr_14_sum += tr;
            self.atr_count += 1;
        } else {
            self.atr_14_sum = (self.atr_14_sum * 13 + tr) / 14;
        }

        // 推入窗口
        self.prices.push_back(price);
        self.volumes.push_back(volume);
        self.last_price = price;

        // 限制窗口大小
        while self.prices.len() > self.window {
            self.prices.pop_front();
        }
        while self.volumes.len() > self.window {
            self.volumes.pop_front();
        }
        while self.vwap_history.len() > self.window {
            if let Some((n, d)) = self.vwap_history.pop_front() {
                self.vwap_numer -= n;
                self.vwap_denom -= d;
            }
        }
    }

    // ========================================================================
    // Getter 函数
    // ========================================================================

    pub fn last_price(&self) -> i64 {
        self.last_price
    }

    /// 设置最新价格 (Trade 发生时由 World 调用)
    pub fn set_last_price(&mut self, price: i64) {
        self.last_price = price;
    }

    pub fn ma_5(&self) -> i64 {
        let n = self.prices.len().min(5) as i64;
        if n == 0 {
            self.last_price
        } else {
            self.sum_5 / n
        }
    }

    pub fn ma_20(&self) -> i64 {
        let n = self.prices.len().min(20) as i64;
        if n == 0 {
            self.last_price
        } else {
            self.sum_20 / n
        }
    }

    pub fn ma_60(&self) -> i64 {
        let n = self.prices.len().min(60) as i64;
        if n == 0 {
            self.last_price
        } else {
            self.sum_60 / n
        }
    }

    pub fn high_20(&self) -> i64 {
        let start = if self.prices.len() > 20 {
            self.prices.len() - 20
        } else {
            0
        };
        self.prices
            .iter()
            .skip(start)
            .copied()
            .max()
            .unwrap_or(self.last_price)
    }

    pub fn low_20(&self) -> i64 {
        let start = if self.prices.len() > 20 {
            self.prices.len() - 20
        } else {
            0
        };
        self.prices
            .iter()
            .skip(start)
            .copied()
            .min()
            .unwrap_or(self.last_price)
    }

    pub fn vwap(&self) -> i64 {
        if self.vwap_denom == 0 {
            self.last_price
        } else {
            (self.vwap_numer / self.vwap_denom as i128) as i64
        }
    }

    pub fn std_dev(&self) -> i64 {
        let n = self.prices.len().min(20) as i64;
        if n <= 1 {
            return 0;
        }
        let start = if self.prices.len() > 20 {
            self.prices.len() - 20
        } else {
            0
        };
        let mean = self.ma_20();
        let variance = self
            .prices
            .iter()
            .skip(start)
            .map(|&p| {
                let d = (p - mean) as i128;
                d * d
            })
            .sum::<i128>()
            / n as i128;

        // Newton's 整数 sqrt
        if variance <= 0 {
            return 0;
        }
        let mut x = (variance as f64).sqrt() as i64;
        if x == 0 {
            x = 1;
        }
        loop {
            let nx = (x as i128 + variance / x as i128) / 2;
            if nx >= x as i128 {
                break;
            }
            x = nx as i64;
        }
        x
    }

    pub fn atr_14(&self) -> i64 {
        if self.atr_count == 0 {
            0
        } else if self.atr_count < 14 {
            self.atr_14_sum / self.atr_count
        } else {
            self.atr_14_sum
        }
    }

    /// RSI × 100 → [0, 10000]
    pub fn rsi_14(&self) -> i64 {
        if self.rsi_count < 14 {
            return 5000; // 中性值
        }
        let total = self.avg_gain_14 + self.avg_loss_14;
        if total == 0 {
            return 5000;
        }
        (self.avg_gain_14 as i128 * 10000 / total as i128) as i64
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ma_basic() {
        let mut ind = IndicatorEngine::new(100_000_000, 256);
        for i in 0..5 {
            ind.push(100_000_000 + i * 1_000_000, 100);
        }
        // prices: 100, 101, 102, 103, 104
        // MA5 = (100+101+102+103+104)/5 = 102
        assert_eq!(ind.ma_5(), 102_000_000);
    }

    #[test]
    fn test_high_low() {
        let mut ind = IndicatorEngine::new(100_000_000, 256);
        ind.push(100_000_000, 100);
        ind.push(105_000_000, 100);
        ind.push(95_000_000, 100);
        ind.push(100_000_000, 100);
        assert_eq!(ind.high_20(), 105_000_000);
        assert_eq!(ind.low_20(), 95_000_000);
    }

    #[test]
    fn test_vwap() {
        let mut ind = IndicatorEngine::new(100_000_000, 256);
        // VWAP = Σ(p*v) / Σv = (100*50 + 102*150) / 200 = (5000+15300)/200 = 101.5
        ind.push(100_000_000, 50);
        ind.push(102_000_000, 150);
        assert_eq!(ind.vwap(), 101_500_000);
    }
}
