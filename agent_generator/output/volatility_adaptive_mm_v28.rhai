let initialized = false;
let lot_size = 0;
let base_spread = 0;
let volatility_threshold = 0;
let lazy_counter = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_capital = account.total_equity * 5 / 100;
        let price_scale = market.price;
        if price_scale > 0 {
            let max_shares = max_capital / price_scale;
            if max_shares > 0 {
                lot_size = rng.rand_int(1, max_shares);
            } else {
                lot_size = 1;
            }
        } else {
            lot_size = 100;
        }
        base_spread = rng.rand_int(10000, 50000);
        volatility_threshold = rng.rand_int(1500000, 3000000);
    }

    if !market.trading_enabled { return; }

    lazy_counter += 1;
    if lazy_counter < 50 {
        return;
    }
    lazy_counter = 0;

    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.std_dev >= volatility_threshold {
        return;
    }

    if lot_size <= 0 || market.price <= 0 {
        return;
    }

    let spread_adjustment = market.std_dev * 3 / 2;
    let half_spread = base_spread + spread_adjustment;
    let bid_price = market.price - half_spread;
    let ask_price = market.price + half_spread;

    if bid_price > 0 {
        orders.submit_limit_buy(bid_price, lot_size);
    }
    orders.submit_limit_sell(ask_price, lot_size);
}