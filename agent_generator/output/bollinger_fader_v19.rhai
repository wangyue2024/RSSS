let initialized = false;
let base_units = 0;
let band_width_multiplier = 2;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_units = 1000;
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= market.total_ticks / 5 {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }
    
    if market.ma_20 == 0 || market.std_dev == 0 {
        return;
    }
    
    let lower_band = market.ma_20 - band_width_multiplier * market.std_dev;
    let upper_band = market.ma_20 + band_width_multiplier * market.std_dev;
    
    if lower_band <= 0 || upper_band <= 0 {
        return;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    let buy_amount = base_units;
    let sell_amount = base_units;
    
    let max_buy_cost = lower_band * buy_amount;
    if account.cash >= max_buy_cost {
        orders.submit_limit_buy(lower_band, buy_amount);
    }
    
    if account.stock >= sell_amount {
        orders.submit_limit_sell(upper_band, sell_amount);
    }
}