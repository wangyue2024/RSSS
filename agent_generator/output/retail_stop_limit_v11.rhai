let entered = false;
let entry_price = 0;
let take_profit_order_id = 0;

fn round_to_dollar(price) {
    let dollar = 1_000_000;
    return ((price + dollar / 2) / dollar) * dollar;
}

fn on_tick() {
    if !market.trading_enabled { return; }

    // Cancel existing pending take-profit order if we are not entered (safety)
    if !entered {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
    }

    // Random entry once
    if !entered && account.stock == 0 {
        if rng.rand_bool(1) { // 1% chance per tick
            let buy_amount = 100;
            orders.submit_market_buy(buy_amount);
            entry_price = market.price;
            
            // Calculate take-profit price (5% above, rounded to nearest dollar)
            let tp_raw = entry_price * 105 / 100;
            let tp_price = round_to_dollar(tp_raw);
            
            // Submit take-profit limit sell
            take_profit_order_id = orders.submit_limit_sell(tp_price, buy_amount);
            entered = true;
        }
        return;
    }

    // If we have a position, monitor for stop-loss (2% below)
    if entered && account.stock > 0 {
        let stop_price = entry_price * 98 / 100;
        
        // Stop-loss triggered: market sell
        if market.price <= stop_price {
            orders.submit_market_sell(account.stock);
            // Cancel the take-profit order
            orders.submit_cancel(take_profit_order_id);
            entered = false;
        }
    }
}