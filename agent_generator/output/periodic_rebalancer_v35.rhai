let last_rebalance_tick = -10;
let target_stock_ratio_upper = 55;
let target_stock_ratio_lower = 45;

fn on_tick() {
    if !market.trading_enabled {
        return;
    }

    let current_tick = market.tick;
    
    if current_tick - last_rebalance_tick >= 10 {
        last_rebalance_tick = current_tick;
        
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        let stock_value = account.stock * market.price;
        let total_equity = account.total_equity;
        
        if total_equity > 0 {
            let current_stock_ratio = (stock_value * 100) / total_equity;
            
            if current_stock_ratio > target_stock_ratio_upper && market.price > account.avg_cost {
                let target_stock_value = total_equity / 2;
                let excess_stock_value = stock_value - target_stock_value;
                if excess_stock_value > 0 {
                    let shares_to_sell = excess_stock_value / market.price;
                    if shares_to_sell > 0 {
                        orders.submit_limit_sell(market.price, shares_to_sell);
                    }
                }
            } else if current_stock_ratio < target_stock_ratio_lower {
                let target_stock_value = total_equity / 2;
                let deficit_stock_value = target_stock_value - stock_value;
                if deficit_stock_value > 0 {
                    let shares_to_buy = deficit_stock_value / market.price;
                    let max_affordable = account.cash / market.price;
                    let actual_buy = if shares_to_buy < max_affordable { shares_to_buy } else { max_affordable };
                    if actual_buy > 0 {
                        orders.submit_limit_buy(market.price, actual_buy);
                    }
                }
            }
        }
    }
}