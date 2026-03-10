let initialized = false;
let trade_active = false;
let base_amount = 100;
let threshold_scaler = 150;

fn on_tick() {
    if !initialized {
        initialized = true;
        if rng.rand_bool(50) {
            base_amount = 150;
        }
        threshold_scaler = rng.rand_int(125, 175);
    }

    if !market.trading_enabled {
        return;
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    trade_active = market.tick * 5 < market.total_ticks;

    if !trade_active {
        return;
    }

    let atr = market.atr_14;
    if atr <= 0 {
        return;
    }

    let deviation = abs_val(market.price - market.ma_20);
    let threshold = atr * threshold_scaler / 100;

    if deviation > threshold {
        if market.price > market.ma_20 {
            let sell_price = market.price - atr * 75 / 100;
            if sell_price > market.bid_price_0 && sell_price > 0 {
                let amount = clamp_val(base_amount, 1, account.stock);
                if amount > 0 {
                    orders.submit_limit_sell(sell_price, amount);
                }
            }
        } else {
            let buy_price = market.price + atr * 75 / 100;
            if buy_price < market.ask_price_0 && buy_price > 0 {
                let max_shares = account.cash / buy_price;
                let amount = clamp_val(base_amount, 1, max_shares);
                if amount > 0 {
                    orders.submit_limit_buy(buy_price, amount);
                }
            }
        }
    }
}