let buy_history = [];
let sell_history = [];

fn on_tick() {
    if !market.trading_enabled { return; }
    
    buy_history.push(market.buy_volume);
    sell_history.push(market.sell_volume);
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if buy_history.len() > 5 {
        buy_history.remove(0);
        sell_history.remove(0);
    }
    
    if buy_history.len() == 5 {
        let old_buy = buy_history[0];
        let old_sell = sell_history[0];
        if old_buy >= 3 * old_sell {
            let amount = 100;
            if account.cash >= market.price * amount {
                orders.submit_market_buy(amount);
            }
        }
    }
}