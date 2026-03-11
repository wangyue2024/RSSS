let initialized = false;
let rebalance_interval = 10;
let last_rebalance_tick = -999;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Morning person constraint - only first 20% of session
    if market.tick >= market.total_ticks / 5 {
        return;
    }
    
    // Cancel existing orders before rebalancing
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Rebalance every N ticks
    if (market.tick - last_rebalance_tick) >= rebalance_interval {
        last_rebalance_tick = market.tick;
        
        let stock_value = account.stock * market.price;
        let total = account.total_equity;
        
        if total > 0 {
            let stock_percent = (stock_value * 10000) / total;
            
            // Round to nearest dollar (1,000,000 micros)
            let round_price = market.price;
            let remainder = round_price % 1_000_000;
            if remainder >= 500_000 {
                round_price = round_price + (1_000_000 - remainder);
            } else {
                round_price = round_price - remainder;
            }
            
            // Off-by-one pumper: add 1 micro to buy orders
            let buy_price = round_price + 1;
            let sell_price = round_price;
            
            if stock_percent > 5500 {
                // Sell if stock > 55%
                let target_stock_value = (total * 5000) / 10000;
                let excess_value = stock_value - target_stock_value;
                let sell_amount = excess_value / market.price;
                
                if sell_amount > 0 && account.stock >= sell_amount {
                    orders.submit_limit_sell(sell_price, sell_amount);
                }
            } else if stock_percent < 4500 {
                // Buy if stock < 45%
                let target_stock_value = (total * 5000) / 10000;
                let deficit_value = target_stock_value - stock_value;
                let buy_amount = deficit_value / market.price;
                let max_buy = account.cash / buy_price;
                
                if buy_amount > 0 && max_buy > 0 {
                    let actual_buy = buy_amount;
                    if actual_buy > max_buy {
                        actual_buy = max_buy;
                    }
                    orders.submit_limit_buy(buy_price, actual_buy);
                }
            }
        }
    }
}