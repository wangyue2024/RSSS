let initialized = false;
let STOP_LOSS_TICKS = 5;
let ROUND_FACTOR = 1_000_000;
let BUY_AMOUNT = 100;

fn round_to_dollar(price) {
    ((price + ROUND_FACTOR / 2) / ROUND_FACTOR) * ROUND_FACTOR
}

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel orders older than 3 ticks
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    // Breakout buy condition
    if market.price > market.high_20 && account.stock == 0 {
        let buy_price = round_to_dollar(market.price);
        if buy_price < market.price {
            buy_price = buy_price + ROUND_FACTOR;
        }
        orders.submit_limit_buy(buy_price, BUY_AMOUNT);
    }
    
    // Stop-loss sell if holding stock
    if account.stock > 0 {
        let stop_price = account.avg_cost - (STOP_LOSS_TICKS * ROUND_FACTOR / 100);
        let sell_price = round_to_dollar(stop_price);
        if sell_price > 0 {
            orders.submit_limit_sell(sell_price, account.stock);
        }
    }
}