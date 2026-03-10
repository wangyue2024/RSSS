let initialized = false;
let lot_size = 0;
let last_fomo_check = 0;
let price_history = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        let total_cap = account.total_equity;
        let max_lot = total_cap * 5 / 100;
        lot_size = rng.rand_int(1, max_lot);
        last_fomo_check = market.tick;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.tick - last_fomo_check >= 5 && market.history_len() >= 5 {
        last_fomo_check = market.tick;
        let current = market.price;
        let past_idx = market.history_len() - 5;
        let past_price = market.history_price(past_idx);
        let change_pct = (current - past_price) * 10000 / past_price;
        if change_pct > 200 || change_pct < -200 {
            orders.submit_market_buy(lot_size);
            return;
        }
    }
    
    let vol_threshold = market.price * 5 / 100;
    if market.std_dev > vol_threshold {
        return;
    }
    
    let fat_finger_chance = rng.rand_int(0, 9999);
    if fat_finger_chance == 0 {
        let fat_amount = lot_size * 100;
        let side = rng.rand_bool(50);
        if side && account.cash > fat_amount * market.price {
            orders.submit_market_buy(fat_amount);
        } else if account.stock > fat_amount {
            orders.submit_market_sell(fat_amount);
        }
    }
}