let initialized = false;
let fair_value = 0;
let lot_size = 0;
let high_vol_threshold = 5_000_000;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = 100_000_000 + rng.rand_int(-5_000_000, 5_000_000);
        let five_percent_cap = account.total_equity * 5 / 100;
        let max_shares = five_percent_cap / fair_value;
        if max_shares < 1 {
            max_shares = 1;
        }
        lot_size = rng.rand_int(1, max_shares);
    }
    
    if !market.trading_enabled { return; }
    if market.std_dev > high_vol_threshold { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let price = market.price;
    let rounded_price = ((price + 500_000) / 1_000_000) * 1_000_000;
    
    if price > fair_value {
        let sell_amount = 0;
        if price > fair_value * 110 / 100 {
            sell_amount = 3 * lot_size;
        } else if price > fair_value * 105 / 100 {
            sell_amount = lot_size;
        }
        
        if sell_amount > 0 && account.stock >= sell_amount {
            orders.submit_limit_sell(rounded_price, sell_amount);
        }
    }
}