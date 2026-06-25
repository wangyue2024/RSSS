let initialized = false;
let lot_size = 0;
let tick_counter = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        // Risk-seeking: use up to 50% of initial cash for a single trade
        let cash_frac = rng.rand_int(25, 50);
        let lot_value = account.cash * cash_frac / 100;
        lot_size = max(1, lot_value / max(1, market.price));
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel existing orders at rebalance time
    tick_counter += 1;
    if tick_counter % 10 == 0 {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        // Calculate current allocation
        let stock_value = account.stock * market.price;
        let total = account.total_equity;
        let stock_pct = 0;
        if total > 0 {
            stock_pct = (stock_value * 100) / total;
        }
        
        // Rebalance logic
        let price = market.price;
        if price <= 0 { return; }
        
        if stock_pct > 55 {
            // Overweight stock: sell
            let target_value = total * 50 / 100;
            let excess_value = stock_value - target_value;
            let sell_shares = min(lot_size, excess_value / price);
            if sell_shares > 0 && account.stock > 0 {
                // Limit sell near current price
                let sell_price = price - micros(0, 100);
                if sell_price > 0 {
                    orders.submit_limit_sell(sell_price, min(sell_shares, account.stock));
                }
            }
        } else if stock_pct < 45 {
            // Underweight stock: buy
            let target_value = total * 50 / 100;
            let deficit_value = target_value - stock_value;
            let buy_shares = min(lot_size, deficit_value / price);
            if buy_shares > 0 && account.cash > price {
                // Limit buy near current price
                let buy_price = price + micros(0, 100);
                let max_affordable = account.cash / buy_price;
                orders.submit_limit_buy(buy_price, min(buy_shares, max_affordable));
            }
        }
    }
}