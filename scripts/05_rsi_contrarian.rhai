// ═══════════════════════════════════════════════════
// RSI 逆势策略 (RSI Contrarian)
// RSI 超卖 (< 30) → 买入, RSI 超买 (> 70) → 卖出
// rsi_14 范围 [0, 10000], 5000 = 中性
// ═══════════════════════════════════════════════════

let my_oversold = rand_int(rng, 2500, 3500);    // 超卖线 25~35 (×100)
let my_overbought = rand_int(rng, 6500, 7500);  // 超买线 65~75 (×100)
let my_size = rand_int(rng, 2, 8);               // 交易量

fn on_tick() {
    if !market.trading_enabled { return; }
    if market.tick < 20 { return; }  // 等待 RSI 收敛

    let rsi = market.rsi_14;

    // ── 超卖 → 买入 ──
    if rsi < my_oversold {
        if account.cash > market.price * my_size {
            // 挂略高于市价的限价单
            orders.submit_limit_buy(market.price + 50_000, my_size);
        }
    }

    // ── 超买 → 卖出 ──
    if rsi > my_overbought {
        if account.stock >= my_size {
            orders.submit_limit_sell(market.price - 50_000, my_size);
        }
    }
}
