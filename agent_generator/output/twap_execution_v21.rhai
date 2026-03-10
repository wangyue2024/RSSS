let target_position = 50000;
let initialized = false;
let lot_size = 0;
let recent_prices = [];
let tick_counter = 0;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        let total_cap = account.total_equity;
        let max_cap_shares = (total_cap * 5 / 100) / market.price;
        if max_cap_shares > 0 {
            lot_size = rng.rand_int(1, max_cap_shares);
        } else {
            lot_size = 1;
        }
        initialized = true;
    }

    recent_prices.push(market.price);
    if recent_prices.len() > 5 {
        recent_prices.remove(0);
    }

    let decision_tick = market.tick % 50 == 0;
    if !decision_tick {
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if recent_prices.len() < 5 {
        return;
    }

    let delayed_price = recent_prices[0];
    let volatility_threshold = delayed_price * 2 / 100;
    if market.std_dev > volatility_threshold {
        return;
    }

    let current_pos = account.stock;
    if current_pos >= target_position {
        return;
    }

    let remaining = target_position - current_pos;
    let buy_qty = lot_size;
    if buy_qty > remaining {
        buy_qty = remaining;
    }

    if buy_qty > 0 {
        orders.submit_market_buy(buy_qty);
    }
}