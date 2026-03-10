let state = 0;
let cluster_price = 0;
let cluster_volume = 0;
let sell_triggered = false;
let buy_back_price = 0;
let buy_back_amount = 0;
let aggression_level = 0;
let price_buffer = 0;
let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        aggression_level = rng.rand_int(70, 90);
        price_buffer = rng.rand_int(1000, 5000);
    }
    
    if !market.trading_enabled { return; }
    
    if state == 0 {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
    }
    
    if state == 0 && !sell_triggered {
        let current_price = market.price;
        let support_level = current_price * 95 / 100;
        
        let total_bid_volume = 0;
        let cluster_found = false;
        
        let bid_price_0 = market.bid_price_0;
        let bid_vol_0 = market.bid_vol_0;
        let bid_price_1 = market.bid_price_1;
        let bid_vol_1 = market.bid_vol_1;
        let bid_price_2 = market.bid_price_2;
        let bid_vol_2 = market.bid_vol_2;
        let bid_price_3 = market.bid_price_3;
        let bid_vol_3 = market.bid_vol_3;
        let bid_price_4 = market.bid_price_4;
        let bid_vol_4 = market.bid_vol_4;
        
        if bid_price_0 > 0 && bid_price_0 >= support_level - price_buffer && bid_price_0 <= support_level + price_buffer {
            total_bid_volume += bid_vol_0;
            if !cluster_found {
                cluster_price = bid_price_0;
                cluster_found = true;
            }
        }
        if bid_price_1 > 0 && bid_price_1 >= support_level - price_buffer && bid_price_1 <= support_level + price_buffer {
            total_bid_volume += bid_vol_1;
            if !cluster_found {
                cluster_price = bid_price_1;
                cluster_found = true;
            }
        }
        if bid_price_2 > 0 && bid_price_2 >= support_level - price_buffer && bid_price_2 <= support_level + price_buffer {
            total_bid_volume += bid_vol_2;
            if !cluster_found {
                cluster_price = bid_price_2;
                cluster_found = true;
            }
        }
        if bid_price_3 > 0 && bid_price_3 >= support_level - price_buffer && bid_price_3 <= support_level + price_buffer {
            total_bid_volume += bid_vol_3;
            if !cluster_found {
                cluster_price = bid_price_3;
                cluster_found = true;
            }
        }
        if bid_price_4 > 0 && bid_price_4 >= support_level - price_buffer && bid_price_4 <= support_level + price_buffer {
            total_bid_volume += bid_vol_4;
            if !cluster_found {
                cluster_price = bid_price_4;
                cluster_found = true;
            }
        }
        
        cluster_volume = total_bid_volume;
        
        if cluster_found && cluster_volume > 10000 && account.stock > 0 {
            let sell_amount = account.stock * aggression_level / 100;
            if sell_amount > 0 {
                orders.submit_market_sell(sell_amount);
                sell_triggered = true;
                buy_back_price = cluster_price * 98 / 100;
                buy_back_amount = sell_amount * 105 / 100;
                state = 1;
            }
        }
    }
    
    if state == 1 && sell_triggered {
        if market.price <= buy_back_price && account.cash > buy_back_price * 1000 / 1000000 {
            let adjusted_price = buy_back_price + 1;
            orders.submit_limit_buy(adjusted_price, buy_back_amount);
            state = 2;
        }
    }
    
    if state == 2 {
        let pending_cnt = my_orders.pending_count();
        if pending_cnt == 0 {
            state = 0;
            sell_triggered = false;
            cluster_price = 0;
            cluster_volume = 0;
            buy_back_price = 0;
            buy_back_amount = 0;
        }
    }
}