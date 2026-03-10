let initialized = false;
let lot_size = 0;
let price_buffer = [];
let risk_threshold = 0;

fn on_tick() {
    if !initialized {
        let max_trade = account.total_equity * 5 / 100;
        if max_trade < 1 { max_trade = 1; }
        lot_size = rng.rand_int(1, max_trade);
        risk_threshold = market.price * 5 / 100;
        initialized = true;
    }

    if !market.trading_enabled { return; }

    price_buffer.push(market.price);
    if price_buffer.len() > 5 {
        price_buffer.remove(0);
    }

    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }

    if price_buffer.len() < 5 { return; }

    let old_price = price_buffer[0];
    let price_moved = abs_val(market.price - old_price) > risk_threshold * 2 / 100;

    if market.std_dev > risk_threshold { return; }

    let fat_finger = rng.rand_int(0, 9999) == 0;

    if !fat_finger || !price_moved { return; }

    let side = rng.rand_bool(50);
    let amount = lot_size * 100;

    if side {
        let max_buy = account.cash / market.price;
        if amount > max_buy { amount = max_buy; }
        if amount > 0 {
            orders.submit_market_buy(amount);
        }
    } else {
        if amount > account.stock { amount = account.stock; }
        if amount > 0 {
            orders.submit_market_sell(amount);
        }
    }
}