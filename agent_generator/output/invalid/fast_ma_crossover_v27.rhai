let initialized = false;
let last_price = 0;
let last_cross = 0;
let fomo_triggered = false;
let order_placement_ticks = #{};

fn on_tick() {
    if !initialized {
        initialized = true;
        last_price = market.price;
        return;
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= market.total_ticks / 5 {
        let pending = my_orders.pending_count();
        let i = 0;
        while i < pending {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }
    
    let price_change = (market.price - last_price) * 100 / last_price;
    if price_change > 200 {
        fomo_triggered = true;
        let buy_amount = account.cash / market.price;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
        last_price = market.price;
        return;
    }
    fomo_triggered = false;
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        let placed_tick = order_placement_ticks[oid];
        if placed_tick != () && (market.tick - placed_tick > 3) {
            orders.submit_cancel(oid);
            order_placement_ticks.remove(oid);
        }
        i += 1;
    }
    
    if fomo_triggered {
        last_price = market.price;
        return;
    }
    
    let current_cross = 0;
    if market.ma_5 > market.ma_20 {
        current_cross = 1;
    } else if market.ma_5 < market.ma_20 {
        current_cross = -1;
    }
    
    if current_cross != last_cross {
        let pending_cnt = my_orders.pending_count();
        let j = 0;
        while j < pending_cnt {
            orders.submit_cancel(my_orders.pending_id(j));
            j += 1;
        }
        
        if current_cross == 1 && last_cross <= 0 {
            let buy_amount = account.cash / market.price;
            if buy_amount > 0 {
                let oid = orders.submit_limit_buy(market.price, buy_amount);
                order_placement_ticks[oid] = market.tick;
            }
        } else if current_cross == -1 && last_cross >= 0 {
            if account.stock > 0 {
                let oid = orders.submit_limit_sell(market.price, account.stock);
                order_placement_ticks[oid] = market.tick;
            }
        }
        last_cross = current_cross;
    }
    
    last_price = market.price;
}