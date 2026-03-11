let initialized = false;
let fair_value = 0;
let max_position = 0;
let lot_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = 100_000_000 + rng.rand_int(-10_000_000, 10_000_000);
        max_position = account.total_equity * 5 / 100;
        lot_size = rng.rand_int(1_000_000, max_position) / 100;
    }
    
    if !market.trading_enabled { return; }
    if market.tick % 50 != 0 { return; }
    if market.std_dev > fair_value * 10 / 100 { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let price_trigger_aggressive = fair_value * 110 / 100;
    let price_trigger_normal = fair_value * 105 / 100;
    
    if market.price > price_trigger_aggressive && account.stock > 0 {
        let sell_amount = clamp_val(lot_size * 3, 0, account.stock);
        let sell_price = price_trigger_aggressive + 1;
        if sell_amount > 0 && sell_price > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    } else if market.price > price_trigger_normal && account.stock > 0 {
        let sell_amount = clamp_val(lot_size, 0, account.stock);
        let sell_price = price_trigger_normal + 1;
        if sell_amount > 0 && sell_price > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}