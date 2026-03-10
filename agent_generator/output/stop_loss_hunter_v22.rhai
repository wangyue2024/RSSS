let initialized = false;
let last_action_tick = 0;
let price_buffer = [];
let old_price = 0;
let cluster_threshold = 0;
let sell_aggression = 0;
let buyback_discount = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        cluster_threshold = rng.rand_int(5000, 15000);
        sell_aggression = rng.rand_int(50, 150);
        buyback_discount = rng.rand_int(50, 200);
    }
    
    if !market.trading_enabled { return; }
    
    price_buffer.push(market.price);
    if price_buffer.len() > 5 {
        price_buffer.remove(0);
    }
    
    if price_buffer.len() < 5 { return; }
    
    old_price = price_buffer[0];
    
    if market.tick - last_action_tick < 20 { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let sell_cluster_detected = false;
    let cluster_price = 0;
    
    if market.bid_price_0 > 0 {
        let spread = market.ask_price_0 - market.bid_price_0;
        if spread > 0 {
            let potential_stop_level = old_price - spread;
            if potential_stop_level > market.bid_price_0 {
                let level_diff = potential_stop_level - market.bid_price_0;
                let max_allowed_diff = spread * 3 / 2;
                if level_diff < max_allowed_diff {
                    let total_bid_vol = 0;
                    total_bid_vol += market.bid_vol_0;
                    total_bid_vol += market.bid_vol_1;
                    total_bid_vol += market.bid_vol_2;
                    total_bid_vol += market.bid_vol_3;
                    total_bid_vol += market.bid_vol_4;
                    
                    if total_bid_vol > cluster_threshold {
                        sell_cluster_detected = true;
                        cluster_price = market.bid_price_0;
                    }
                }
            }
        }
    }
    
    if sell_cluster_detected && market.price > account.avg_cost {
        let sell_amount = account.stock * sell_aggression / 10000;
        if sell_amount > 0 {
            orders.submit_market_sell(sell_amount);
            
            let target_buy_price = cluster_price - (cluster_price * buyback_discount / 10000);
            if target_buy_price > 0 {
                let buy_amount = sell_amount;
                if buy_amount > 0 {
                    orders.submit_limit_buy(target_buy_price, buy_amount);
                }
            }
            last_action_tick = market.tick;
        }
    }
}