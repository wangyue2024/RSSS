let initialized = false;
let lot_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size = rng.rand_int(25, 50);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let buy_vol = market.buy_volume;
    let sell_vol = market.sell_volume;
    
    if buy_vol > sell_vol * 3 {
        let cash_to_use = account.cash * lot_size / 100;
        let shares_to_buy = cash_to_use / market.price;
        if shares_to_buy > 0 {
            orders.submit_market_buy(shares_to_buy);
        }
    } else if sell_vol > buy_vol * 3 && account.stock > 0 {
        let shares_to_sell = account.stock * lot_size / 100;
        if shares_to_sell > 0 {
            orders.submit_market_sell(shares_to_sell);
        }
    }
}