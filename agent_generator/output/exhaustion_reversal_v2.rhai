let initialized = false;
let volume_lookback = 20;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.history_len() >= volume_lookback && market.high_20 > market.ma_60 {
        let vol_sum = 0;
        let j = 0;
        while j < volume_lookback {
            vol_sum += market.history_volume(j);
            j += 1;
        }
        let avg_vol = vol_sum / volume_lookback;
        
        if avg_vol > 0 && market.volume < (avg_vol * 10 / 100) {
            let raw_price = market.price;
            let rounded_price = ((raw_price + 500_000) / 1_000_000) * 1_000_000;
            let amount = 100;
            
            orders.submit_limit_sell(rounded_price, amount);
        }
    }
}