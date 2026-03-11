let initialized = false;
let fair_value = 0;
let price_history = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = rng.rand_int(95_000_000, 105_000_000);
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    let fomo_triggered = false;
    if price_history.len() == 5 {
        let min_price = 0;
        for p in price_history {
            if min_price == 0 || p < min_price {
                min_price = p;
            }
        }
        let threshold = min_price * 102 / 100;
        if market.price > threshold {
            fomo_triggered = true;
        }
    }
    
    let i = 0;
    while i < my_orders.pending_count() {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if fomo_triggered {
        let fomo_amount = 100;
        orders.submit_market_buy(fomo_amount);
        return;
    }
    
    let buy_amount = 0;
    let bid_price = 0;
    
    let threshold1 = fair_value * 95 / 100;
    let threshold2 = fair_value * 90 / 100;
    
    if market.price < threshold2 {
        buy_amount = 500;
        bid_price = market.bid_price_0;
    } else if market.price < threshold1 {
        buy_amount = 100;
        bid_price = market.bid_price_0;
    }
    
    if buy_amount > 0 && market.bid_price_0 > 0 {
        let my_bid = bid_price + 1;
        if my_bid < threshold2 {
            orders.submit_limit_buy(my_bid, buy_amount);
        }
    }
}