let initialized = false;
let base_order_size = 0;
let normal_order_prob = 0;
let fat_finger_prob = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_order_size = rng.rand_int(50, 200);
        normal_order_prob = rng.rand_int(1, 5);
        fat_finger_prob = 1;
    }
    
    if !market.trading_enabled { return; }
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let should_trade = rng.rand_bool(normal_order_prob);
    let fat_finger = rng.rand_bool(fat_finger_prob);
    
    if fat_finger {
        let fat_size = base_order_size * 100;
        let side = rng.rand_bool(50);
        
        if side && market.ask_price_0 > 0 {
            orders.submit_market_buy(fat_size);
        } else if !side && market.bid_price_0 > 0 {
            orders.submit_market_sell(fat_size);
        }
    } else if should_trade {
        let raw_price = market.price;
        let round_price = ((raw_price + 500_000) / 1_000_000) * 1_000_000;
        
        let side = rng.rand_bool(50);
        let spread = (market.ask_price_0 - market.bid_price_0).abs();
        let min_spread = 1000;
        
        if side && market.ask_price_0 > 0 {
            let buy_price = round_price - min_spread;
            if buy_price > 0 {
                orders.submit_limit_buy(buy_price, base_order_size);
            }
        } else if !side && market.bid_price_0 > 0 {
            let sell_price = round_price + min_spread;
            if sell_price > 0 {
                orders.submit_limit_sell(sell_price, base_order_size);
            }
        }
    }
}