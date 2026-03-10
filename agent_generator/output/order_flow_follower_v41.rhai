let initialized = false;
let lot_size = 0;
let std_dev_threshold = 5_000_000; // 5 dollars in micros

fn on_tick() {
    if !initialized {
        initialized = true;
        // Initialize lot_size to less than 5% of total capital
        let five_percent_capital = account.total_equity * 5 / 100;
        if market.price > 0 {
            let max_shares = five_percent_capital / market.price;
            if max_shares > 0 {
                lot_size = rng.rand_int(1, max_shares);
            } else {
                lot_size = 0;
            }
        }
    }

    if !market.trading_enabled { return; }

    // Cancel any pending orders first
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    // Risk-averse: refuse to trade if standard deviation is high
    if market.std_dev > std_dev_threshold { return; }

    // Order flow logic
    if market.buy_volume > 3 * market.sell_volume {
        // Join buying crowd
        let cost_estimate = market.ask_price_0 * lot_size;
        if account.cash >= cost_estimate && lot_size > 0 {
            orders.submit_market_buy(lot_size);
        }
    }
}