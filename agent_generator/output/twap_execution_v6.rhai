let initialized = false;
let target_position = 50000;
let lot_size = 0;
let slice_interval = 10;
let ticks_since_last_buy = 0;
let volatility_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        
        let total_cap = account.cash + account.stock * market.price;
        let max_lot_value = total_cap * 5 / 100;
        let shares_affordable = max_lot_value / market.price;
        
        lot_size = rng.rand_int(100, shares_affordable);
        if lot_size < 1 { lot_size = 1; }
        
        slice_interval = rng.rand_int(5, 20);
        volatility_threshold = market.price * 2 / 100;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.std_dev > volatility_threshold {
        return;
    }
    
    ticks_since_last_buy += 1;
    
    if account.stock < target_position && ticks_since_last_buy >= slice_interval {
        let remaining = target_position - account.stock;
        let buy_amount = remaining;
        if buy_amount > lot_size {
            buy_amount = lot_size;
        }
        
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
            ticks_since_last_buy = 0;
        }
    }
    
    if account.stock > 0 && market.price > account.avg_cost {
        let rounded_price = ((market.price + 500_000) / 1_000_000) * 1_000_000;
        if rounded_price <= account.avg_cost {
            rounded_price = rounded_price + 1_000_000;
        }
        
        let sell_amount = account.stock * 10 / 100;
        if sell_amount < 1 { sell_amount = 1; }
        
        orders.submit_limit_sell(rounded_price, sell_amount);
    }
}