let initialized = false;
let fomo_triggered = false;
let cluster_detected = false;
let push_attempts = 0;
let last_fomo_tick = 0;
let price_history = [];
let predatory_mode = false;
let target_buy_price = 0;
let aggressive_sell_amount = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        price_history = [];
    }

    if !market.trading_enabled { return; }

    // Cancel all pending orders each tick
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    // Update price history (keep last 20 ticks)
    price_history.push(market.price);
    if price_history.len() > 20 {
        price_history.remove(0);
    }

    // FOMO CHECK: 2% jump in last 5 ticks
    if price_history.len() >= 5 {
        let current_price = price_history[price_history.len() - 1];
        let past_price = price_history[price_history.len() - 5];
        let price_jump = (current_price - past_price) * 10000 / past_price;
        if price_jump > 200 && market.tick - last_fomo_tick > 10 {
            fomo_triggered = true;
            last_fomo_tick = market.tick;
            // Market buy with 50% of cash
            let buy_amount = account.cash * 50 / 100 / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            predatory_mode = false;
            return;
        }
    }

    // Only sell if price > avg_cost (Diamond Hands rule)
    let can_sell = market.price > account.avg_cost && account.stock > 0;

    // Detect cluster of orders below current price (2-3% below)
    cluster_detected = false;
    let cluster_volume = 0;
    let i = 0;
    while i < 5 {
        let bid_price = 0;
        let bid_vol = 0;
        if i == 0 { bid_price = market.bid_price_0; bid_vol = market.bid_vol_0; }
        if i == 1 { bid_price = market.bid_price_1; bid_vol = market.bid_vol_1; }
        if i == 2 { bid_price = market.bid_price_2; bid_vol = market.bid_vol_2; }
        if i == 3 { bid_price = market.bid_price_3; bid_vol = market.bid_vol_3; }
        if i == 4 { bid_price = market.bid_price_4; bid_vol = market.bid_vol_4; }
        
        if bid_price > 0 && bid_price < market.price * 97 / 100 && bid_price > market.price * 95 / 100 {
            cluster_volume += bid_vol;
        }
        i += 1;
    }
    
    if cluster_volume > 10000 {
        cluster_detected = true;
    }

    // Predatory logic
    if !predatory_mode && cluster_detected && can_sell {
        // Enter predatory mode
        predatory_mode = true;
        push_attempts = 0;
        // Sell 30% of position aggressively
        aggressive_sell_amount = account.stock * 30 / 100;
        if aggressive_sell_amount > 0 {
            orders.submit_market_sell(aggressive_sell_amount);
        }
        // Target buy price 5% below current
        target_buy_price = market.price * 95 / 100;
    }

    // If in predatory mode, try to buy back
    if predatory_mode {
        if market.price <= target_buy_price {
            // Buy back more than we sold (150%)
            let buy_back_amount = aggressive_sell_amount * 150 / 100;
            let max_buy = account.cash / market.price;
            if buy_back_amount > max_buy {
                buy_back_amount = max_buy;
            }
            if buy_back_amount > 0 {
                orders.submit_market_buy(buy_back_amount);
            }
            predatory_mode = false;
            fomo_triggered = false;
        } else {
            push_attempts += 1;
            // Try additional push if not working after 3 ticks
            if push_attempts <= 3 && can_sell {
                let extra_sell = account.stock * 10 / 100;
                if extra_sell > 0 {
                    orders.submit_market_sell(extra_sell);
                }
            }
            // Exit if takes too long
            if push_attempts > 10 {
                predatory_mode = false;
            }
        }
    }

    // Reset FOMO after some time
    if market.tick - last_fomo_tick > 50 {
        fomo_triggered = false;
    }
}