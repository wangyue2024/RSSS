let initialized = false;
let price_buffer = [];
let last_trade_tick = -50;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    price_buffer.push(market.price);
    if price_buffer.len() > 5 {
        price_buffer.remove(0);
    }
    
    if price_buffer.len() >= 5 && market.tick - last_trade_tick >= 50 {
        let fomo_window = 5;
        if market.tick >= fomo_window {
            let idx = price_buffer.len() - fomo_window;
            let old_price = price_buffer[idx];
            if old_price > 0 {
                let jump_threshold = old_price * 102 / 100;
                if market.price > jump_threshold {
                    let max_shares = account.cash / market.price;
                    let amount = clamp_val(max_shares, 1, 1000);
                    if amount > 0 {
                        orders.submit_market_buy(amount);
                    }
                    return;
                }
            }
        }
        
        let delayed_price = price_buffer[0];
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        let upper_band = market.ma_20 + 2 * market.std_dev;
        let lower_band = market.ma_20 - 2 * market.std_dev;
        
        let buy_price = lower_band;
        let sell_price = upper_band;
        
        if buy_price > 0 {
            let max_shares = account.cash / buy_price;
            let amount = clamp_val(max_shares, 1, 1000);
            if amount > 0 && delayed_price <= buy_price {
                orders.submit_limit_buy(buy_price, amount);
            }
        }
        
        if account.stock > 0 && sell_price > 0 && delayed_price >= sell_price {
            let amount = clamp_val(account.stock, 1, 1000);
            orders.submit_limit_sell(sell_price, amount);
        }
        
        last_trade_tick = market.tick;
    }
}