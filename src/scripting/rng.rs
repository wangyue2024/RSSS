//! 确定性随机数生成器 (AgentRng)
//!
//! 每个 Agent 持有独立的 RNG，种子由 `global_seed + agent_id` 派生。
//! 并行执行时各 Agent 序列互不干扰 → 比特级可复现。

use rand::Rng;
use rand::SeedableRng;
use rand_xoshiro::Xoshiro256PlusPlus;

/// Agent 专属确定性随机数生成器
///
/// 包装 `Xoshiro256PlusPlus`（32 字节状态），注册为 Rhai CustomType。
/// 跨 Tick 保留在 Scope 中，序列持续推进。
#[derive(Clone, Debug)]
pub struct AgentRng {
    inner: Xoshiro256PlusPlus,
}

impl AgentRng {
    /// 从全局种子和 Agent ID 派生确定性种子
    pub fn new(global_seed: u64, agent_id: u32) -> Self {
        // LCG 派生，保证不同 agent_id 产生不同种子
        let agent_seed = global_seed
            .wrapping_mul(6_364_136_223_846_793_005)
            .wrapping_add(agent_id as u64);
        Self {
            inner: Xoshiro256PlusPlus::seed_from_u64(agent_seed),
        }
    }

    /// 生成 [lo, hi] 范围内的均匀分布随机整数
    ///
    /// Rhai 注册为: `rand_int(rng, lo, hi) -> i64`
    pub fn rand_int(&mut self, lo: i64, hi: i64) -> i64 {
        if lo >= hi {
            return lo;
        }
        self.inner.gen_range(lo..=hi)
    }

    /// 以 pct% 的概率返回 true
    ///
    /// Rhai 注册为: `rand_bool(rng, pct) -> bool`
    /// pct 取值 0-100, pct=30 即 30% 概率
    pub fn rand_bool(&mut self, pct: i64) -> bool {
        if pct <= 0 {
            return false;
        }
        if pct >= 100 {
            return true;
        }
        self.inner.gen_range(0..100) < pct
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_determinism() {
        let mut rng1 = AgentRng::new(12345, 0);
        let mut rng2 = AgentRng::new(12345, 0);

        let seq1: Vec<i64> = (0..100).map(|_| rng1.rand_int(0, 1000)).collect();
        let seq2: Vec<i64> = (0..100).map(|_| rng2.rand_int(0, 1000)).collect();
        assert_eq!(seq1, seq2);
    }

    #[test]
    fn test_different_agents_different_sequences() {
        let mut rng0 = AgentRng::new(12345, 0);
        let mut rng1 = AgentRng::new(12345, 1);

        let seq0: Vec<i64> = (0..20).map(|_| rng0.rand_int(0, 1000)).collect();
        let seq1: Vec<i64> = (0..20).map(|_| rng1.rand_int(0, 1000)).collect();
        assert_ne!(seq0, seq1);
    }

    #[test]
    fn test_rand_bool_edges() {
        let mut rng = AgentRng::new(42, 0);
        assert!(!rng.rand_bool(0));
        assert!(rng.rand_bool(100));
    }

    #[test]
    fn test_rand_int_same_bounds() {
        let mut rng = AgentRng::new(42, 0);
        assert_eq!(rng.rand_int(5, 5), 5);
    }
}
