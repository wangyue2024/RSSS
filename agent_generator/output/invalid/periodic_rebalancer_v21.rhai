// Global variables
let rebalance_counter = 0;
let last_rebalance_tick = -10;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    // Morning Person: Only trade during first 20% of session
    if market.tick * 5 >= market.total_ticks {
        // Cancel any existing orders if we're past the allowed period
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    // Check if it's time to rebalance (every 10 ticks)
    if market.tick - last_rebalance_tick >= 10 {
        last_rebalance_tick = market.tick;
        
        // Cancel existing orders before placing new ones
        let pending_cnt = my_orders.pending_count();
        let j = 0;
        while j < pending_cnt {
            let oid = my_orders.pending_id(j);
            orders.submit_cancel(oid);
            j += 1;
        }
        
        // Calculate current allocation
        let stock_value = account.stock * market.price;
        let total_eq = account.total_equity;
        
        // Avoid division by zero
        if total_eq == 0 { return; }
        
        // Calculate stock percentage in basis points (10000 = 100%)
        let stock_pct = (stock_value * 10000) / total_eq;
        
        // Target is 50% (5000 basis points)
        let target_pct = 5000;
        
        // Tolerance bands: 45% to 55%
        if stock_pct > 5500 {
            // Overweight in stock - sell some
            let target_stock_value = (total_eq * target_pct) / 10000;
            let excess_value = stock_value - target_stock_value;
            
            if excess_value > 0 && market.price > 0 {
                let shares_to_sell = excess_value / market.price;
                if shares_to_sell > 0 && shares_to_sell <= account.stock {
                    // Place limit sell order near current price (at bid)
                    let sell_price = if market.bid_price_0 > 0 {
                        market.bid_price_0
                    } else {
                        market.price - 10_000  // 1 cent below if no bid
                    };
                    if sell_price > 0 {
                        orders.submit_limit_sell(sell_price, shares_to_sell);
                    }
                }
            }
        } else if stock_pct < 4500 {
            // Underweight in stock - buy some
            let target_stock_value = (total_eq * target_pct) / 10000;
            let deficit_value = target_stock_value - stock_value;
            
            if deficit_value > 0 && market.price > 0 {
                let shares_to_buy = deficit_value / market.price;
                let max_affordable = account.cash / market.price;
                let actual_buy = if shares_to_buy < max_affordable { shares_to_buy } else { max_affordable };
                
                if actual_buy > 0 {
                    // Place limit buy order near current price (at ask)
                    let buy_price = if market.ask_price_0 > 0 {
                        market.ask_price_0
                    } else {
                        market.price + 10_000  // 1 cent above if no ask
                    };
                    if buy_price > 0 && account.cash >= buy_price * actual_buy {
                        orders.submit_limit_buy(buy_price, actual_buy);
                    }
                }
            }
        }
    }
}