let initialized = false;
let price_history = [];
let last_action_tick = 0;
let attack_phase = 0;
let target_support = 0;
let sell_amount = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        sell_amount = rng.rand_int(10, 100);
    }
    
    if !market.trading_enabled { return; }
    
    // Delayed reaction: store current price for future use
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    // Cancel orders older than 3 ticks
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let placed = my_orders.pending_placed_tick(i);
        if market.tick - placed > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    // Wait for enough history
    if price_history.len() < 5 { return; }
    
    let delayed_price = price_history[0];
    
    // Detect support cluster below delayed price
    let cluster_detected = false;
    let cluster_price = 0;
    let cluster_volume = 0;
    
    // Check bid levels 1-4 (not top of book) for significant volume
    let i = 1;
    while i <= 4 {
        let bid_price = if i == 1 { market.bid_price_1 } 
                       else if i == 2 { market.bid_price_2 }
                       else if i == 3 { market.bid_price_3 }
                       else { market.bid_price_4 };
        
        let bid_vol = if i == 1 { market.bid_vol_1 } 
                     else if i == 2 { market.bid_vol_2 }
                     else if i == 3 { market.bid_vol_3 }
                     else { market.bid_vol_4 };
        
        // Check if this bid is significantly below delayed price (1-2% range)
        if bid_price > 0 && delayed_price > 0 {
            let price_diff = delayed_price - bid_price;
            let diff_percent = price_diff * 10000 / delayed_price;
            
            if diff_percent >= 100 && diff_percent <= 200 && bid_vol > 1000 {
                cluster_detected = true;
                cluster_price = bid_price;
                cluster_volume = bid_vol;
                break;
            }
        }
        i += 1;
    }
    
    // Attack logic
    if attack_phase == 0 {
        if cluster_detected && market.tick - last_action_tick > 10 {
            // Initiate attack: market sell to break support
            let available = account.stock;
            if available > 0 {
                let attack_qty = if available < sell_amount { available } else { sell_amount };
                orders.submit_market_sell(attack_qty);
                target_support = cluster_price;
                attack_phase = 1;
                last_action_tick = market.tick;
            }
        }
    } else if attack_phase == 1 {
        // Wait 2 ticks for price to drop, then buy back
        if market.tick - last_action_tick > 2 {
            // Buy back at depressed price (slightly above target support)
            let buy_price = target_support + (target_support * 50 / 10000);
            let cash_available = account.cash;
            let max_buy = cash_available / buy_price;
            
            if max_buy > 0 {
                let buy_qty = if max_buy < sell_amount { max_buy } else { sell_amount };
                orders.submit_limit_buy(buy_price, buy_qty);
                attack_phase = 0;
                last_action_tick = market.tick;
            }
        }
    }
}