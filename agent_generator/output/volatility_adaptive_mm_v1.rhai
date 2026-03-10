let initialized = false;
let panic_threshold = 0;
let fomo_triggered = false;
let base_spread = 3000;
let vol_factor = 400;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(10000, 50000);
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.history_len() >= 10 {
        let old_price = market.history_price(9);
        if old_price > 0 && ((market.price - old_price) * 100) >= (old_price * 2) {
            fomo_triggered = true;
            let buy_amount = clamp_val((account.cash * 80) / (100 * market.price), 1, 1000);
            orders.submit_market_buy(buy_amount);
            return;
        }
    }
    fomo_triggered = false;

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    let mid = market.price;
    if market.std_dev == 0 { return; }

    let vol_component = (vol_factor * market.std_dev) / 1_000_000;
    let spread = base_spread + vol_component;

    let bid_offset = (mid * (1_000_000 - spread)) / 1_000_000;
    let ask_offset = (mid * (1_000_000 + spread)) / 1_000_000;

    let rounded_bid = ((bid_offset + 500_000) / 1_000_000) * 1_000_000;
    let rounded_ask = ((ask_offset + 500_000) / 1_000_000) * 1_000_000;

    let bid_price = clamp_val(rounded_bid, 1_000_000, mid - 1);
    let ask_price = clamp_val(rounded_ask, mid + 1, 100_000_000_000);

    if account.cash >= bid_price {
        let buy_amt = clamp_val((account.cash * 10) / (100 * bid_price), 1, 500);
        orders.submit_limit_buy(bid_price, buy_amt);
    }

    if account.stock > 0 {
        let sell_amt = clamp_val(account.stock, 1, 500);
        orders.submit_limit_sell(ask_price, sell_amt);
    }
}