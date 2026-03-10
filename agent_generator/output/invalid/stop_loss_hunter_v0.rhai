let initialized = false;
let fomo_triggered = false;
let hunt_active = false;
let sell_tick = 0;
let buy_target = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let current_price = market.price;
    let price_jump = false;
    
    if market.history_len() >= 5 {
        let past_price = market.history_price(4);
        if past_price != 0 {
            let pct_change = (current_price - past_price) * 10000 / past_price;
            if pct_change > 200 {
                price_jump = true;
            }
        }
    }
    
    if price_jump && !fomo_triggered {
        fomo_triggered = true;
        let buy_amount = account.cash / current_price;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
        return;
    }
    
    if fomo_triggered {
        return;
    }
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if hunt_active {
        if current_price <= buy_target {
            let buy_amount = account.cash / current_price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            hunt_active = false;
        } else if market.tick - sell_tick > 20 {
            hunt_active = false;
        }
        return;
    }
    
    let cluster_volume = 0;
    let j = 1;
    while j <= 4 {
        let bid = market["bid_vol_" + j];
        if bid > 0 {
            cluster_volume += bid;
        }
        j += 1;
    }
    
    if cluster_volume > 10000 {
        let sell_amount = account.stock;
        if sell_amount > 0 {
            orders.submit_market_sell(sell_amount);
            hunt_active = true;
            sell_tick = market.tick;
            buy_target = current_price * 97 / 100;
        }
    }
}