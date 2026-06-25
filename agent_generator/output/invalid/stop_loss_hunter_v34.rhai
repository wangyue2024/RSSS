let initialized = false;
let hunting = false;
let last_sell_tick = 0;
let buy_order_id = 0;
let buy_order_placed_tick = 0;
let cluster_threshold = 5000;
let hunt_triggered = false;

fn round_to_dollar(price) {
    ((price + 500_000) / 1_000_000) * 1_000_000
}

fn on_tick() {
    if !initialized {
        initialized = true;
        cluster_threshold = rng.rand_int(3000, 8000);
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    let current_price = market.price;
    
    if hunting {
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            if oid == buy_order_id {
                let placed = my_orders.pending_placed_tick(i);
                if current_tick - placed >= 3 {
                    orders.submit_cancel(oid);
                    buy_order_id = 0;
                }
                break;
            }
            i += 1;
        }
        
        if current_tick - last_sell_tick > 10 {
            hunting = false;
            hunt_triggered = false;
        }
    }
    
    if !hunting {
        let support_volume = 0;
        let price_level = current_price - 2_000_000;
        
        if market.bid_price_0 > 0 && market.bid_price_0 <= price_level {
            support_volume += market.bid_vol_0;
        }
        if market.bid_price_1 > 0 && market.bid_price_1 <= price_level {
            support_volume += market.bid_vol_1;
        }
        if market.bid_price_2 > 0 && market.bid_price_2 <= price_level {
            support_volume += market.bid_vol_2;
        }
        if market.bid_price_3 > 0 && market.bid_price_3 <= price_level {
            support_volume += market.bid_vol_3;
        }
        if market.bid_price_4 > 0 && market.bid_price_4 <= price_level {
            support_volume += market.bid_vol_4;
        }
        
        if support_volume > cluster_threshold && account.stock > 0 {
            let sell_amount = account.stock;
            if sell_amount > 0 {
                orders.submit_market_sell(sell_amount);
                hunting = true;
                hunt_triggered = true;
                last_sell_tick = current_tick;
            }
        }
    }
    
    if hunt_triggered {
        if buy_order_id == 0 {
            let target_price = round_to_dollar(current_price - 3_000_000);
            let buy_amount = account.cash / target_price;
            if buy_amount > 0 && target_price > 0 {
                orders.submit_limit_buy(target_price, buy_amount);
                buy_order_placed_tick = current_tick;
            }
        }
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        let placed = my_orders.pending_placed_tick(i);
        if current_tick - placed >= 3 && oid != buy_order_id {
            orders.submit_cancel(oid);
        }
        i += 1;
    }
}