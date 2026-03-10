let session_active = false;
let entry_condition_met = false;
let round_sell_price = 0;
let last_volume_check = 0;

fn on_tick() {
    if !market.trading_enabled { 
        return; 
    }

    let total_ticks = market.total_ticks;
    let current_tick = market.tick;
    
    if current_tick * 5 < total_ticks {
        session_active = true;
    } else {
        session_active = false;
    }

    if session_active {
        let ma_60_available = market.ma_60 != 0;
        if ma_60_available {
            let price_above_ma = market.price > market.ma_60;
            let history_len = market.history_len();
            
            if price_above_ma && history_len >= 5 {
                let volume_sum = 0;
                let i = 0;
                while i < 5 {
                    volume_sum += market.history_volume(i);
                    i += 1;
                }
                let avg_volume = volume_sum / 5;
                let volume_threshold = avg_volume * 10 / 100;
                
                if market.volume < volume_threshold {
                    entry_condition_met = true;
                    last_volume_check = market.volume;
                    
                    let nearest_million = ((market.price + 500_000) / 1_000_000) * 1_000_000;
                    round_sell_price = nearest_million;
                } else {
                    entry_condition_met = false;
                }
            } else {
                entry_condition_met = false;
            }
        }
        
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        if entry_condition_met && round_sell_price > 0 {
            orders.submit_limit_sell(round_sell_price, 100);
        }
    } else {
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        entry_condition_met = false;
    }
}