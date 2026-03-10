let initialized = false;
let vol_lookback = 10;
let min_vol_threshold = 100;
let order_timeout = 3;
let base_trade_amount = 1000;
let last_order_ticks = [];
let last_order_ids = [];

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        let placed_tick = my_orders.pending_placed_tick(i);
        
        if current_tick - placed_tick > order_timeout {
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    let avg_recent_vol = 0;
    let hist_len = market.history_len();
    if hist_len >= vol_lookback {
        let vol_sum = 0;
        let j = 0;
        while j < vol_lookback {
            vol_sum += market.history_volume(j);
            j += 1;
        }
        avg_recent_vol = vol_sum / vol_lookback;
    }
    
    let volume_drop = false;
    if avg_recent_vol > 0 && market.volume < min_vol_threshold {
        volume_drop = true;
    }
    
    let price_above_ma = market.price > market.ma_60 && market.ma_60 > 0;
    
    if volume_drop && price_above_ma {
        let sell_price = market.bid_price_0;
        if sell_price > 0 {
            orders.submit_limit_sell(sell_price, base_trade_amount);
        }
    }
}