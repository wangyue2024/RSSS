let initialized = false;
let last_rebalance_tick = 0;
let panic_threshold = 0;

fn on_tick() {
    if !initialized {
        panic_threshold = -rng.rand_int(1000, 10000);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        orders.submit_market_sell(account.stock);
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_tick = market.tick;
    if current_tick - last_rebalance_tick >= 10 {
        last_rebalance_tick = current_tick;
        
        let equity = account.total_equity;
        let stock_value = account.stock * market.price;
        let stock_ratio = stock_value * 100 / equity;
        
        if stock_ratio > 55 {
            if market.price > account.avg_cost && account.stock > 0 {
                let target_stock_value = equity * 50 / 100;
                let excess_value = stock_value - target_stock_value;
                let amount_to_sell = excess_value / market.price;
                
                if amount_to_sell > 0 {
                    let ask_price = if market.ask_price_0 != 0 { market.ask_price_0 } else { market.price };
                    let sell_price = ask_price - 1;
                    orders.submit_limit_sell(sell_price, amount_to_sell);
                }
            }
        } else if stock_ratio < 45 {
            let target_stock_value = equity * 50 / 100;
            let deficit_value = target_stock_value - stock_value;
            let amount_to_buy = deficit_value / market.price;
            
            if amount_to_buy > 0 && account.cash > amount_to_buy * market.price {
                let bid_price = if market.bid_price_0 != 0 { market.bid_price_0 } else { market.price };
                let buy_price = bid_price + 1;
                orders.submit_limit_buy(buy_price, amount_to_buy);
            }
        }
    }
}