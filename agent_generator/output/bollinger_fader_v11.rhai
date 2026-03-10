let initialized = false;
let price_history = [];
let last_action_tick = 0;
let lot_size = 0;
let max_orders_placed = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let five_percent_capital = (account.total_equity * 5) / 100;
        if five_percent_capital > 0 {
            lot_size = rng.rand_int(1, five_percent_capital);
        } else {
            lot_size = 1;
        }
        max_orders_placed = 0;
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if price_history.len() < 5 { return; }
    
    let delayed_price = price_history[0];
    let five_percent_price = (delayed_price * 5) / 100;
    
    if market.std_dev >= five_percent_price {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    let current_tick = market.tick;
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if current_tick <= last_action_tick { return; }
    
    let lower_band = market.ma_20 - 2 * market.std_dev;
    let upper_band = market.ma_20 + 2 * market.std_dev;
    
    if lower_band <= 0 || upper_band <= 0 { return; }
    
    let pending_count = my_orders.pending_count();
    let has_buy = false;
    let has_sell = false;
    let i = 0;
    while i < pending_count {
        let side = my_orders.pending_side(i);
        if side == 0 { has_buy = true; }
        if side == 1 { has_sell = true; }
        i += 1;
    }
    
    if !has_buy {
        orders.submit_limit_buy(lower_band, lot_size);
    }
    
    if !has_sell {
        orders.submit_limit_sell(upper_band, lot_size);
    }
    
    last_action_tick = current_tick;
}