let initialized = false;
let breakout_buy_triggered = false;
let pending_buy_id = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let order_id = my_orders.pending_id(i);
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick >= 3 {
            orders.submit_cancel(order_id);
        }
        i += 1;
    }
    
    if my_orders.pending_count() == 0 {
        pending_buy_id = 0;
    }
    
    if !breakout_buy_triggered && market.price > market.high_20 && pending_buy_id == 0 {
        let buy_amount = (account.cash * 80 / 100) / market.ask_price_0;
        if buy_amount > 0 {
            let order_id = orders.submit_limit_buy(market.ask_price_0, buy_amount);
            pending_buy_id = order_id;
            breakout_buy_triggered = true;
        }
    }
    
    if account.stock > 0 && market.price > account.avg_cost && my_orders.pending_count() == 0 {
        orders.submit_limit_sell(market.bid_price_0, account.stock);
    }
}