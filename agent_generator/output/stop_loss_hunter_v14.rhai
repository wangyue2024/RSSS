let initialized = false;
let cluster_threshold = 0;
let push_aggressiveness = 0;
let buyback_discount = 0;
let round_mod = 1_000_000;
let cooling_ticks = 0;
let last_push_tick = -100;

fn round_to_nearest_dollar(price) {
    ((price + 500_000) / round_mod) * round_mod
}

fn on_tick() {
    if !initialized {
        initialized = true;
        cluster_threshold = rng.rand_int(5_000, 20_000);
        push_aggressiveness = rng.rand_int(300, 700);
        buyback_discount = rng.rand_int(50, 200);
    }

    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    if (current_tick - last_push_tick) < cooling_ticks {
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let detect_cluster = false;
    let cluster_price = 0;
    let cluster_volume = 0;
    
    let price = market.price;
    
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
        
        if bid_price > 0 && bid_vol > cluster_threshold {
            let price_diff_percent = ((price - bid_price) * 10_000) / price;
            if price_diff_percent < 200 && price_diff_percent > 0 {
                detect_cluster = true;
                cluster_price = bid_price;
                cluster_volume = bid_vol;
                break;
            }
        }
        i += 1;
    }
    
    if detect_cluster && cluster_price > 0 {
        let sell_amount = (cluster_volume * push_aggressiveness) / 1000;
        if sell_amount > 0 {
            orders.submit_market_sell(sell_amount);
            
            let buyback_price = (cluster_price * (10_000 - buyback_discount)) / 10_000;
            let rounded_buyback = round_to_nearest_dollar(buyback_price);
            let buyback_amount = (sell_amount * 120) / 100;
            
            orders.submit_limit_buy(rounded_buyback, buyback_amount);
            
            last_push_tick = current_tick;
            cooling_ticks = rng.rand_int(3, 8);
        }
    } else {
        let spread = market.ask_price_0 - market.bid_price_0;
        if spread > 2_000_000 && market.volume > 100_000 {
            let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
            let rounded_sell = round_to_nearest_dollar(mid_price + 500_000);
            let rounded_buy = round_to_nearest_dollar(mid_price - 500_000);
            
            if rounded_sell > market.ask_price_0 {
                orders.submit_limit_sell(rounded_sell, 500);
            }
            if rounded_buy < market.bid_price_0 {
                orders.submit_limit_buy(rounded_buy, 500);
            }
        }
    }
}