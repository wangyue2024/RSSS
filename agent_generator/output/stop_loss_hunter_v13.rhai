let initialized = false;
let fomo_triggered = false;
let morning_active = true;
let panic_threshold = 0;
let last_break_attempt = -100;
let cooldown_ticks = 20;
let last_price = 0;
let price_jump_counter = 0;

fn on_tick() {
    if !initialized {
        panic_threshold = rng.rand_int(5000, 15000);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    let max_tick = market.total_ticks;
    
    morning_active = current_tick < max_tick * 20 / 100;
    if !morning_active { return; }
    
    let current_price = market.price;
    
    if current_tick > 0 {
        if last_price != 0 {
            let price_change = (current_price - last_price) * 10000 / last_price;
            if price_change > 200 {
                price_jump_counter += 1;
                if price_jump_counter >= 2 {
                    fomo_triggered = true;
                }
            } else {
                price_jump_counter = 0;
            }
        }
        last_price = current_price;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if fomo_triggered {
        if account.cash > 1000000 && market.ask_price_0 > 0 {
            let buy_amount = account.cash / market.ask_price_0;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        }
        fomo_triggered = false;
        return;
    }
    
    if account.unrealized_pnl < -panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    if current_tick - last_break_attempt < cooldown_ticks { return; }
    
    let cluster_detected = false;
    let cluster_price = 0;
    let cluster_volume = 0;
    
    let price_99 = current_price * 99 / 100;
    let price_98 = current_price * 98 / 100;
    
    if market.bid_price_0 >= price_98 && market.bid_price_0 <= price_99 && market.bid_vol_0 > 5000 {
        cluster_detected = true;
        cluster_price = market.bid_price_0;
        cluster_volume = market.bid_vol_0;
    }
    
    if market.bid_price_1 >= price_98 && market.bid_price_1 <= price_99 && market.bid_vol_1 > 5000 {
        cluster_detected = true;
        cluster_price = market.bid_price_1;
        cluster_volume += market.bid_vol_1;
    }
    
    if market.bid_price_2 >= price_98 && market.bid_price_2 <= price_99 && market.bid_vol_2 > 5000 {
        cluster_detected = true;
        cluster_price = market.bid_price_2;
        cluster_volume += market.bid_vol_2;
    }
    
    if cluster_detected && account.stock > 0 {
        let sell_amount = cluster_volume * 120 / 100;
        if sell_amount > account.stock {
            sell_amount = account.stock;
        }
        
        if sell_amount > 0 {
            orders.submit_market_sell(sell_amount);
            last_break_attempt = current_tick;
            
            let buy_back_price = cluster_price * 98 / 100;
            if buy_back_price > 0 && account.cash > buy_back_price {
                let buy_amount = account.cash / buy_back_price;
                if buy_amount > 0 {
                    orders.submit_limit_buy(buy_back_price, buy_amount);
                }
            }
        }
    }
}