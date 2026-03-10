let initialized = false;
let fomo_triggered = false;
let last_checked_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        last_checked_price = market.price;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if last_checked_price > 0 {
        let price_change_percent = ((market.price - last_checked_price) * 10000) / last_checked_price;
        if price_change_percent > 200 {
            fomo_triggered = true;
        }
    }
    
    if fomo_triggered {
        let buy_amount = (account.cash * 50) / 100 / market.price;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
        fomo_triggered = false;
        last_checked_price = market.price;
        return;
    }
    
    if market.buy_volume > 3 * market.sell_volume {
        let buy_amount = (account.cash * 10) / 100 / market.price;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
    }
    
    if account.stock > 0 && market.price > account.avg_cost {
        let sell_amount = (account.stock * 10) / 100;
        if sell_amount > 0 {
            orders.submit_market_sell(sell_amount);
        }
    }
    
    last_checked_price = market.price;
}