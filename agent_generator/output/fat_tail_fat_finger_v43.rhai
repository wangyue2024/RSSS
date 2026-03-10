let initialized = false;
let base_lot = 1000;
let current_lot = 1000;
let last_trade_profit = 0;
let last_position_cost = 0;
let in_position = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = 1000;
        current_lot = base_lot;
        last_trade_profit = 0;
        last_position_cost = 0;
        in_position = false;
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= market.total_ticks / 5 { return; }
    if market.tick % 50 != 0 { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if in_position && account.stock != 0 {
        let current_value = account.stock * market.price / 1_000_000;
        let position_value = account.stock * last_position_cost / 1_000_000;
        last_trade_profit = current_value - position_value;
    } else {
        last_trade_profit = 0;
    }
    
    if last_trade_profit < 0 {
        current_lot = current_lot * 2;
        if current_lot > 1000000 {
            current_lot = 1000000;
        }
    } else {
        current_lot = base_lot;
    }
    
    if rng.rand_int(0, 9999) == 0 {
        let fat_finger_amount = current_lot * 100;
        
        if rng.rand_bool(50) {
            orders.submit_market_buy(fat_finger_amount);
            in_position = true;
            if account.stock != 0 {
                last_position_cost = account.avg_cost;
            }
        } else {
            orders.submit_market_sell(fat_finger_amount);
            in_position = false;
            last_position_cost = 0;
        }
    }
}