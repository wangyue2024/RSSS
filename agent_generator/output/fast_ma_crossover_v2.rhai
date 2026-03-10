let initialized = false;
let prev_fast_above_slow = false;
let lot_size_shares = 0;
let risk_pct = 0;

fn on_tick() {
    if !initialized {
        risk_pct = rng.rand_int(40, 50);
        initialized = true;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let fast = market.ma_5;
    let slow = market.ma_20;
    let current_fast_above_slow = fast > slow;

    if current_fast_above_slow && !prev_fast_above_slow {
        let cash_available = account.cash;
        let price_now = market.price;
        if price_now > 0 && cash_available > 0 {
            let cash_to_use = cash_available * risk_pct / 100;
            lot_size_shares = cash_to_use / price_now;
            if lot_size_shares > 0 {
                orders.submit_market_buy(lot_size_shares);
            }
        }
    }

    if !current_fast_above_slow && prev_fast_above_slow {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
    }

    prev_fast_above_slow = current_fast_above_slow;
}