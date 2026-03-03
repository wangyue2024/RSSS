//! 价格档位队列 (Level Queue)
//!
//! 每个价格档位维护一个 FIFO 队列和缓存的总挂单量。
//! `total_volume` 保证 L2 Snapshot 的 O(1) 读取。
//!
//! **关键设计**：`raw_pop_front` 不自动扣减 `total_volume`，
//! 因为影子撤单时已扣减过，幽灵订单被弹出时不应再次扣减。

use std::collections::VecDeque;

use crate::domain::{Order, Vol};

/// 价格档位队列
///
/// 包含该档位的所有挂单（FIFO 顺序）和缓存的总挂单量。
#[derive(Debug, Clone)]
pub struct LevelQueue {
    /// 缓存的总挂单量，L2 读取时直接返回此值
    pub total_volume: Vol,
    /// FIFO 队列，保证同价位时间优先 (Time-Priority)
    pub orders: VecDeque<Order>,
}

impl LevelQueue {
    /// 创建空队列
    pub fn new() -> Self {
        Self {
            total_volume: Vol::ZERO,
            orders: VecDeque::new(),
        }
    }

    /// 新订单排队 (加入队尾)
    ///
    /// 同时更新 `total_volume`。
    #[inline]
    pub fn push_back(&mut self, order: Order) {
        self.total_volume += order.amount;
        self.orders.push_back(order);
    }

    /// 原始弹出 (从队头取出)
    ///
    /// **不**自动扣减 `total_volume`。
    /// 调用方需根据订单是否为幽灵来决定是否调用 `deduct_volume`。
    ///
    /// 原因：影子撤单时已扣减过 `total_volume`，
    /// 若此处再扣则会导致双重扣减。
    #[inline]
    pub fn raw_pop_front(&mut self) -> Option<Order> {
        self.orders.pop_front()
    }

    /// 扣减有效订单量 (与 `raw_pop_front` 配合使用)
    ///
    /// 仅当弹出的订单是有效订单（非幽灵）时调用。
    #[inline]
    pub fn deduct_volume(&mut self, vol: Vol) {
        self.total_volume -= vol;
    }

    /// 将部分成交的 Maker 订单放回队头
    ///
    /// 注意：放回前 `total_volume` 中该订单的量已被 `deduct_volume` 扣掉，
    /// 这里会加回 Maker 的剩余量。
    #[inline]
    pub fn push_front(&mut self, order: Order) {
        self.total_volume += order.amount;
        self.orders.push_front(order);
    }

    /// 队列中是否还有实体订单 (含幽灵)
    #[inline]
    pub fn is_empty(&self) -> bool {
        self.orders.is_empty()
    }

    /// 队列中的实体订单数 (含幽灵)
    #[inline]
    pub fn len(&self) -> usize {
        self.orders.len()
    }
}

impl Default for LevelQueue {
    fn default() -> Self {
        Self::new()
    }
}
