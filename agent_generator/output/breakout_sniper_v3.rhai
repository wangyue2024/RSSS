let initialized = false;
let TRADE_SHARES = 1000;
let STOP_LOSS_TICKS = 5;
let CANCEL_AFTER_TICKS = 3;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let current_price = market.price;
    let high_20 = market.high_20;
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick >= CANCEL_AFTER_TICKS {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if account.stock > 0 {
        let stop_price = account.avg_cost - (STOP_LOSS_TICKS * 10000);
        if current_price < stop_price {
            orders.submit_market_sell(account.stock);
        }
    }
    
    if current_price > high_20 && account.stock == 0 {
        let ask_price = market.ask_price_0;
        let buy_price = ask_price + 5000;
        orders.submit_limit_buy(buy_price, TRADE_SHARES);
    }
}