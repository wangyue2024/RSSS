let state = 0;
let position_size = 0;
let entry_price = 0;
let take_profit_order_id = 0;
let stop_loss_price = 0;

fn on_tick() {
    if !market.trading_enabled {
        return;
    }

    // Cancel any existing pending orders (clean slate each tick)
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if state == 0 {
        // No position yet, randomly decide to enter with large lot
        if rng.rand_bool(1) && account.stock == 0 {
            // Risk-seeking: bet up to 50% of cash
            let max_cash_to_use = account.cash * 50 / 100;
            let amount_shares = max_cash_to_use / market.price;
            
            // Ensure we buy at least 1 share if we have enough cash
            if amount_shares > 0 {
                orders.submit_market_buy(amount_shares);
                // Store intended position size for setting orders next tick
                position_size = amount_shares;
                state = 1; // Waiting for fill
            }
        }
    } else if state == 1 {
        // Check if our market buy filled
        if account.stock >= position_size {
            entry_price = account.avg_cost;
            // Set take profit at 5% above entry
            let tp_price = entry_price * 105 / 100;
            // Set stop loss at 2% below entry
            stop_loss_price = entry_price * 98 / 100;
            
            // Place take-profit limit order
            orders.submit_limit_sell(tp_price, position_size);
            state = 2; // Active position with TP order
        } else {
            // Fill didn't happen yet, keep waiting
            position_size = account.stock; // Adjust to whatever partially filled
        }
    } else if state == 2 {
        // We have active position with TP order
        // Check if stop loss triggered (market price <= stop price)
        if market.price <= stop_loss_price {
            // Execute stop-loss market sell
            orders.submit_market_sell(account.stock);
            state = 0;
            position_size = 0;
        }
        // If TP order filled, account.stock will be 0 next tick, resetting state
        if account.stock == 0 {
            state = 0;
            position_size = 0;
        }
    }
}