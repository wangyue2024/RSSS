let initialized = false;
let next_action_tick = 0;
let trade_size = 0;

fn round_to_dollar(price) {
    let remainder = price % 1_000_000;
    let base = price - remainder;
    if remainder >= 500_000 {
        base + 1_000_000
    } else {
        base
    }
}

fn on_tick() {
    if !initialized {
        initialized = true;
        next_action_tick = market.tick + 50;
        trade_size = rng.rand_int(20, 100);
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick < next_action_tick { return; }
    
    next_action_tick = market.tick + 50;
    trade_size = rng.rand_int(20, 100);
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let rsi = market.rsi_14;
    let current_price = market.price;
    
    if rsi < 3000 && account.cash > 1_000_000 {
        let buy_price = round_to_dollar(current_price * 99 / 100);
        if buy_price <= 0 { buy_price = 1_000_000; }
        orders.submit_limit_buy(buy_price, trade_size);
    } else if rsi > 7000 && account.stock > 0 {
        let sell_price = round_to_dollar(current_price * 101 / 100);
        if sell_price <= 0 { sell_price = 1_000_000; }
        let sell_amount = if trade_size > account.stock { account.stock } else { trade_size };
        orders.submit_limit_sell(sell_price, sell_amount);
    }
}