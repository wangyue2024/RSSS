let price_history = [];
let initialized = false;
let base_spread_bps = 50;
let vol_factor = 200;
let order_size = 100;
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread_bps = rng.rand_int(40, 60);
        vol_factor = rng.rand_int(150, 250);
        order_size = rng.rand_int(80, 120);
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > 10 {
        price_history.remove(0);
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if price_history.len() >= 5 {
        let old_idx = price_history.len() - 5;
        let old_price = price_history[old_idx];
        let current_price = market.price;
        
        if old_price > 0 {
            let change_bps = (current_price - old_price) * 10000 / old_price;
            if change_bps > 200 || change_bps < -200 {
                fomo_triggered = true;
            }
        }
    }
    
    if fomo_triggered {
        if market.buy_volume > market.sell_volume * 3 / 2 {
            orders.submit_market_buy(order_size);
        }
        fomo_triggered = false;
        return;
    }
    
    let mid_price = market.price;
    if market.bid_price_0 > 0 && market.ask_price_0 > 0 {
        mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    }
    
    let volatility_component = market.std_dev * vol_factor / 10000;
    let half_spread_bps = base_spread_bps + volatility_component;
    let half_spread_micros = mid_price * half_spread_bps / 10000;
    
    if half_spread_micros < 100 { half_spread_micros = 100; }
    if half_spread_micros > 50000 { half_spread_micros = 50000; }
    
    let bid_price = mid_price - half_spread_micros + 1;
    let ask_price = mid_price + half_spread_micros;
    
    if bid_price > 0 {
        orders.submit_limit_buy(bid_price, order_size);
    }
    
    if ask_price > 0 {
        orders.submit_limit_sell(ask_price, order_size);
    }
}