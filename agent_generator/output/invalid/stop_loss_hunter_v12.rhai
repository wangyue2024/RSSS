// Global state
let hunting = false;
let target_buy_price = 0;
let aggression_level = 0;
let initialized = false;
let last_sell_tick = 0;
let hunt_phase = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        aggression_level = rng.rand_int(70, 95);
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    let current_price = market.price;
    
    // High-Frequency Canceler: Cancel orders older than 3 ticks
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    // Check for stop loss clusters below current price
    let cluster_detected = false;
    let cluster_price = 0;
    let cluster_size = 0;
    
    // Look at bid levels 1-4 (below best bid)
    let bid1_price = market.bid_price_1;
    let bid1_vol = market.bid_vol_1;
    let bid2_price = market.bid_price_2;
    let bid2_vol = market.bid_vol_2;
    
    // Detect if there's a significant order cluster 1-2% below current price
    if bid1_price > 0 && bid2_price > 0 {
        let price_diff_pct = (current_price - bid1_price) * 10000 / current_price;
        
        // Look for clusters 1-2% below current price with substantial volume
        if price_diff_pct > 100 && price_diff_pct < 200 {
            let total_cluster_vol = bid1_vol + bid2_vol;
            let avg_vol_threshold = market.volume * 5 / 100; // 5% of current volume
            
            if total_cluster_vol > avg_vol_threshold {
                cluster_detected = true;
                cluster_price = bid1_price;
                cluster_size = total_cluster_vol;
            }
        }
    }
    
    // Strategy logic
    if hunting {
        // We're in hunting phase, try to buy back
        if hunt_phase == 1 {
            // Phase 1: Just sold, wait for price to drop
            if current_price <= target_buy_price * 98 / 100 {
                hunt_phase = 2;
            } else if current_tick - last_sell_tick > 5 {
                // Timeout, give up
                hunting = false;
                hunt_phase = 0;
            }
        } else if hunt_phase == 2 {
            // Phase 2: Price dropped, buy back aggressively
            let buy_amount = cluster_size * 30 / 100;
            if buy_amount > 0 && account.cash > current_price * buy_amount {
                // Use limit buy slightly above current price to ensure fill
                let buy_price = current_price * 1002 / 1000;
                orders.submit_limit_buy(buy_price, buy_amount);
                
                hunting = false;
                hunt_phase = 0;
            }
        }
    } else if cluster_detected && account.stock > 0 {
        // Found stop loss cluster, initiate hunt
        let sell_amount = account.stock * aggression_level / 100;
        if sell_amount > 0 {
            // Aggressive market sell to push price down
            orders.submit_market_sell(sell_amount);
            
            hunting = true;
            hunt_phase = 1;
            target_buy_price = cluster_price * 95 / 100; // Target 5% below cluster
            last_sell_tick = current_tick;
        }
    }
    
    // Normal market making when not hunting
    if !hunting && account.stock > 0 {
        let spread = market.ask_price_0 - market.bid_price_0;
        if spread > 0 {
            let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
            
            // Place limit orders around mid price
            let buy_price = mid_price * 998 / 1000;
            let sell_price = mid_price * 1002 / 1000;
            
            let order_size = 100;
            
            // Only place if we have no pending orders at these levels
            let can_place_buy = true;
            let can_place_sell = true;
            
            let pending_cnt = my_orders.pending_count();
            let j = 0;
            while j < pending_cnt {
                let pprice = my_orders.pending_price(j);
                if abs_val(pprice - buy_price) < mid_price * 1 / 1000 {
                    can_place_buy = false;
                }
                if abs_val(pprice - sell_price) < mid_price * 1 / 1000 {
                    can_place_sell = false;
                }
                j += 1;
            }
            
            if can_place_buy && account.cash > buy_price * order_size {
                orders.submit_limit_buy(buy_price, order_size);
            }
            
            if can_place_sell && account.stock >= order_size {
                orders.submit_limit_sell(sell_price, order_size);
            }
        }
    }
}