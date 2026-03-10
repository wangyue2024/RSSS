let initialized = false;
let recent_prices = [];
let fomo_triggered = false;
let min_spread = 100000;
let max_spread = 5000000;
let vol_multiplier = 20;
let order_amount = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        min_spread = rng.rand_int(80000, 150000);
        max_spread = rng.rand_int(4000000, 6000000);
        vol_multiplier = rng.rand_int(15, 30);
        order_amount = rng.rand_int(80, 120);
    }
    
    if !market.trading_enabled { 
        return; 
    }

    let current_price = market.price;
    recent_prices.push(current_price);
    if recent_prices.len() > 5 {
        recent_prices.remove(0);
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if recent_prices.len() >= 5 && !fomo_triggered {
        let old_price = recent_prices[0];
        let diff = abs_val(current_price - old_price);
        let threshold = old_price * 2 / 100;
        if diff > threshold {
            fomo_triggered = true;
            orders.submit_market_buy(order_amount);
            return;
        }
    }

    if fomo_triggered {
        fomo_triggered = false;
    }

    let volatility = market.std_dev;
    let spread_addition = volatility * vol_multiplier / 1000;
    let spread = min_spread + spread_addition;
    if spread > max_spread {
        spread = max_spread;
    }
    
    let half_spread = spread / 2;
    let bid_price = market.price - half_spread + 1;
    let ask_price = market.price + half_spread;

    if bid_price > 0 {
        orders.submit_limit_buy(bid_price, order_amount);
    }
    if ask_price > 0 {
        orders.submit_limit_sell(ask_price, order_amount);
    }
}