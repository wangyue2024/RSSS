let initialized = false;
let risk_percentage = 0;
let lot_size_multiplier = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        risk_percentage = rng.rand_int(40, 50);
        lot_size_multiplier = rng.rand_int(2, 5);
    }

    if !market.trading_enabled { return; }

    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let buy_vol = market.buy_volume;
    let sell_vol = market.sell_volume;

    if buy_vol > 3 * sell_vol {
        let max_shares = account.cash / market.price;
        let target_shares = max_shares * risk_percentage / 100;
        let lot_size = target_shares * lot_size_multiplier;
        
        if lot_size > 0 {
            orders.submit_market_buy(lot_size);
        }
    }

    if sell_vol > 3 * buy_vol && account.stock > 0 {
        let target_shares = account.stock * risk_percentage / 100;
        let lot_size = target_shares * lot_size_multiplier;
        
        if lot_size > 0 {
            orders.submit_market_sell(lot_size);
        }
    }
}