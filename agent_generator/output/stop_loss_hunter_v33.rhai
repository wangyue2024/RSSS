let initialized = false;
let aggression = 0;
let cooldown = 0;
let fomo_triggered = false;
let fomo_cooldown = 0;
let last_price = 0;
let price_jump_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        aggression = rng.rand_int(70, 95);
        price_jump_threshold = 20000; // 2% in hundredths of a percent
    }
    
    if !market.trading_enabled { return; }
    
    let current_price = market.price;
    
    if last_price == 0 {
        last_price = current_price;
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if cooldown > 0 {
        cooldown -= 1;
    }
    
    if fomo_cooldown > 0 {
        fomo_cooldown -= 1;
        fomo_triggered = fomo_cooldown > 0;
    }
    
    let price_change = (current_price - last_price) * 10000 / last_price;
    let abs_change = abs_val(price_change);
    
    if abs_change > price_jump_threshold && price_change > 0 && fomo_cooldown == 0 {
        fomo_triggered = true;
        fomo_cooldown = 10;
        
        let available_cash = account.cash;
        if available_cash > 1000000 {
            let buy_amount = available_cash * 80 / (100 * current_price);
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        }
        last_price = current_price;
        return;
    }
    
    if fomo_triggered || cooldown > 0 {
        last_price = current_price;
        return;
    }
    
    let support_cluster = 0;
    let support_threshold = current_price * 99 / 100;
    
    if market.bid_price_0 > 0 && market.bid_price_0 <= support_threshold {
        support_cluster += market.bid_vol_0;
    }
    if market.bid_price_1 > 0 && market.bid_price_1 <= support_threshold {
        support_cluster += market.bid_vol_1;
    }
    if market.bid_price_2 > 0 && market.bid_price_2 <= support_threshold {
        support_cluster += market.bid_vol_2;
    }
    
    if support_cluster > 1000 && account.stock > 0 {
        let sell_amount = clamp_val(account.stock * aggression / 100, 1, support_cluster * 120 / 100);
        
        if sell_amount > 0 {
            orders.submit_market_sell(sell_amount);
            cooldown = 5;
            
            let expected_price = current_price * 98 / 100;
            let buy_back_amount = sell_amount * 110 / 100;
            let max_affordable = account.cash / expected_price;
            let actual_buy = clamp_val(buy_back_amount, 1, max_affordable);
            
            if actual_buy > 0 && expected_price > 0 {
                orders.submit_limit_buy(expected_price, actual_buy);
            }
        }
    }
    
    last_price = current_price;
}