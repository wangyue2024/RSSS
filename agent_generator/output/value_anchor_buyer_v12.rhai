let initialized = false;
let fair_value = 0;
let base_lot = 100;
let lot_multiplier = 1;
let last_position = 0;

fn on_tick() {
    if !initialized {
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let tick_limit = market.total_ticks / 5;
    if market.tick >= tick_limit { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let threshold_95 = fair_value * 95 / 100;
    let threshold_90 = fair_value * 90 / 100;
    let current_price = market.price;
    
    if current_price < threshold_90 {
        let buy_amount = base_lot * lot_multiplier * 4;
        if buy_amount > 0 {
            orders.submit_limit_buy(current_price, buy_amount);
        }
    } else if current_price < threshold_95 {
        let buy_amount = base_lot * lot_multiplier;
        if buy_amount > 0 {
            orders.submit_limit_buy(current_price, buy_amount);
        }
    }
    
    if account.stock != last_position {
        if last_position > 0 && account.stock > last_position {
            let current_position = account.stock;
            if current_price < account.avg_cost {
                lot_multiplier *= 2;
            } else {
                lot_multiplier = 1;
            }
        }
        last_position = account.stock;
    }
}