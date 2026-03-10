let initialized = false;

fn round_to_dollar(price) {
    let remainder = price % 1_000_000;
    if remainder >= 500_000 {
        price - remainder + 1_000_000
    } else {
        price - remainder
    }
}

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let rand = rng.rand_int(0, 99);
    
    if rand < 5 {
        let offset = rng.rand_int(-500_000, 500_000);
        let raw_price = market.price + offset;
        let price = round_to_dollar(raw_price);
        if price <= 0 { return; }
        let max_affordable = account.cash / price;
        if max_affordable <= 0 { return; }
        let qty = rng.rand_int(1, max_affordable);
        if qty > 0 {
            orders.submit_limit_buy(price, qty);
        }
    } else if rand > 95 {
        let offset = rng.rand_int(-500_000, 500_000);
        let raw_price = market.price + offset;
        let price = round_to_dollar(raw_price);
        if price <= 0 { return; }
        let max_sellable = account.stock;
        if max_sellable <= 0 { return; }
        let qty = rng.rand_int(1, max_sellable);
        if qty > 0 {
            orders.submit_limit_sell(price, qty);
        }
    }
}