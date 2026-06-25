let initialized = false;
let trade_cooldown = 50;
let last_trade_tick = -100;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick % trade_cooldown != 0 {
        return;
    }
    
    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let deviation = abs_val(market.price - market.ma_20);
    let atr_threshold = (market.atr_14 * 150) / 100;
    
    if deviation > atr_threshold {
        if market.price > market.ma_20 {
            if market.price > account.avg_cost && account.stock > 0 {
                let sell_amount = account.stock / 4;
                if sell_amount > 0 {
                    orders.submit_limit_sell(market.price, sell_amount);
                }
            }
        } else {
            let buy_amount = (account.cash / 4) / market.price;
            if buy_amount > 0 {
                orders.submit_limit_buy(market.price, buy_amount);
            }
        }
    }
    
    last_trade_tick = market.tick;
}