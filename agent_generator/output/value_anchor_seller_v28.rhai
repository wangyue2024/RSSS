let initialized = false;
let fair_value = 0;
let lot_size = 0;
let vol_threshold = 5_000_000;

fn on_tick() {
    if !initialized {
        fair_value = 100_000_000 + rng.rand_int(-2_000_000, 2_000_000);
        let max_lot = account.total_equity * 5 / 100 / market.price;
        if max_lot < 1 {
            max_lot = 1;
        }
        lot_size = rng.rand_int(1, max_lot);
        initialized = true;
    }
    
    if !market.trading_enabled {
        return;
    }
    
    if market.std_dev > vol_threshold {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }
    
    let cancel_count = my_orders.pending_count();
    let j = 0;
    while j < cancel_count {
        orders.submit_cancel(my_orders.pending_id(j));
        j += 1;
    }
    
    let current_price = market.price;
    let level1 = fair_value * 105 / 100;
    let level2 = fair_value * 110 / 100;
    
    if current_price > level2 && account.stock > 0 {
        let sell_amount = lot_size * 2;
        if sell_amount > account.stock {
            sell_amount = account.stock;
        }
        if sell_amount > 0 {
            orders.submit_limit_sell(current_price + 1, sell_amount);
        }
    } else if current_price > level1 && account.stock > 0 {
        let sell_amount = lot_size;
        if sell_amount > account.stock {
            sell_amount = account.stock;
        }
        if sell_amount > 0 {
            orders.submit_limit_sell(current_price + 1, sell_amount);
        }
    }
}