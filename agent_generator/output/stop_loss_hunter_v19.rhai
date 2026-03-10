let initialized = false;
let lazy_counter = 0;
let lot_size = 0;
let cluster_threshold = 0;
let panic_multiplier = 0;
let volatility_threshold = 0;
let buy_back_level = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        lazy_counter = rng.rand_int(0, 49);
        
        let risk_seeking = rng.rand_bool(50);
        if risk_seeking {
            lot_size = rng.rand_int(25, 50);
        } else {
            lot_size = rng.rand_int(1, 5);
        }
        
        cluster_threshold = rng.rand_int(500, 2000);
        panic_multiplier = rng.rand_int(150, 300);
        volatility_threshold = rng.rand_int(200000, 500000);
        buy_back_level = rng.rand_int(98, 102);
    }
    
    if !market.trading_enabled { return; }
    
    lazy_counter += 1;
    if lazy_counter < 50 { return; }
    lazy_counter = 0;
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.std_dev > volatility_threshold {
        return;
    }
    
    let cluster_volume = 0;
    if market.bid_price_1 > 0 && market.bid_price_1 * 100 / market.price < 9980 {
        cluster_volume += market.bid_vol_1;
    }
    if market.bid_price_2 > 0 && market.bid_price_2 * 100 / market.price < 9980 {
        cluster_volume += market.bid_vol_2;
    }
    if market.bid_price_3 > 0 && market.bid_price_3 * 100 / market.price < 9980 {
        cluster_volume += market.bid_vol_3;
    }
    
    if cluster_volume > cluster_threshold && market.price > 0 {
        let shares_to_sell = account.cash * lot_size / (market.price * 100);
        if shares_to_sell > 0 {
            orders.submit_market_sell(shares_to_sell);
            
            let buy_price = market.price * buy_back_level / 100;
            let buy_amount = shares_to_sell * panic_multiplier / 100;
            if buy_amount > 0 {
                orders.submit_limit_buy(buy_price, buy_amount);
            }
        }
    }
}