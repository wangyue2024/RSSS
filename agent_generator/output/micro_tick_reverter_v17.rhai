let initialized = false;
let offset = 10;
let trade_amount = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        trade_amount = rng.rand_int(50, 200);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.history_len() < 1 { return; }
    
    let prev_price = market.history_price(0);
    let curr_price = market.price;
    
    if curr_price < prev_price {
        let bid_price = curr_price - offset + 1;
        let amt = trade_amount;
        if amt > 0 && bid_price > 0 {
            orders.submit_limit_buy(bid_price, amt);
        }
    } else if curr_price > prev_price {
        let ask_price = curr_price + offset;
        let amt = trade_amount;
        if amt > 0 && ask_price > 0 {
            orders.submit_limit_sell(ask_price, amt);
        }
    }
}