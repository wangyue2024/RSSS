let initialized = false;
let panic_threshold = 0;
let entered_position = false;
let entry_price = 0;
let take_profit_order_id = -1;
let last_evaluation_tick = -50;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        initialized = true;
        // 1-5% negative PNL threshold for panic selling
        panic_threshold = -1 * rng.rand_int(10_000_000, 50_000_000); // -$10 to -$50
    }

    // Morning Person: Only trade in first 20% of session
    if market.tick >= market.total_ticks / 5 {
        return;
    }

    // Lazy Trader: Only evaluate every 50 ticks
    if market.tick - last_evaluation_tick < 50 {
        // But still check for panic on every tick (panic-prone)
        if entered_position && account.unrealized_pnl < panic_threshold {
            // PANIC SELL EVERYTHING
            let stock_amt = account.stock;
            if stock_amt > 0 {
                orders.submit_market_sell(stock_amt);
            }
            // Cancel take-profit order if exists
            if take_profit_order_id != -1 {
                orders.submit_cancel(take_profit_order_id);
                take_profit_order_id = -1;
            }
            entered_position = false;
        }
        return;
    }
    last_evaluation_tick = market.tick;

    // Cancel any old take-profit order if position is gone
    if !entered_position && take_profit_order_id != -1 {
        orders.submit_cancel(take_profit_order_id);
        take_profit_order_id = -1;
    }

    // Panic check (also in lazy evaluation cycle)
    if entered_position && account.unrealized_pnl < panic_threshold {
        let stock_amt = account.stock;
        if stock_amt > 0 {
            orders.submit_market_sell(stock_amt);
        }
        if take_profit_order_id != -1 {
            orders.submit_cancel(take_profit_order_id);
            take_profit_order_id = -1;
        }
        entered_position = false;
        return;
    }

    // ENTRY LOGIC: Random entry once
    if !entered_position && account.stock == 0 {
        // 2% chance to enter on evaluation tick
        if rng.rand_bool(2) {
            // Buy with 50% of cash
            let max_afford = account.cash / market.price;
            let buy_amt = max_afford / 2;
            if buy_amt > 0 {
                orders.submit_market_buy(buy_amt);
                // We assume fill happens this tick for simplicity
                // In real scenario, we'd track pending order
                entry_price = market.price;
                entered_position = true;
            }
        }
    }

    // POSITION MANAGEMENT: Place take-profit/stop-loss after entry
    if entered_position && account.stock > 0 && take_profit_order_id == -1 {
        // Place take-profit limit order 5% above entry
        let tp_price = entry_price * 105 / 100;
        let tp_order = orders.submit_limit_sell(tp_price, account.stock);
        take_profit_order_id = tp_order;

        // Stop-loss is monitored, not an order
        let stop_price = entry_price * 98 / 100;
        if market.price <= stop_price {
            // Stop-loss hit: market sell
            orders.submit_market_sell(account.stock);
            orders.submit_cancel(take_profit_order_id);
            take_profit_order_id = -1;
            entered_position = false;
        }
    } else if entered_position && account.stock > 0 {
        // Check stop-loss on each evaluation tick
        let stop_price = entry_price * 98 / 100;
        if market.price <= stop_price {
            orders.submit_market_sell(account.stock);
            orders.submit_cancel(take_profit_order_id);
            take_profit_order_id = -1;
            entered_position = false;
        }
    }
}