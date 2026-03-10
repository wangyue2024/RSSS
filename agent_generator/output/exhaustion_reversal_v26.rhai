let initialized = false;
let last_trade_tick = -1000;
let cooldown_ticks = 100;
let position_limit = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.tick - last_trade_tick < cooldown_ticks { return; }
    if account.stock <= -position_limit { return; }
    
    let volume_threshold_met = false;
    if market.history_len() >= 5 {
        let recent_volumes = [];
        let j = 0;
        while j < 5 {
            recent_volumes.push(market.history_volume(j));
            j += 1;
        }
        let avg_vol = arr_mean(recent_volumes);
        if avg_vol > 0 && market.volume * 100 < avg_vol * 10 {
            volume_threshold_met = true;
        }
    }
    
    if market.high_20 > market.ma_60 && volume_threshold_met {
        let sell_amount = 10;
        if account.stock >= sell_amount {
            orders.submit_limit_sell(market.bid_price_0, sell_amount);
        } else {
            orders.submit_market_sell(sell_amount);
        }
        last_trade_tick = market.tick;
    }
}