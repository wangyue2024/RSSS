// ═══════════════════════════════════════════════════
// 做市商策略 (Market Maker)
// 在买卖两侧持续报价, 赚取买卖价差
// 每 Tick: 撤旧单 → 计算新报价 → 双边挂单
// ═══════════════════════════════════════════════════

// 初始化: 每个做市商通过 RNG 产生不同参数
let my_spread = rand_int(rng, 300_000, 1_000_000);  // 价差 0.30 ~ 1.00 元
let my_qty = rand_int(rng, 5, 15);                   // 每侧挂单量

fn on_tick() {
    if !market.trading_enabled { return; }

    // ── 撤销上期所有挂单 ──
    let i = 0;
    while i < my_orders.pending_count() {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }

    // ── 计算报价 ──
    let mid = market.price;
    let half = my_spread / 2;

    // 库存管理: 持仓偏离初始值 (100股) 时偏移报价
    // 持仓多 → 降低买价/抬高卖价 → 倾向卖出减仓
    // 持仓少 → 抬高买价/降低卖价 → 倾向买入补仓
    let inv_skew = (account.stock - 100) * 5_000;  // 每偏1股 → 0.005 元

    let bid = mid - half - inv_skew;
    let ask = mid + half - inv_skew;

    // ── 下单 (附带资金/持仓检查) ──
    if bid > 0 && account.cash > bid * my_qty {
        orders.submit_limit_buy(bid, my_qty);
    }
    if ask > 0 && account.stock >= my_qty {
        orders.submit_limit_sell(ask, my_qty);
    }
}
