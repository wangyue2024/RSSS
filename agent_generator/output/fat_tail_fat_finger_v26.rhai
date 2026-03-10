let initialized = false;
let normal_lot_size = 0;
let fat_finger_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        normal_lot_size = account.cash / market.price * 50 / 100;
        if normal_lot_size == 0 {
            normal_lot_size = 1000;
        }
    }
    
    if !market.trading_enabled { return; }
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let fat_finger_chance = rng.rand_int(0, 9999);
    if fat_finger_chance == 0 {
        fat_finger_triggered = true;
        let direction = rng.rand_int(0, 1);
        if direction == 0 {
            let amount = normal_lot_size * 100;
            let max_affordable = account.cash / market.price;
            let buy_amount = if amount > max_affordable { max_affordable } else { amount };
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        } else {
            let amount = normal_lot_size * 100;
            let sell_amount = if amount > account.stock { account.stock } else { amount };
            if sell_amount > 0 {
                orders.submit_market_sell(sell_amount);
            }
        }
    }
}