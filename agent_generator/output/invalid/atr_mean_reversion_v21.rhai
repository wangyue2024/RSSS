let initialized = false;
let order_size = 0;
let position_held = false;
let last_action_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        order_size = rng.rand_int(50, 100);
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick < market.total_ticks / 5 {
        let ma20 = market.ma_20;
        let current_price = market.price;
        let atr = market.atr_14;
        
        let threshold = atr * 3 / 2;
        let deviation = current_price - ma20;
        let abs_deviation = abs_val(deviation);
        
        if abs_deviation > threshold && (market.tick - last_action_tick) > 10 {
            let count = my_orders.pending_count();
            let i = 0;
            while i < count {
                let oid = my_orders.pending_id(i);
                orders.submit_cancel(oid);
                i += 1;
            }
            
            if deviation > 0 && account.stock >= order_size {
                let target_price = (current_price + 500_000) / 1_000_000 * 1_000_000;
                orders.submit_limit_sell(target_price, order_size);
                last_action_tick = market.tick;
                position_held = false;
            } else if deviation < 0 && account.cash >= (current_price * order_size) {
                let target_price = (current_price + 500_000) / 1_000_000 * 1_000_000;
                orders.submit_limit_buy(target_price, order_size);
                last_action_tick = market.tick;
                position_held = true;
            }
        }
    } else {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
    }
}