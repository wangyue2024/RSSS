let initialized = false;
let target_position = 50000;
let frequency_ticks = 10;
let last_buy_tick = -100;
let lot_size = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        let cash_50_percent = account.cash / 2;
        let shares_affordable = cash_50_percent / market.price;
        lot_size = rng.rand_int(shares_affordable / 2, shares_affordable);
        if lot_size < 100 { lot_size = 100; }
        last_buy_tick = market.tick - frequency_ticks;
        initialized = true;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_position = account.stock;
    if current_position < target_position {
        let ticks_since_last = market.tick - last_buy_tick;
        if ticks_since_last >= frequency_ticks {
            let remaining = target_position - current_position;
            let buy_amount = remaining;
            if lot_size < buy_amount {
                buy_amount = lot_size;
            }
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
                last_buy_tick = market.tick;
            }
        }
    }
}