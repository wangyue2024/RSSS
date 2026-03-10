let initialized = false;
let base_lot_size = 100;
let current_lot_size = 100;
let spread_bps = 50;
let recent_prices = [];
let last_trade_was_loss = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = 100;
        current_lot_size = 100;
        spread_bps = rng.rand_int(40, 80);
    }
    
    if !market.trading_enabled { return; }
    
    recent_prices.push(market.price);
    if recent_prices.len() > 10 {
        recent_prices.remove(0);
    }
    
    let fomo_triggered = false;
    if recent_prices.len() >= 5 {
        let old_price = recent_prices[0];
        let price_change = abs_val(market.price - old_price) * 10000 / old_price;
        if price_change > 200 {
            fomo_triggered = true;
        }
    }
    
    if last_trade_was_loss {
        current_lot_size = base_lot_size * 2;
    } else {
        current_lot_size = base_lot_size;
    }
    
    if account.stock > 0 && market.price < account.avg_cost {
        last_trade_was_loss = true;
    } else {
        last_trade_was_loss = false;
    }
    
    if fomo_triggered {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        if current_lot_size > 0 {
            orders.submit_market_buy(current_lot_size);
        }
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let spread = market.price * spread_bps / 10000;
    let buy_price = market.price - spread;
    let sell_price = market.price + spread;
    
    if buy_price > 0 && current_lot_size > 0 {
        orders.submit_limit_buy(buy_price, current_lot_size);
    }
    if sell_price > 0 && current_lot_size > 0 {
        orders.submit_limit_sell(sell_price, current_lot_size);
    }
}