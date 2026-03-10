let stop_loss_offset = 50000;
let initialized = false;
let morning_ticks = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        morning_ticks = market.total_ticks / 5;
    }
    
    if !market.trading_enabled { return; }
    
    let is_morning = market.tick < morning_ticks;
    if !is_morning {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    if account.stock > 0 {
        let stop_price = account.avg_cost - stop_loss_offset;
        if market.price < stop_price {
            orders.submit_market_sell(account.stock);
        }
    } else {
        if market.price > market.high_20 {
            let round_price = ((market.price + 500000) / 1000000) * 1000000;
            let buy_amount = 100;
            orders.submit_limit_buy(round_price, buy_amount);
        }
    }
}