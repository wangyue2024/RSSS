let initialized = false;
let price_history = [];
let current_tick = 0;
let delayed_price = 0;
let fomo_triggered = false;
let fomo_cooldown = 0;
let spread_bps = 50;
let order_size = 1000;

fn on_tick() {
    if !initialized {
        initialized = true;
        spread_bps = rng.rand_int(30, 80);
        order_size = rng.rand_int(800, 1200);
    }
    
    if !market.trading_enabled { return; }
    
    current_tick = market.tick;
    
    price_history.push(market.price);
    if price_history.len() > 20 {
        price_history.remove(0);
    }
    
    if fomo_triggered {
        fomo_cooldown += 1;
        if fomo_cooldown > 20 {
            fomo_triggered = false;
            fomo_cooldown = 0;
        }
        return;
    }
    
    if price_history.len() >= 10 {
        let recent_high = price_history[price_history.len() - 1];
        let old_price = price_history[price_history.len() - 10];
        if old_price > 0 {
            let price_change_pct = (recent_high - old_price) * 10000 / old_price;
            if price_change_pct > 200 {
                fomo_triggered = true;
                let cancel_count = my_orders.pending_count();
                let i = 0;
                while i < cancel_count {
                    let oid = my_orders.pending_id(i);
                    orders.submit_cancel(oid);
                    i += 1;
                }
                let buy_amount = account.cash / (2 * market.price);
                if buy_amount > 0 {
                    orders.submit_market_buy(buy_amount);
                }
                return;
            }
        }
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if price_history.len() >= 5 {
        delayed_price = price_history[price_history.len() - 5];
        
        let buy_price = delayed_price * (10000 - spread_bps) / 10000;
        let sell_price = delayed_price * (10000 + spread_bps) / 10000;
        
        let max_buy_shares = account.cash / buy_price;
        let buy_shares = if max_buy_shares < order_size { max_buy_shares } else { order_size };
        
        if buy_shares > 0 && buy_price > 0 {
            orders.submit_limit_buy(buy_price, buy_shares);
        }
        
        let sell_shares = if account.stock < order_size { account.stock } else { order_size };
        
        if sell_shares > 0 && sell_price > 0 {
            orders.submit_limit_sell(sell_price, sell_shares);
        }
    }
}