let initialized = false;
let spread_micros = 0;
let trade_amount = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        spread_micros = rng.rand_int(1000, 5000);
        trade_amount = rng.rand_int(10, 100);
    }
    
    if !market.trading_enabled {
        return;
    }
    
    let current_price = market.price;
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let bid_price = current_price - spread_micros + 1;
    if bid_price > 0 && account.cash >= bid_price * trade_amount {
        orders.submit_limit_buy(bid_price, trade_amount);
    }
    
    let ask_price = current_price + spread_micros;
    if account.stock >= trade_amount && ask_price > account.avg_cost {
        orders.submit_limit_sell(ask_price, trade_amount);
    }
}