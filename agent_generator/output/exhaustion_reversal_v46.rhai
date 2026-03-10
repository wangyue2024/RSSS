let initialized = false;
let risk_personality = 0;
let max_wait_ticks = 3;
let lot_size = 0;
let volume_ma_period = 5;
let volume_threshold_pct = 10;
let price_up_pct = 200;
let std_dev_threshold_pct = 200;

fn on_tick() {
    if !initialized {
        initialized = true;
        risk_personality = rng.rand_int(0, 1);
        
        if risk_personality == 0 {
            let equity = account.total_equity;
            let max_risk = equity * 5 / 100;
            lot_size = rng.rand_int(100, max_risk);
        } else {
            let max_risk = account.cash * 50 / 100;
            lot_size = rng.rand_int(max_risk * 80 / 100, max_risk);
        }
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > max_wait_ticks {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if risk_personality == 0 && market.std_dev > (market.price * std_dev_threshold_pct / 10000) {
        return;
    }
    
    let price_up_condition = market.price > (market.ma_60 + (market.ma_60 * price_up_pct / 10000));
    if !price_up_condition { return; }
    
    let hist_len = market.history_len();
    if hist_len < volume_ma_period { return; }
    
    let volume_history = [];
    let j = 0;
    while j < volume_ma_period {
        volume_history.push(market.history_volume(hist_len - 1 - j));
        j += 1;
    }
    
    let avg_volume = arr_mean(volume_history);
    if avg_volume == 0 { return; }
    
    let volume_ratio = market.volume * 100 / avg_volume;
    let exhaustion = volume_ratio < volume_threshold_pct;
    
    if exhaustion {
        let sell_price = market.bid_price_0;
        if sell_price > 0 && lot_size > 0 {
            orders.submit_limit_sell(sell_price, lot_size);
        }
    }
}