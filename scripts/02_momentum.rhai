// ═══════════════════════════════════════════════════
// 趋势跟随策略 (Momentum / Trend Following)
// MA5 上穿 MA20 → 买入, MA5 下穿 MA20 → 卖出
// 仅在信号翻转时交易, 避免频繁操作
// ═══════════════════════════════════════════════════

let my_size = rand_int(rng, 3, 10);  // 每次交易量
let prev_signal = 0;                  // 上一 Tick 的信号 (1=多, -1=空, 0=无)

fn on_tick() {
    if !market.trading_enabled { return; }
    if market.tick < 25 { return; }  // 等待 MA20 有足够数据

    // ── 判断趋势方向 ──
    let signal = 0;
    if market.ma_5 > market.ma_20 {
        signal = 1;   // 短均线在上 → 上升趋势
    }
    if market.ma_5 < market.ma_20 {
        signal = -1;  // 短均线在下 → 下降趋势
    }

    // ── 信号翻转时交易 ──
    if signal != prev_signal {
        if signal == 1 && account.cash > market.price * my_size {
            // 上穿: 买入 (挂略高于市价的限价单以提高成交率)
            orders.submit_limit_buy(market.price + 50_000, my_size);
        }
        if signal == -1 && account.stock >= my_size {
            // 下穿: 卖出
            orders.submit_limit_sell(market.price - 50_000, my_size);
        }
    }

    prev_signal = signal;
}
