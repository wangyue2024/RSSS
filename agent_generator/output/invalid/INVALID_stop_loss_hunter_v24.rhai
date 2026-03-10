// Generation Failed after 5 retries.
// Last error: ERROR: Compile error: Expecting '{' to start a statement block (line 39, position 82)
// Global variables persist across ticks
let initialized = false;
let mode = "hUNTING";
let target_cover_price = 0;
let attack_volume = 0;
let attack_tick = 0;
let cluster_price = 0;
let pending_order_tracker = [];

// Round to nearest dollar (1_000_000 micros)
fn round_price(price) {
    let remainder = price % 1_000_000;
    if remainder >= 500_000 {
        price - remainder + 1_000_000
    } else {
        price - remainder
    }
}

// Detect stop loss clusters at round numbers below current price
fn find_stop_loss_cluster() {
    let current = market.price;
    let max_lookback = 2_000_000; // 2 dollars below
    let min_volume = 2000; // Minimum volume to consider a cluster
    
    // Check bid levels for round number clusters
    let bid_levels = [
        [market.bid_price_0, market.bid_vol_0],
        [market.bid_price_1, market.bid_vol_1],
        [market.bid_price_2, market.bid_vol_2],
        [market.bid_price_3, market.bid_vol_3],
        [market.bid_price_4, market.bid_vol_4]
    ];
    
    for level in bid_levels {
        let price = level[0];
        let volume = level[1];
        
        if price > 0 && volume >= min_volume && (current - price) <= max_lookback) {
            // Check if price is a round number (dollar boundary)
            if price % 1_000_000 == 0 {
                return price;
            }
        }
    }
    
    0 // No cluster found
}

fn on_tick() {
    if !initialized {
        initialized = true;
        // Initialize with some randomness for aggression
        attack_volume = rng.rand_int(100, 500);
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel orders older than 3 ticks
    let current_tick = market.tick;
    let i = 0;
    while i < my_orders.pending_count() {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            
            // Remove from tracker
            let j = 0;
            while j < pending_order_tracker.len() {
                if pending_order_tracker[j] == oid {
                    pending_order_tracker.remove(j);
                    break;
                }
                j += 1;
            }
        }
        i += 1;
    }
    
    // Update pending order tracker
    let fresh_pending = [];
    let k = 0;
    while k < my_orders.pending_count() {
        fresh_pending.push(my_orders.pending_id(k));
        k += 1;
    }
    pending_order_tracker = fresh_pending;
    
    // Check for filled short positions
    let fill_count = my_orders.fill_count();
    let f = 0;
    while f < fill_count {
        let fill_side = my_orders.fill_side(f);
        if mode == "COVERING" && fill_side == 0) { // Buy fill
            mode = "HUNTING";
        }
        f += 1;
    }
    
    // Main strategy logic
    if mode == "HUNTING" {
        // Look for stop loss clusters
        cluster_price = find_stop_loss_cluster();
        
        if cluster_price > 0) {
            // Found a cluster - attack!
            let sell_volume = attack_volume;
            if account.stock >= sell_volume {
                orders.submit_market_sell(sell_volume);
            } else {
                // Short sell if allowed (negative stock)
                orders.submit_market_sell(sell_volume);
            }
            
            mode = "COVERING";
            attack_tick = current_tick;
            // Target cover at next round number below cluster
            target_cover_price = round_price(cluster_price - 1_000_000);
            if target_cover_price < 0 { target_cover_price = 0; }
        } else {
            // No cluster found - place resting limit orders at round numbers
            let spread = market.ask_price_0 - market.bid_price_0;
            if spread > 500_000) { // Only if spread is reasonable
                let bid_price = round_price(market.bid_price_0 - 100_000);
                let ask_price = round_price(market.ask_price_0 + 100_000);
                
                // Place limit orders if we don't have too many pending
                if pending_order_tracker.len() < 3 {
                    if account.cash > 1_000_000) {
                        orders.submit_limit_buy(bid_price, attack_volume);
                    }
                    if account.stock > attack_volume {
                        orders.submit_limit_sell(ask_price, attack_volume);
                    }
                }
            }
        }
    } else if mode == "COVERING") {
        // Try to cover our short position
        if account.stock < 0) {
            // Place limit buy at target round price
            if pending_order_tracker.len() < 2) {
                let cover_amount = -account.stock;
                if cover_amount > 0) {
                    orders.submit_limit_buy(target_cover_price, cover_amount);
                }
            }
            
            // Emergency cover if price moves against us
            if current_tick - attack_tick > 10) {
                orders.submit_market_buy(-account.stock);
                mode = "HUNTING";
            }
        } else {
            mode = "HUNTING";
        }
    }
}