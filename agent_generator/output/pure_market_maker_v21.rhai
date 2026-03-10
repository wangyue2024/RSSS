let initialized = false;
let lot_size = 0;
let spread_micros = 20000;
let max_std_dev = 500000;

fn on_tick() {
    if !initialized {
        initialized = true;
        
        let five_percent_capital = account.total_equity * 5 / 100;
        let max_shares = five_percent_capital / market.price;
        
        if max_shares > 0 {
            lot_size = rng.rand_int(1, max_shares);
        } else {
            lot_size = 1;
        }
    }
    
    if !market.trading_enabled { return; }
    
    let curr_price = market.price;
    
    if market.std_dev > max_std_dev {
        let pending_cnt = my_orders.pending_count();
        let idx = 0;
        while idx < pending_cnt {
            let oid = my_orders.pending_id(idx);
            orders.submit_cancel(oid);
            idx += 1;
        }
        return;
    }
    
    let pending_cnt = my_orders.pending_count();
    let idx = 0;
    while idx < pending_cnt {
        let oid = my_orders.pending_id(idx);
        orders.submit_cancel(oid);
        idx += 1;
    }
    
    if lot_size <= 0 { return; }
    
    let half_spread = spread_micros / 2;
    
    let target_bid = curr_price - half_spread;
    let target_ask = curr_price + half_spread;
    
    let rounded_bid = ((target_bid + 500000) / 1_000_000) * 1_000_000;
    let rounded_ask = ((target_ask + 500000) / 1_000_000) * 1_000_000;
    
    let final_bid = rounded_bid + 1;
    
    if final_bid < curr_price {
        orders.submit_limit_buy(final_bid, lot_size);
    }
    
    if rounded_ask > curr_price {
        orders.submit_limit_sell(rounded_ask, lot_size);
    }
}