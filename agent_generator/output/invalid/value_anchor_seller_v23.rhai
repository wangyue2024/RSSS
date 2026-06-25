let initialized = false;
let fair_value_micros = 0;
let my_resistance_active = true;

fn on_tick() {
    if !initialized {
        initialized = true;
        // Base 100 yuan plus/minus 5 yuan random offset
        let random_offset = rng.rand_int(-5_000_000, 5_000_000);
        fair_value_micros = 100_000_000 + random_offset;
    }

    // Morning person: only active first 20% of session
    if market.tick >= market.total_ticks * 2 / 10 {
        if my_resistance_active {
            my_resistance_active = false;
            // Cancel all pending orders when session period ends
            let count = my_orders.pending_count();
            let i = 0;
            while i < count {
                let oid = my_orders.pending_id(i);
                orders.submit_cancel(oid);
                i += 1;
            }
        }
        return;
    }

    if !market.trading_enabled { return; }

    // Cancel any existing pending orders each tick to adjust
    let pending_cnt = my_orders.pending_count();
    let j = 0;
    while j < pending_cnt {
        let oid = my_orders.pending_id(j);
        orders.submit_cancel(oid);
        j += 1;
    }

    let current_price = market.price;
    let stock_held = account.stock;

    // Only sell, never buy above fair value
    if current_price > fair_value_micros && stock_held > 0 {
        let sell_amount;
        let sell_price;

        // Aggressive selling threshold: > 110% of fair value
        if current_price > fair_value_micros * 110 / 100 {
            // Sell 30% of holdings
            sell_amount = stock_held * 30 / 100;
            if sell_amount == 0 { sell_amount = 1; }
            // Place sell order at current best bid
            sell_price = market.bid_price_0;
            if sell_price == 0 {
                sell_price = current_price * 99 / 100; // Fallback slightly below market
            }
            orders.submit_limit_sell(sell_price, sell_amount);
        }
        // Moderate selling threshold: > 105% of fair value
        else if current_price > fair_value_micros * 105 / 100 {
            // Sell 10% of holdings
            sell_amount = stock_held * 10 / 100;
            if sell_amount == 0 { sell_amount = 1; }
            // Place sell order at current best bid
            sell_price = market.bid_price_0;
            if sell_price == 0 {
                sell_price = current_price * 99 / 100;
            }
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}