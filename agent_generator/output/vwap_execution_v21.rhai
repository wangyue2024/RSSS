let initialized = false;
let total_target = 10000;
let bought_so_far = 0;
let total_cost = 0;
let base_lot_size = 100;
let last_fill_price = 0;
let last_trade_loss = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let fill_count = my_orders.fill_count();
    if fill_count > 0 {
        for i in 0..fill_count {
            let fill_price = my_orders.fill_price(i);
            let fill_amount = my_orders.fill_amount(i);
            total_cost += fill_price * fill_amount;
            bought_so_far += fill_amount;
            last_fill_price = fill_price;
        }
    }
    
    if last_fill_price > 0 {
        last_trade_loss = market.price < last_fill_price;
    } else {
        last_trade_loss = false;
    }
    
    last_fill_price = 0;
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if bought_so_far >= total_target {
        return;
    }
    
    let remaining = total_target - bought_so_far;
    if remaining <= 0 { return; }
    
    let lookback = 20;
    let available_ticks = market.history_len();
    let ticks_to_use = available_ticks;
    if available_ticks > lookback {
        ticks_to_use = lookback;
    }
    
    let volume_sum = 0;
    let j = 0;
    while j < ticks_to_use {
        volume_sum += market.history_volume(j);
        j += 1;
    }
    
    let avg_volume = 0;
    if ticks_to_use > 0 {
        avg_volume = volume_sum / ticks_to_use;
    } else {
        avg_volume = market.volume;
    }
    
    let volume_factor = 1;
    if avg_volume > 0 {
        volume_factor = market.volume / avg_volume;
    }
    
    if volume_factor < 500 {
        volume_factor = 500;
    }
    if volume_factor > 2000 {
        volume_factor = 2000;
    }
    
    let adjusted_lot = base_lot_size * volume_factor / 1000;
    
    if last_trade_loss {
        adjusted_lot = adjusted_lot * 2;
    }
    
    if adjusted_lot < 1 {
        adjusted_lot = 1;
    }
    if adjusted_lot > remaining {
        adjusted_lot = remaining;
    }
    
    if market.bid_price_0 > 0 {
        orders.submit_limit_buy(market.bid_price_0, adjusted_lot);
    } else {
        orders.submit_market_buy(adjusted_lot);
    }
}