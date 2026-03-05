// ═══════════════════════════════════════════════════
// 均值回归策略 (Mean Reversion)
// 价格偏离 MA20 超过阈值 → 反向交易
// 低于均值买入, 高于均值卖出
// ═══════════════════════════════════════════════════

let my_threshold = rand_int(rng, 500_000, 2_000_000);  // 触发阈值 0.50 ~ 2.00 元
let my_size = rand_int(rng, 2, 8);                      // 交易量

fn on_tick() {
    if !market.trading_enabled { return; }
    if market.tick < 25 { return; }

    let deviation = market.price - market.ma_20;

    if deviation < -my_threshold {
        // ── 价格低于均值过多 → 买入 (预期回归) ──
        if account.cash > market.price * my_size {
            orders.submit_limit_buy(market.price, my_size);
        }
    }

    if deviation > my_threshold {
        // ── 价格高于均值过多 → 卖出 (预期回归) ──
        if account.stock >= my_size {
            orders.submit_limit_sell(market.price, my_size);
        }
    }
}
