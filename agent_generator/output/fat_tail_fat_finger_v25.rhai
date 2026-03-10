let initialized = false;
let normal_order_amount = 0;
let max_offset_dollars = 0;
let cancel_threshold = 3;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        normal_order_amount = rng.rand_int(100, 500);
        max_offset_dollars = rng.rand_int(1, 10);
    }
    
    let fat_finger_chance = rng.rand_int(0, 9999);
    if fat_finger_chance == 0 {
        let fat_amount = normal_order_amount * 100;
        if rng.rand_bool(50) {
            orders.submit_market_buy(fat_amount);
        } else {
            orders.submit_market_sell(fat_amount);
        }
        return;
    }
    
    if market.tick % 50 != 0 {
        return;
    }
    
    let pending_cnt = my_orders.pending_count();
    let to_cancel = [];
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick > cancel_threshold {
            let oid = my_orders.pending_id(i);
            to_cancel.push(oid);
        }
        i += 1;
    }
    
    for oid in to_cancel {
        orders.submit_cancel(oid);
    }
    
    let offset_dollars = rng.rand_int(0, max_offset_dollars);
    let offset_micros = offset_dollars * 1_000_000;
    let base_price = market.price;
    let is_buy = rng.rand_bool(50);
    
    if is_buy {
        let target_price = base_price - offset_micros;
        let rounded_price = (target_price + 500_000) / 1_000_000 * 1_000_000;
        if rounded_price > 0 {
            orders.submit_limit_buy(rounded_price, normal_order_amount);
        }
    } else {
        let target_price = base_price + offset_micros;
        let rounded_price = (target_price + 500_000) / 1_000_000 * 1_000_000;
        orders.submit_limit_sell(rounded_price, normal_order_amount);
    }
}