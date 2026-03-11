let initialized = false;
let fair_value = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        let base_fair_value = 100_000_000;
        let random_offset = rng.rand_int(-2_000_000, 2_000_000);
        fair_value = base_fair_value + random_offset;
    }
    
    let morning_end = market.total_ticks * 20 / 100;
    if market.tick >= morning_end {
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.stock <= 0 { return; }
    
    let current_price = market.price;
    if current_price == 0 { return; }
    
    let threshold_105 = fair_value * 105 / 100;
    let threshold_110 = fair_value * 110 / 100;
    let sell_price = market.bid_price_0;
    
    if sell_price == 0 { return; }
    
    let sell_amount = 0;
    if current_price > threshold_110 {
        sell_amount = account.stock * 30 / 100;
    } else if current_price > threshold_105 {
        sell_amount = account.stock * 10 / 100;
    }
    
    if sell_amount > 0 {
        if sell_amount < 1 { sell_amount = 1; }
        if sell_amount > account.stock { sell_amount = account.stock; }
        orders.submit_limit_sell(sell_price, sell_amount);
    }
}