let initialized = false;
let lot_size = 0;
let max_ticks_until_cancel = 3;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        let risk_cap = account.total_equity * 5 / 100;
        if market.price > 0 {
            lot_size = rng.rand_int(1, risk_cap / market.price);
        } else {
            lot_size = 100;
        }
        if lot_size < 1 { lot_size = 1; }
    }
    
    if market.tick >= market.total_ticks / 5 {
        let p_count = my_orders.pending_count();
        let i = 0;
        while i < p_count {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }
    
    let vol_threshold = market.price * 5 / 1000;
    if market.std_dev > vol_threshold {
        let p_count = my_orders.pending_count();
        let i = 0;
        while i < p_count {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }
    
    let p_count = my_orders.pending_count();
    let i = 0;
    while i < p_count {
        let age = market.tick - my_orders.pending_placed_tick(i);
        if age >= max_ticks_until_cancel {
            orders.submit_cancel(my_orders.pending_id(i));
        }
        i += 1;
    }
    
    let hist_len = market.history_len();
    if hist_len < 5 { return; }
    
    let price_window = 5;
    let slope_window = [];
    let j = 0;
    while j < price_window && j < hist_len {
        slope_window.push(market.history_price(j));
        j += 1;
    }
    let current_slope = arr_slope(slope_window);
    
    if current_slope > 5000 && account.stock == 0 {
        let buy_price = market.ask_price_0;
        if buy_price > 0 {
            let amount = lot_size;
            if amount > 0 {
                orders.submit_limit_buy(buy_price, amount);
            }
        }
    }
    
    if current_slope < -2000 && account.stock > 0 {
        let sell_price = market.bid_price_0;
        if sell_price > 0 {
            let amount = account.stock;
            if amount > 0 {
                orders.submit_limit_sell(sell_price, amount);
            }
        }
    }
}