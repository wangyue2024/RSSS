let initialized = false;
let target_shares = 0;
let total_bought = 0;
let last_round_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        target_shares = rng.rand_int(5000, 15000);
    }
    
    if !market.trading_enabled { return; }
    
    let fill_cnt = my_orders.fill_count();
    let i = 0;
    while i < fill_cnt {
        if my_orders.fill_side(i) == "buy" {
            total_bought += my_orders.fill_amount(i);
        }
        i += 1;
    }
    
    let remaining = target_shares - total_bought;
    if remaining <= 0 { return; }
    
    let pending_cnt = my_orders.pending_count();
    let j = 0;
    while j < pending_cnt {
        let oid = my_orders.pending_id(j);
        orders.submit_cancel(oid);
        j += 1;
    }
    
    let recent_vol = market.volume;
    let slice_pct = clamp_val(10 + (recent_vol * 10 / 100000), 5, 30);
    let slice_size = remaining * slice_pct / 100;
    
    if slice_size <= 0 { return; }
    
    let price = market.price;
    let rounded_price = ((price + 500_000) / 1_000_000) * 1_000_000;
    last_round_price = rounded_price;
    
    orders.submit_limit_buy(rounded_price, slice_size);
}