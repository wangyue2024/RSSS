let initialized = false;
let state = 0;
let sell_tick = 0;
let sell_price = 0;
let sell_amount = 0;
let fomo_triggered = false;
let recent_prices = [];
let pending_buy_id = 0;
let pending_buy_placed_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= market.total_ticks / 5 {
        return;
    }
    
    recent_prices.push(market.price);
    if recent_prices.len() > 10 {
        recent_prices.remove(0);
    }
    
    let i = 0;
    while i < my_orders.pending_count() {
        let placed = my_orders.pending_placed_tick(i);
        if market.tick - placed > 3 {
            orders.submit_cancel(my_orders.pending_id(i));
        }
        i += 1;
    }
    
    if !fomo_triggered && recent_prices.len() >= 5 {
        let old_price = recent_prices[0];
        let new_price = recent_prices[recent_prices.len() - 1];
        let change_bp = (new_price - old_price) * 10000 / old_price;
        if change_bp > 200 {
            fomo_triggered = true;
            let buy_amount = account.cash * 1 / 10 / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            return;
        }
    }
    
    if fomo_triggered {
        return;
    }
    
    if state == 0 {
        let cluster_threshold = 5000;
        let bid_volume = market.bid_vol_0 + market.bid_vol_1 + market.bid_vol_2;
        
        if bid_volume > cluster_threshold && account.stock > 0 {
            let sell_amt = cluster_threshold / 2;
            if sell_amt > account.stock {
                sell_amt = account.stock;
            }
            if sell_amt > 0 {
                orders.submit_market_sell(sell_amt);
                state = 1;
                sell_tick = market.tick;
                sell_price = market.price;
                sell_amount = sell_amt;
            }
        }
    } else if state == 1 {
        let target_buy_price = sell_price * 98 / 100;
        let buy_placed = false;
        
        i = 0;
        while i < my_orders.pending_count() {
            if my_orders.pending_side(i) == 0 {
                buy_placed = true;
                pending_buy_id = my_orders.pending_id(i);
                break;
            }
            i += 1;
        }
        
        if !buy_placed && market.price <= target_buy_price {
            orders.submit_limit_buy(target_buy_price, sell_amount);
            pending_buy_placed_tick = market.tick;
            state = 2;
        } else if market.tick - sell_tick > 20 {
            state = 0;
        }
    } else if state == 2 {
        let pending = false;
        i = 0;
        while i < my_orders.pending_count() {
            if my_orders.pending_side(i) == 0 {
                pending = true;
                if market.tick - pending_buy_placed_tick > 3 {
                    orders.submit_cancel(my_orders.pending_id(i));
                    let new_price = market.price * 99 / 100;
                    orders.submit_limit_buy(new_price, sell_amount);
                    pending_buy_placed_tick = market.tick;
                }
                break;
            }
            i += 1;
        }
        
        if !pending {
            state = 0;
        }
    }
}