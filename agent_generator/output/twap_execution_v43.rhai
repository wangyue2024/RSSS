let initialized = false;
let target_position = 50_000;
let slice_size = 500;
let trade_interval = 10;
let price_history = [];
let tick_counter = 0;
let last_trade_tick = -999999;
let risk_threshold = 200_000;
let lot_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_lot_value = account.total_equity * 5 / 100;
        let max_lot_shares = max_lot_value / market.price;
        lot_size = rng.rand_int(1, max_lot_shares);
    }
    
    if !market.trading_enabled { return; }
    
    tick_counter += 1;
    
    price_history.push(market.price);
    if price_history.len() > 10 {
        price_history.remove(0);
    }
    
    if market.std_dev > risk_threshold { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.stock >= target_position { return; }
    
    if price_history.len() >= 5 && tick_counter >= last_trade_tick + trade_interval {
        let delayed_price = price_history[price_history.len() - 5];
        let target_amount = target_position - account.stock;
        let trade_amount = if target_amount < slice_size { target_amount } else { slice_size };
        
        if trade_amount > 0 {
            let bid_price = delayed_price + 1;
            orders.submit_limit_buy(bid_price, trade_amount);
            last_trade_tick = tick_counter;
        }
    }
}