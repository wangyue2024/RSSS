let initialized = false;
let base_position = 100;
let target_spread = 1000000;
let position_scale = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_position = rng.rand_int(80, 120);
        target_spread = rng.rand_int(800000, 1200000);
        position_scale = rng.rand_int(80, 120);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let high_20 = market.high_20;
    let low_20 = market.low_20;
    
    if high_20 <= low_20 { return; }
    
    let spread = high_20 - low_20;
    let spread_ratio = (target_spread * 100) / spread;
    
    let position_size = base_position * position_scale / 100;
    let scaled_position = position_size * spread_ratio / 100;
    let buy_amount = clamp_val(scaled_position, 10, 1000);
    let sell_amount = buy_amount;
    
    let buy_offset = (spread * 1) / 10;
    let sell_offset = (spread * 1) / 10;
    
    let bid_price = low_20 + buy_offset + 1;
    let ask_price = high_20 - sell_offset;
    
    if account.cash >= bid_price * buy_amount {
        orders.submit_limit_buy(bid_price, buy_amount);
    }
    
    if account.stock >= sell_amount {
        orders.submit_limit_sell(ask_price, sell_amount);
    }
}