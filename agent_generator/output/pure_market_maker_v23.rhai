let initialized = false;
let lot_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let five_percent_capital = account.total_equity * 5 / 100;
        let max_shares = five_percent_capital / market.price;
        if max_shares > 0 {
            lot_size = rng.rand_int(1, max_shares);
        } else {
            lot_size = 1;
        }
    }
    
    if !market.trading_enabled { return; }
    
    let time_active = market.tick * 100 / market.total_ticks;
    if time_active >= 20 { return; }
    
    let std_dev_threshold = market.price * 2 / 100;
    if market.std_dev > std_dev_threshold { return; }
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_price = market.price;
    let spread = current_price * 50 / 10000;
    
    let rounded_price = ((current_price + 500_000) / 1_000_000) * 1_000_000;
    
    let buy_price = ((rounded_price - spread + 500_000) / 1_000_000) * 1_000_000;
    let sell_price = ((rounded_price + spread + 500_000) / 1_000_000) * 1_000_000;
    
    if buy_price > 0 && account.cash >= buy_price * lot_size {
        orders.submit_limit_buy(buy_price, lot_size);
    }
    
    if account.stock >= lot_size {
        orders.submit_limit_sell(sell_price, lot_size);
    }
}