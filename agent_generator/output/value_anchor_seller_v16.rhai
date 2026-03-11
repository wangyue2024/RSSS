let initialized = false;
let fair_value = 0;
let panic_threshold = 0;

fn round_to_nearest_yuan(price_micros) {
    let remainder = price_micros % 1_000_000;
    if remainder >= 500_000 {
        price_micros - remainder + 1_000_000
    } else {
        price_micros - remainder
    }
}

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = 100_000_000 + rng.rand_int(-5_000_000, 5_000_000);
        panic_threshold = -rng.rand_int(500_000, 5_000_000);
    }

    if !market.trading_enabled { return; }

    // Panic stop-loss check (every tick)
    if account.unrealized_pnl < panic_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }

    // Lazy trader: only act every 50 ticks
    if market.tick % 50 != 0 { return; }

    // Cancel all pending orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }

    let current_price = market.price;
    let sell_amount;

    if current_price > fair_value * 110 / 100 && account.stock > 0 {
        // Aggressive selling
        sell_amount = (account.stock * 30) / 100;
        if sell_amount == 0 { sell_amount = 1; }
        let rounded_price = round_to_nearest_yuan(current_price);
        orders.submit_limit_sell(rounded_price, sell_amount);
    } else if current_price > fair_value * 105 / 100 && account.stock > 0 {
        // Small selling
        sell_amount = (account.stock * 10) / 100;
        if sell_amount == 0 { sell_amount = 1; }
        let rounded_price = round_to_nearest_yuan(current_price);
        orders.submit_limit_sell(rounded_price, sell_amount);
    }
}