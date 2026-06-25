let initialized = false;
let prev_state = 0; // 0 unknown, 1 ma5 > ma20, -1 ma5 < ma20

fn on_tick() {
    if !market.trading_enabled { return; }

    // Morning Person: only first 20% of session
    if market.tick >= market.total_ticks * 20 / 100 {
        // Cancel any pending orders
        let pending = my_orders.pending_count();
        let i = 0;
        while i < pending {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        // Exit any position
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }

    // Initialize state
    if !initialized {
        initialized = true;
        if market.ma_5 > market.ma_20 {
            prev_state = 1;
        } else if market.ma_5 < market.ma_20 {
            prev_state = -1;
        }
    }

    // Cancel all pending orders each tick for simplicity
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let current_state = 0;
    if market.ma_5 > market.ma_20 {
        current_state = 1;
    } else if market.ma_5 < market.ma_20 {
        current_state = -1;
    }

    // Check for crossover
    if current_state != prev_state {
        if prev_state <= 0 && current_state == 1 {
            // MA5 crossed above MA20: buy with all cash
            let buy_amount = account.cash / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        } else if prev_state >= 0 && current_state == -1 {
            // MA5 crossed below MA20: sell all stock
            if account.stock > 0 {
                orders.submit_market_sell(account.stock);
            }
        }
        prev_state = current_state;
    }
}