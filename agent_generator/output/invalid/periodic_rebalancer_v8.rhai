let initialized = false;
let price_history = [];
let tick_counter = 0;
let max_trade_fraction = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        max_trade_fraction = rng.rand_int(1, 5);
    }
    
    if !market.trading_enabled { return; }
    
    tick_counter += 1;
    price_history.push(market.price);
    if price_history.len() > 6 {
        price_history.remove(0);
    }
    
    if tick_counter % 10 == 0 {
        if market.std_dev > (market.price * 5 / 100) {
            return;
        }
        
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        if price_history.len() >= 6 {
            let delayed_price = price_history[price_history.len() - 6];
            let equity = account.total_equity;
            let stock_value = account.stock * delayed_price;
            
            let upper_threshold = (equity * 55) / 100;
            let lower_threshold = (equity * 45) / 100;
            
            let max_trade_value = (equity * max_trade_fraction) / 100;
            
            if stock_value > upper_threshold {
                let target_stock_value = (equity * 50) / 100;
                let sell_value = stock_value - target_stock_value;
                if sell_value > max_trade_value {
                    sell_value = max_trade_value;
                }
                let sell_amount = sell_value / delayed_price;
                if sell_amount > 0 {
                    orders.submit_limit_sell(delayed_price, sell_amount);
                }
            } else if stock_value < lower_threshold {
                let target_stock_value = (equity * 50) / 100;
                let buy_value = target_stock_value - stock_value;
                if buy_value > max_trade_value {
                    buy_value = max_trade_value;
                }
                let max_buy_by_cash = account.cash;
                if buy_value > max_buy_by_cash {
                    buy_value = max_buy_by_cash;
                }
                let buy_amount = buy_value / delayed_price;
                if buy_amount > 0 {
                    orders.submit_limit_buy(delayed_price, buy_amount);
                }
            }
        }
    }
}