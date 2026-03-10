let initialized = false;
let base_position = 0;
let trade_size = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_position = rng.rand_int(800, 1200);
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.tick >= market.total_ticks * 20 / 100 {
        return;
    }
    
    let deviation = abs_val(market.price - market.ma_20);
    let atr_threshold = market.atr_14 * 3 / 2;
    
    if deviation > atr_threshold && market.atr_14 > 0 {
        if market.price > market.ma_20 {
            if account.stock >= trade_size && market.price > account.avg_cost {
                orders.submit_market_sell(trade_size);
            }
        } else {
            if account.cash >= market.price * trade_size {
                orders.submit_market_buy(trade_size);
            }
        }
    }
}