let initialized = false;
let panic_threshold = 0;
let price_buffer = [];
let volume_buffer = [];
let signal_delay = 5;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(10_000, 50_000);
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    price_buffer.push(market.price);
    volume_buffer.push(market.volume);
    
    if price_buffer.len() > signal_delay {
        price_buffer.remove(0);
        volume_buffer.remove(0);
    }
    
    if price_buffer.len() < signal_delay {
        return;
    }
    
    let delayed_price = price_buffer[0];
    let delayed_volume = volume_buffer[0];
    
    let delayed_high = market.high_20;
    let delayed_ma_60 = market.ma_60;
    
    let volume_threshold = 1000;
    let is_exhaustion = delayed_high > delayed_ma_60 && delayed_volume < volume_threshold;
    
    if is_exhaustion {
        let sell_amount = if account.stock > 0 { account.stock } else { 100 };
        let target_price = market.bid_price_0;
        if target_price > 0 {
            orders.submit_limit_sell(target_price, sell_amount);
        }
    }
}