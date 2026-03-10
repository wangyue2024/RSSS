let initialized = false;
let mode = "normal";
let attack_triggered = false;
let sell_volume = 0;
let buy_back_price = 0;
let attack_price = 0;
let support_level = 0;
let base_bid = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        mode = "normal";
        attack_triggered = false;
        sell_volume = 0;
        buy_back_price = 0;
        attack_price = 0;
        support_level = 0;
        base_bid = 0;
    }
    
    if !market.trading_enabled { return; }
    
    let current_price = market.price;
    let current_tick = market.tick;
    
    if mode == "normal" {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        support_level = market.low_20;
        let price_distance = current_price - support_level;
        
        if price_distance > 0 && price_distance < current_price * 2 / 100 {
            let cluster_volume = 0;
            let j = 0;
            while j < 5 {
                let bid_price = market["bid_price_" + j];
                let bid_vol = market["bid_vol_" + j];
                if bid_price > 0 && bid_price <= support_level && bid_price >= support_level - current_price * 1 / 100 {
                    cluster_volume += bid_vol;
                }
                j += 1;
            }
            
            if cluster_volume > 10000 && account.stock > 0 {
                sell_volume = account.stock;
                if sell_volume > cluster_volume * 120 / 100 {
                    sell_volume = cluster_volume * 120 / 100;
                }
                
                if sell_volume > 0 {
                    orders.submit_market_sell(sell_volume);
                    attack_triggered = true;
                    attack_price = current_price;
                    buy_back_price = support_level - current_price * 3 / 100;
                    if buy_back_price < support_level * 98 / 100 {
                        buy_back_price = support_level * 98 / 100;
                    }
                    mode = "waiting";
                }
            }
        }
        
        if mode == "normal" {
            base_bid = market.bid_price_0 - current_price * 5 / 1000;
            if base_bid < support_level {
                base_bid = support_level + current_price * 1 / 100;
            }
            if base_bid < 1 { base_bid = 1; }
            
            let bid_price = base_bid + 1;
            let buy_amount = account.cash / bid_price;
            if buy_amount > 0 && bid_price > 0 {
                orders.submit_limit_buy(bid_price, buy_amount);
            }
        }
    } else if mode == "waiting" {
        if attack_triggered && current_price <= buy_back_price {
            let bid_price = buy_back_price + 1;
            let buy_amount = sell_volume * 110 / 100;
            let max_affordable = account.cash / bid_price;
            if buy_amount > max_affordable {
                buy_amount = max_affordable;
            }
            if buy_amount > 0 && bid_price > 0 {
                orders.submit_limit_buy(bid_price, buy_amount);
                attack_triggered = false;
                mode = "normal";
            }
        }
        
        if current_tick % 10 == 0 {
            mode = "normal";
            attack_triggered = false;
        }
    }
}