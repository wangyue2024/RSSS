let initialized = false;
let last_fomo_check_tick = 0;
let last_cluster_action_tick = 0;
let cooldown_ticks = 0;
let active_phase = 0;
let buy_back_price = 0;
let buy_back_amount = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        cooldown_ticks = rng.rand_int(50, 150);
    }

    if !market.trading_enabled { return; }

    // Cancel all pending orders at start of tick
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    // FOMO check: price jump > 2% in 5 ticks
    if market.tick - last_fomo_check_tick >= 5 {
        last_fomo_check_tick = market.tick;
        if market.history_len() >= 5 {
            let price_now = market.price;
            let price_past = market.history_price(4);
            if price_past > 0 {
                let percent_change = (price_now - price_past) * 10000 / price_past;
                if percent_change > 200 { // 2% = 200 basis points
                    let buy_amount = (account.cash / 2) / market.price;
                    if buy_amount > 0 {
                        orders.submit_market_buy(buy_amount);
                    }
                    active_phase = 0;
                    return;
                }
            }
        }
    }

    // Cooldown check
    if market.tick - last_cluster_action_tick < cooldown_ticks {
        return;
    }

    // Phase 0: Detect stop-loss cluster
    if active_phase == 0 {
        let cluster_volume = 0;
        let cluster_levels = 0;
        
        // Check bid levels 0-4 for round prices below current price
        let i = 0;
        while i < 5 {
            let bid_price = 0;
            let bid_vol = 0;
            if i == 0 {
                bid_price = market.bid_price_0;
                bid_vol = market.bid_vol_0;
            } else if i == 1 {
                bid_price = market.bid_price_1;
                bid_vol = market.bid_vol_1;
            } else if i == 2 {
                bid_price = market.bid_price_2;
                bid_vol = market.bid_vol_2;
            } else if i == 3 {
                bid_price = market.bid_price_3;
                bid_vol = market.bid_vol_3;
            } else if i == 4 {
                bid_price = market.bid_price_4;
                bid_vol = market.bid_vol_4;
            }
            
            if bid_price > 0 && bid_price % 1_000_000 == 0 && bid_price < market.price {
                cluster_volume += bid_vol;
                cluster_levels += 1;
            }
            i += 1;
        }
        
        // Trigger condition: at least 2 round-price bid levels with significant volume
        if cluster_levels >= 2 && cluster_volume > 5000 {
            // Aggressive market sell to push price down
            let sell_amount = account.stock;
            if sell_amount > 0 {
                orders.submit_market_sell(sell_amount);
                // Set buy-back order at depressed round price
                let depressed_price = (market.price * 98 / 100) / 1_000_000 * 1_000_000;
                buy_back_price = depressed_price;
                buy_back_amount = sell_amount;
                active_phase = 1;
                last_cluster_action_tick = market.tick;
            }
        }
    }
    // Phase 1: Place buy-back order
    else if active_phase == 1 {
        if buy_back_price > 0 && buy_back_amount > 0 {
            orders.submit_limit_buy(buy_back_price, buy_back_amount);
            active_phase = 0;
        }
    }
}