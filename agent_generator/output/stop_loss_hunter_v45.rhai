let initialized = false;
let price_history = [];
let fomo_active = false;
let fomo_ticks = 0;
let last_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        last_price = market.price;
    }
    
    if !market.trading_enabled { return; }
    
    let current_price = market.price;
    
    if price_history.len() >= 5 {
        price_history.remove(0);
    }
    price_history.push(current_price);
    
    if !fomo_active {
        let old_price = if price_history.len() >= 5 { price_history[0] } else { last_price };
        if old_price > 0 && current_price > old_price {
            let price_jump_pct = (current_price - old_price) * 10000 / old_price;
            if price_jump_pct > 200 {
                fomo_active = true;
                fomo_ticks = 0;
            }
        }
    }
    
    if fomo_active {
        fomo_ticks += 1;
        if fomo_ticks > 10 {
            fomo_active = false;
        }
        
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        let buy_amount = (account.cash * 50 / 100) / market.price;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
        
        last_price = current_price;
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let cluster_threshold = market.price * 98 / 100;
    let cluster_volume = 0;
    
    if market.bid_price_0 > 0 && market.bid_price_0 <= cluster_threshold {
        cluster_volume += market.bid_vol_0;
    }
    if market.bid_price_1 > 0 && market.bid_price_1 <= cluster_threshold {
        cluster_volume += market.bid_vol_1;
    }
    if market.bid_price_2 > 0 && market.bid_price_2 <= cluster_threshold {
        cluster_volume += market.bid_vol_2;
    }
    if market.bid_price_3 > 0 && market.bid_price_3 <= cluster_threshold {
        cluster_volume += market.bid_vol_3;
    }
    if market.bid_price_4 > 0 && market.bid_price_4 <= cluster_threshold {
        cluster_volume += market.bid_vol_4;
    }
    
    if cluster_volume > 1000 && account.stock > 0 {
        let sell_amount = if cluster_volume > 5000 { 500 } else { 200 };
        if sell_amount > account.stock {
            sell_amount = account.stock;
        }
        
        orders.submit_market_sell(sell_amount);
        
        let buy_price = cluster_threshold * 95 / 100;
        let buy_amount = sell_amount * 120 / 100;
        let max_affordable = (account.cash * 80 / 100) / buy_price;
        
        if buy_amount > max_affordable {
            buy_amount = max_affordable;
        }
        
        if buy_amount > 0 {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    }
    
    last_price = current_price;
}