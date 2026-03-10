let initialized = false;
let lot_size_percent = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size_percent = rng.rand_int(40, 50);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let deviation = abs_val(market.price - market.ma_20);
    let atr_threshold = market.atr_14 * 3 / 2;
    
    if deviation > atr_threshold && market.price > market.ma_20 && account.stock > 0 && market.price > account.avg_cost {
        let sell_amount = account.stock * lot_size_percent / 100;
        if sell_amount > 0 {
            let raw_price = ((market.price + 500_000) / 1_000_000) * 1_000_000;
            orders.submit_limit_sell(raw_price, sell_amount);
        }
    }
    
    if deviation > atr_threshold && market.price < market.ma_20 {
        let max_buy_shares = account.cash / market.price;
        let buy_amount = max_buy_shares * lot_size_percent / 100;
        if buy_amount > 0 {
            let raw_price = ((market.price + 500_000) / 1_000_000) * 1_000_000;
            orders.submit_limit_buy(raw_price, buy_amount);
        }
    }
}