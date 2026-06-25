let tick_counter = 0;
let last_rebalance_tick = -10;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders each tick
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    tick_counter += 1;
    
    // Only rebalance every 10 ticks
    if tick_counter - last_rebalance_tick < 10 { return; }
    
    let equity = account.total_equity;
    // Guard against division by zero
    if equity == 0 { return; }
    
    let stock_value = account.stock * market.price;
    let stock_percent = (stock_value * 100) / equity;
    
    // Rebalance thresholds: 45% to 55%
    if stock_percent > 55 {
        // Stock percentage too high - sell some
        if market.price > account.avg_cost {  // Diamond hands: only sell at profit
            let target_stock_value = equity / 2;  // 50% target
            let excess_stock_value = stock_value - target_stock_value;
            // Calculate shares to sell (avoid division by zero)
            if market.price > 0 {
                let shares_to_sell = excess_stock_value / market.price;
                if shares_to_sell > 0 {
                    // Sell at 1% above current price
                    let sell_price = market.price * 101 / 100;
                    orders.submit_limit_sell(sell_price, shares_to_sell);
                }
            }
        }
    } else if stock_percent < 45 {
        // Stock percentage too low - buy some
        let target_stock_value = equity / 2;  // 50% target
        let deficit_stock_value = target_stock_value - stock_value;
        // Calculate shares to buy (avoid division by zero)
        if market.price > 0 {
            let shares_to_buy = deficit_stock_value / market.price;
            if shares_to_buy > 0 {
                // Buy at 1% below current price
                let buy_price = market.price * 99 / 100;
                orders.submit_limit_buy(buy_price, shares_to_buy);
            }
        }
    }
    
    last_rebalance_tick = tick_counter;
}