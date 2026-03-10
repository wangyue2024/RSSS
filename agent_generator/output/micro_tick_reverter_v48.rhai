let initialized = false;
let last_prices = [];
let ticks_processed = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
    }
    
    if market.tick >= market.total_ticks * 20 / 100 {
        return;
    }
    
    last_prices.push(market.price);
    if last_prices.len() > 6 {
        last_prices.remove(0);
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if last_prices.len() < 6 {
        return;
    }
    
    let delayed_price = last_prices[0];
    let prev_delayed_price = last_prices[1];
    
    let price_5_ago = last_prices[last_prices.len() - 6];
    let current_price = market.price;
    
    if price_5_ago != 0 {
        let price_change = (current_price - price_5_ago) * 10000 / price_5_ago;
        if price_change > 200 {
            orders.submit_market_buy(100);
            return;
        }
    }
    
    if delayed_price < prev_delayed_price {
        let buy_price = delayed_price * 9995 / 10000;
        orders.submit_limit_buy(buy_price, 100);
    } else if delayed_price > prev_delayed_price && account.stock > 0 {
        let sell_price = delayed_price * 10005 / 10000;
        orders.submit_limit_sell(sell_price, 100);
    }
}