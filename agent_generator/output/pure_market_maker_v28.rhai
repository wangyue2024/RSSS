let initialized = false;
let spread = 0;
let order_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        spread = rng.rand_int(50000, 200000);
        order_size = rng.rand_int(5, 20);
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let buy_price = market.price - spread;
    let sell_price = market.price + spread;
    
    if buy_price > 0 {
        let max_buy = account.cash / buy_price;
        if max_buy > order_size {
            orders.submit_limit_buy(buy_price, order_size);
        } else if max_buy > 0 {
            orders.submit_limit_buy(buy_price, max_buy);
        }
    }
    
    if account.stock > 0 && sell_price > account.avg_cost {
        let sell_amount = if account.stock > order_size { order_size } else { account.stock };
        if sell_amount > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}