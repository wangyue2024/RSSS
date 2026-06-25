let initialized = false;
let risk_bp = 0;
let cooldown_ticks = 0;
let last_trade_tick = -10000;
let lot_multiplier = 0;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        initialized = true;
        risk_bp = rng.rand_int(4000, 6000);
        cooldown_ticks = rng.rand_int(5, 15);
        lot_multiplier = rng.rand_int(1, 3);
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.tick - last_trade_tick < cooldown_ticks { return; }

    let price = market.price;
    let ma20 = market.ma_20;
    let atr14 = market.atr_14;
    let cash = account.cash;

    if atr14 == 0 || ma20 == 0 { return; }

    let deviation = price - ma20;
    let abs_dev = abs_val(deviation);
    let threshold = 3 * atr14 / 2;

    if abs_dev <= threshold { return; }

    let trade_cash = cash * risk_bp / 10000;
    let base_shares = trade_cash / price;
    let shares = base_shares * lot_multiplier;

    if shares <= 0 { return; }

    if deviation > 0 {
        if account.stock > 0 {
            let sell_qty = if shares > account.stock { account.stock } else { shares };
            if sell_qty > 0 {
                orders.submit_market_sell(sell_qty);
                last_trade_tick = market.tick;
            }
        }
    } else {
        if trade_cash > 0 {
            orders.submit_market_buy(shares);
            last_trade_tick = market.tick;
        }
    }
}