let initialized = false;
let base_trade_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_trade_size = rng.rand_int(20, 100);
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= market.total_ticks * 1 / 5 {
        return;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let rsi = market.rsi_14;
    
    if rsi < 3000 {
        let bid_price = market.bid_price_0 - 5000;
        if bid_price > 0 {
            let buy_price = bid_price + 1;
            let buy_amount = base_trade_size;
            if account.cash >= buy_price * buy_amount {
                orders.submit_limit_buy(buy_price, buy_amount);
            }
        }
    } else if rsi > 7000 && account.stock > 0 {
        let ask_price = market.ask_price_0 + 5000;
        let sell_amount = base_trade_size;
        if sell_amount > account.stock {
            sell_amount = account.stock;
        }
        if sell_amount > 0 {
            orders.submit_limit_sell(ask_price, sell_amount);
        }
    }
}