let entered = false;
let take_profit_order_id = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    // Cancel any existing orders
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    take_profit_order_id = 0;
    
    // Random entry once
    if !entered {
        if rng.rand_bool(2) {
            let max_shares = account.cash / market.price;
            if max_shares > 0 {
                let buy_amount = rng.rand_int(1, max_shares);
                orders.submit_market_buy(buy_amount);
                entered = true;
            }
        }
    }
    
    // Place take-profit order if we have stock && price > avg_cost
    if entered && account.stock > 0 && market.price > account.avg_cost {
        let take_profit_price = account.avg_cost * 105 / 100;
        take_profit_order_id = orders.submit_limit_sell(take_profit_price, account.stock);
    }
}