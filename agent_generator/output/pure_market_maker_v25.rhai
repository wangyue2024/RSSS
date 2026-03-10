let initialized = false;
let lazy_interval = 50;
let spread_micros = 20_000;
let order_amount = 100;

fn round_to_dollar(price) {
    ((price + 500_000) / 1_000_000) * 1_000_000
}

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled {
        return;
    }
    
    if market.tick % lazy_interval != 0 {
        return;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let mid_price = market.price;
    let buy_price = round_to_dollar(mid_price - spread_micros / 2);
    let sell_price = round_to_dollar(mid_price + spread_micros / 2);
    
    let adjusted_buy_price = buy_price + 1;
    
    if account.cash >= adjusted_buy_price * order_amount {
        orders.submit_limit_buy(adjusted_buy_price, order_amount);
    }
    
    if account.stock >= order_amount {
        orders.submit_limit_sell(sell_price, order_amount);
    }
}