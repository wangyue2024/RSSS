let initialized = false;
let stop_loss_threshold = 0;
let volume_threshold = 0;
let avg_volume = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_threshold = rng.rand_int(50_000, 200_000);
        volume_threshold = rng.rand_int(500, 2_000);
    }
    
    if !market.trading_enabled { return; }
    
    if account.unrealized_pnl < -stop_loss_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }
    
    if market.tick % 50 != 0 { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.history_len() < 60 { return; }
    
    let high_price = market.price;
    let current_volume = market.volume;
    let ma60 = market.ma_60;
    
    if ma60 == 0 { return; }
    
    let vol_sum = 0;
    let j = 0;
    while j < 5 && j < market.history_len() {
        vol_sum += market.history_volume(j);
        j += 1;
    }
    avg_volume = if j > 0 { vol_sum / j } else { 0 };
    
    if high_price > ma60 && current_volume < volume_threshold && avg_volume > 0 && current_volume < avg_volume / 2 {
        if account.stock > 0 {
            let sell_price = market.bid_price_0 + 1;
            if sell_price > 0 {
                orders.submit_limit_sell(sell_price, account.stock);
            }
        }
    }
}