let target_shares = 100_000;
let bought_shares = 0;
let initialized = false;
let last_tick = -1;

fn on_tick() {
    if !initialized {
        initialized = true;
        bought_shares = 0;
    }
    
    if !market.trading_enabled {
        return;
    }
    
    let tick = market.tick;
    
    if tick % 50 != 0 {
        return;
    }
    
    if last_tick == tick {
        return;
    }
    last_tick = tick;
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let fill_cnt = my_orders.fill_count();
    i = 0;
    while i < fill_cnt {
        let side = my_orders.fill_side(i);
        let amount = my_orders.fill_amount(i);
        if side == 0 {
            bought_shares += amount;
        } else {
            bought_shares -= amount;
        }
        i += 1;
    }
    
    let current_shares = account.stock;
    
    if current_shares > 0 && market.price > account.avg_cost {
        let sell_price = market.ask_price_0;
        if sell_price > 0 {
            let sell_amount = current_shares / 10;
            if sell_amount > 0 {
                orders.submit_limit_sell(sell_price, sell_amount);
            }
        }
    }
    
    if bought_shares >= target_shares {
        return;
    }
    
    let remaining = target_shares - bought_shares;
    if remaining <= 0 {
        return;
    }
    
    let current_price = market.price;
    let bid_price = market.bid_price_0;
    
    if current_price <= 0 || bid_price <= 0 {
        return;
    }
    
    let lookback = 50;
    let history_len = market.history_len();
    let samples = if history_len < lookback { history_len } else { lookback };
    
    let vol_sum = 0;
    let j = 0;
    while j < samples {
        vol_sum += market.history_volume(j);
        j += 1;
    }
    
    let avg_volume = if samples > 0 { vol_sum / samples } else { market.volume };
    
    let current_volume = market.volume;
    let volume_ratio = if avg_volume > 0 {
        current_volume * 100 / avg_volume
    } else {
        100
    };
    
    let slice_pct = clamp_val(volume_ratio, 50, 200);
    let slice_amount = remaining * slice_pct / 10000;
    
    let order_size = clamp_val(slice_amount, 100, 5000);
    let buy_amount = if order_size > remaining { remaining } else { order_size };
    
    if buy_amount > 0 && bid_price > 0 {
        orders.submit_limit_buy(bid_price, buy_amount);
    }
}