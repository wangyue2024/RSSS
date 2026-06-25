let initialized = false;
let cluster_threshold = 0;
let aggression_level = 0;
let recovery_phase = 0;
let recovery_target = 0;
let last_action_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        cluster_threshold = rng.rand_int(500_000, 2_000_000);
        aggression_level = rng.rand_int(30, 80);
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    if current_tick % 50 != 0 && recovery_phase == 0 {
        return;
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_price = market.price;
    
    if recovery_phase > 0 {
        if recovery_phase == 1 {
            let rounded_target = (recovery_target / 1_000_000) * 1_000_000;
            if (recovery_target % 1_000_000) >= 500_000 {
                rounded_target + 1_000_000;
            }
            
            let buy_amount = account.cash / (rounded_target * 2);
            if buy_amount > 0 && rounded_target > 0 {
                orders.submit_limit_buy(rounded_target, buy_amount);
            }
            recovery_phase = 0;
        }
        return;
    }
    
    let cluster_pressure = 0;
    let support_level = 0;
    
    i = 0;
    while i < 5 {
        let bid_price = if i == 0 { market.bid_price_0 } 
                       else if i == 1 { market.bid_price_1 }
                       else if i == 2 { market.bid_price_2 }
                       else if i == 3 { market.bid_price_3 }
                       else { market.bid_price_4 };
                       
        let bid_vol = if i == 0 { market.bid_vol_0 } 
                     else if i == 1 { market.bid_vol_1 }
                     else if i == 2 { market.bid_vol_2 }
                     else if i == 3 { market.bid_vol_3 }
                     else { market.bid_vol_4 };
        
        if bid_price > 0 && current_price - bid_price < cluster_threshold {
            cluster_pressure += bid_vol;
            if support_level == 0 || bid_price < support_level {
                support_level = bid_price;
            }
        }
        i += 1;
    }
    
    if cluster_pressure > 10000 && support_level > 0 && account.stock > 1000 {
        let sell_amount = account.stock * aggression_level / 100;
        if sell_amount > 0 {
            orders.submit_market_sell(sell_amount);
            
            let target_buy_price = support_level * 95 / 100;
            let rounded_price = (target_buy_price / 1_000_000) * 1_000_000;
            if (target_buy_price % 1_000_000) >= 500_000 {
                rounded_price + 1_000_000;
            }
            
            recovery_target = rounded_price;
            recovery_phase = 1;
            last_action_tick = current_tick;
        }
    }
}