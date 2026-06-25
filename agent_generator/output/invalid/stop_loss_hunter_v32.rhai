let initialized = false;
let hunting_state = 0;
let hunt_order_id = -1;
let hunt_amount = 0;
let target_buy_price = 0;
let hunt_start_tick = 0;
let THRESHOLD_VOLUME = 10000;
let CLUSTER_DISTANCE_PCT = 2;

fn round_to_dollar(price) {
    let remainder = price % 1_000_000;
    if remainder >= 500_000 {
        price - remainder + 1_000_000
    } else {
        price - remainder
    }
}

fn on_tick() {
    if !initialized {
        initialized = true;
        THRESHOLD_VOLUME = rng.rand_int(8000, 12000);
        CLUSTER_DISTANCE_PCT = rng.rand_int(1, 3);
    }
    
    if !market.trading_enabled { return; }
    
    if hunting_state == 1 {
        let found = false;
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            if my_orders.pending_id(i) == hunt_order_id {
                found = true;
                if market.tick - hunt_start_tick > 10 {
                    orders.submit_cancel(hunt_order_id);
                    hunting_state = 0;
                    hunt_order_id = -1;
                }
                break;
            }
            i += 1;
        }
        if !found {
            hunting_state = 0;
            hunt_order_id = -1;
        }
    }
    
    if hunting_state == 0 {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        let cluster_volume = 0;
        let cluster_levels = [];
        let min_price = market.price * (100 - CLUSTER_DISTANCE_PCT) / 100;
        
        let bid_prices = [];
        let bid_volumes = [];
        bid_prices.push(market.bid_price_0);
        bid_prices.push(market.bid_price_1);
        bid_prices.push(market.bid_price_2);
        bid_prices.push(market.bid_price_3);
        bid_prices.push(market.bid_price_4);
        bid_volumes.push(market.bid_vol_0);
        bid_volumes.push(market.bid_vol_1);
        bid_volumes.push(market.bid_vol_2);
        bid_volumes.push(market.bid_vol_3);
        bid_volumes.push(market.bid_vol_4);
        
        let j = 0;
        while j < 5 {
            if bid_prices[j] >= min_price && bid_volumes[j] >= THRESHOLD_VOLUME {
                cluster_levels.push(j);
                cluster_volume += bid_volumes[j];
            }
            j += 1;
        }
        
        let consecutive = false;
        let k = 0;
        while k < cluster_levels.len() - 1 {
            if cluster_levels[k + 1] - cluster_levels[k] == 1 {
                consecutive = true;
                break;
            }
            k += 1;
        }
        
        if consecutive && cluster_levels.len() >= 2 && account.stock > 0 {
            let lowest_idx = arr_max(cluster_levels);
            let lowest_price = bid_prices[lowest_idx];
            
            target_buy_price = lowest_price * 99 / 100;
            target_buy_price = round_to_dollar(target_buy_price) + 1;
            
            hunt_amount = account.stock;
            if hunt_amount > cluster_volume {
                hunt_amount = cluster_volume;
            }
            
            if hunt_amount > 0 {
                orders.submit_market_sell(hunt_amount);
                hunting_state = 1;
                hunt_start_tick = market.tick;
                
                let cash_needed = target_buy_price * hunt_amount;
                if cash_needed > account.cash {
                    hunt_amount = account.cash / target_buy_price;
                }
                
                if hunt_amount > 0 {
                    let result = orders.submit_limit_buy(target_buy_price, hunt_amount);
                    hunt_order_id = result;
                }
            }
        }
    }
}