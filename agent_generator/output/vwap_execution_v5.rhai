let initialized = false;
let base_lot_size = 0;
let target_amount = 0;
let bought_so_far = 0;
let volume_lookback = 20;

fn on_tick() {
    if !initialized {
        initialized = true;
        
        let total_capital = account.total_equity;
        let five_percent_cap = total_capital * 5 / 100;
        let max_lot_stocks = five_percent_cap / market.price;
        
        if max_lot_stocks > 0 {
            base_lot_size = rng.rand_int(1, max_lot_stocks);
        } else {
            base_lot_size = 1;
        }
        
        let risk_cap = total_capital * 20 / 100;
        target_amount = risk_cap / market.price;
        bought_so_far = 0;
    }
    
    if !market.trading_enabled { return; }
    
    let volatility_threshold = market.price * 2 / 100;
    if market.std_dev > volatility_threshold {
        return;
    }
    
    let fill_count = my_orders.fill_count();
    let i = 0;
    while i < fill_count {
        let side = my_orders.fill_side(i);
        if side == 0 {
            bought_so_far += my_orders.fill_amount(i);
        }
        i += 1;
    }
    
    if bought_so_far >= target_amount {
        return;
    }
    
    let count = my_orders.pending_count();
    let j = 0;
    while j < count {
        let oid = my_orders.pending_id(j);
        orders.submit_cancel(oid);
        j += 1;
    }
    
    if market.history_len() < 2 { return; }
    
    let total_vol = 0;
    let samples = 0;
    let k = 0;
    while k < volume_lookback && k < market.history_len() {
        total_vol += market.history_volume(k);
        samples += 1;
        k += 1;
    }
    
    if samples == 0 { return; }
    
    let avg_volume = total_vol / samples;
    if avg_volume == 0 { return; }
    
    let volume_ratio = market.volume * 100 / avg_volume;
    let adjusted_ratio = clamp_val(volume_ratio, 50, 200);
    let dynamic_lot = base_lot_size * adjusted_ratio / 100;
    
    let remaining = target_amount - bought_so_far;
    let order_amount = dynamic_lot;
    if order_amount > remaining {
        order_amount = remaining;
    }
    
    if order_amount < 1 { return; }
    
    let bid_spread = market.price - market.bid_price_0;
    let safe_bid = market.bid_price_0;
    if bid_spread > 50000 {
        safe_bid = market.price - 10000;
    }
    
    if safe_bid < 1 { safe_bid = 1; }
    
    orders.submit_limit_buy(safe_bid, order_amount);
}