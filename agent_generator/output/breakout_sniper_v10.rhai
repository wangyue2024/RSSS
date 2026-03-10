let initialized = false;
let fomo_window = 5;
let stop_loss_ticks = 3;
let breakout_shares = 1000;
let last_prices = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        // Initialize price history buffer
        let i = 0;
        while i < fomo_window {
            last_prices.push(market.price);
            i += 1;
        }
    }

    if !market.trading_enabled { return; }

    // Update rolling price window for FOMO detection
    if last_prices.len() >= fomo_window {
        last_prices.remove(0);
    }
    last_prices.push(market.price);

    // Cancel all pending orders each tick
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }

    // FOMO Condition: price jumped >2% in short window
    let fomo_triggered = false;
    if last_prices.len() >= fomo_window {
        let old_price = last_prices[0];
        if old_price > 0 {
            // Check if price increased by >2% (2% = 200/10000)
            let price_change = market.price - old_price;
            if price_change * 10000 > old_price * 200 {
                fomo_triggered = true;
            }
        }
    }

    // FOMO behavior: market buy with 50% of cash
    if fomo_triggered {
        let cash_to_use = account.cash * 50 / 100;
        if cash_to_use > 0 && market.price > 0 {
            let buy_shares = cash_to_use / market.price;
            if buy_shares > 0 {
                orders.submit_market_buy(buy_shares);
            }
        }
        return;
    }

    // Main breakout strategy
    let position = account.stock;
    let avg_cost = account.avg_cost;

    // Stop-loss for existing position
    if position > 0 && avg_cost > 0 {
        // Stop-loss price: avg_cost minus 3 ticks (each tick = 1/10000 of avg_cost)
        let tick_size = avg_cost / 10000;
        let stop_price = avg_cost - tick_size * stop_loss_ticks;
        if market.price <= stop_price {
            orders.submit_market_sell(position);
        } else {
            orders.submit_limit_sell(stop_price, position);
        }
    }

    // Breakout entry: price exceeds 20-tick high
    if position == 0 && market.price > market.high_20 {
        orders.submit_market_buy(breakout_shares);
    }
}