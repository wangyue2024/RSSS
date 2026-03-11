let initialized = false;
let last_trade_tick = -100;
let price_5_ticks_ago = 0;
let rsi_5_ticks_ago = 0;
let price_history = [];
let rsi_history = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        price_history = [];
        rsi_history = [];
        last_trade_tick = -100;
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    rsi_history.push(market.rsi_14);
    
    if price_history.len() > 5 {
        price_history.remove(0);
        rsi_history.remove(0);
    }
    
    if price_history.len() < 5 {
        return;
    }
    
    price_5_ticks_ago = price_history[0];
    rsi_5_ticks_ago = rsi_history[0];
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.tick - last_trade_tick < 30 {
        return;
    }
    
    if rsi_5_ticks_ago < 3000 {
        let buy_amount = rng.rand_int(20, 100);
        let limit_price = price_5_ticks_ago - (price_5_ticks_ago * rng.rand_int(10, 50) / 10000);
        
        if limit_price > 0 && account.cash >= limit_price * buy_amount {
            orders.submit_limit_buy(limit_price, buy_amount);
            last_trade_tick = market.tick;
        }
    } else if rsi_5_ticks_ago > 7000 && account.stock > 20 {
        let sell_amount = rng.rand_int(20, 100);
        let sell_size = if sell_amount > account.stock { account.stock } else { sell_amount };
        let limit_price = price_5_ticks_ago + (price_5_ticks_ago * rng.rand_int(10, 50) / 10000);
        
        if sell_size >= 20 {
            orders.submit_limit_sell(limit_price, sell_size);
            last_trade_tick = market.tick;
        }
    }
}