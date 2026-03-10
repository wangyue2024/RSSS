let initialized = false;
let strategy_phase = 0;
let sell_triggered = false;
let buy_back_price = 0;
let cycle_counter = 0;

fn round_to_nearest_dollar(price) {
    let base = 1_000_000;
    let half = base / 2;
    ((price + half) / base) * base
}

fn get_cluster_below(threshold) {
    let cluster_volume = 0;
    let i = 0;
    while i < 5 {
        let bid_price = market.bid_price_0;
        if i == 1 { bid_price = market.bid_price_1; }
        if i == 2 { bid_price = market.bid_price_2; }
        if i == 3 { bid_price = market.bid_price_3; }
        if i == 4 { bid_price = market.bid_price_4; }
        
        if bid_price > 0 && bid_price < threshold {
            let bid_vol = market.bid_vol_0;
            if i == 1 { bid_vol = market.bid_vol_1; }
            if i == 2 { bid_vol = market.bid_vol_2; }
            if i == 3 { bid_vol = market.bid_vol_3; }
            if i == 4 { bid_vol = market.bid_vol_4; }
            
            cluster_volume += bid_vol;
        }
        i += 1;
    }
    cluster_volume
}

fn on_tick() {
    if !initialized {
        initialized = true;
        strategy_phase = rng.rand_int(0, 2);
        cycle_counter = 0;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    cycle_counter += 1;
    if cycle_counter % 50 != 0 { return; }
    
    let current_price = market.price;
    let round_price = round_to_nearest_dollar(current_price);
    let lookback_ticks = 20;
    
    if lookback_ticks > market.history_len() {
        lookback_ticks = market.history_len();
    }
    
    let recent_prices = [];
    let j = 0;
    while j < lookback_ticks {
        recent_prices.push(market.history_price(j));
        j += 1;
    }
    
    let price_volatility = 0;
    if recent_prices.len() > 1 {
        price_volatility = arr_std_dev(recent_prices);
    }
    
    let avg_volume = 0;
    if recent_prices.len() > 0 {
        let volumes = [];
        let k = 0;
        while k < lookback_ticks && k < market.history_len() {
            volumes.push(market.history_volume(k));
            k += 1;
        }
        avg_volume = arr_mean(volumes);
    }
    
    let support_level = round_price - 1_000_000;
    let cluster_volume_threshold = 5000;
    if price_volatility > 0 {
        cluster_volume_threshold = (avg_volume * 15) / 100;
    }
    
    let cluster_below = get_cluster_below(support_level + 500_000);
    let has_cluster = cluster_below > cluster_volume_threshold;
    
    if !sell_triggered {
        if has_cluster && account.stock > 1000 {
            let push_amount = (account.stock * 30) / 100;
            if push_amount > 0 {
                orders.submit_market_sell(push_amount);
                sell_triggered = true;
                buy_back_price = round_price - 2_000_000;
                if buy_back_price < 0 { buy_back_price = 0; }
            }
        } else {
            if rng.rand_bool(20) {
                let buy_amount = rng.rand_int(100, 500);
                let target_price = round_price - 1_000_000;
                if target_price > 0 {
                    orders.submit_limit_buy(target_price, buy_amount);
                }
            }
        }
    } else {
        if current_price <= buy_back_price || rng.rand_bool(40) {
            let buy_back_amount = (account.cash / buy_back_price) * 80 / 100;
            if buy_back_amount > 0 && buy_back_price > 0 {
                orders.submit_limit_buy(buy_back_price, buy_back_amount);
                sell_triggered = false;
            }
        } else if current_price > buy_back_price + 3_000_000 {
            sell_triggered = false;
        }
    }
}