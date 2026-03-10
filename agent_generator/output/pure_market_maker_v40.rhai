let price_history = [];
let last_delayed_price = 0;
let spread_micros = 10_000;
let order_size = 100;

fn round_to_dollar(micros) {
    let remainder = micros % 1_000_000;
    if remainder >= 500_000 {
        micros + (1_000_000 - remainder)
    } else {
        micros - remainder
    }
}

fn on_tick() {
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if price_history.len() < 5 {
        return;
    }
    
    let delayed_price = price_history[0];
    if delayed_price == last_delayed_price && my_orders.pending_count() > 0 {
        return;
    }
    last_delayed_price = delayed_price;
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let buy_price_raw = delayed_price - (delayed_price * spread_micros) / 1_000_000;
    let sell_price_raw = delayed_price + (delayed_price * spread_micros) / 1_000_000;
    
    let buy_price = round_to_dollar(buy_price_raw);
    let sell_price = round_to_dollar(sell_price_raw);
    
    if buy_price > 0 && account.cash >= buy_price * order_size {
        orders.submit_limit_buy(buy_price, order_size);
    }
    
    if sell_price > 0 && account.stock >= order_size {
        orders.submit_limit_sell(sell_price, order_size);
    }
}