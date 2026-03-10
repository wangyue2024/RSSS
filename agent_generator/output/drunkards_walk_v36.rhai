let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let roll = rng.rand_int(0, 99);
    
    if roll < 5 {
        let buy_qty = rng.rand_int(1, 10);
        let price_offset = rng.rand_int(-50, 50);
        let buy_price = market.price + price_offset * 1000;
        if buy_price < 1 { buy_price = 1; }
        orders.submit_limit_buy(buy_price, buy_qty);
    } else if roll > 95 && account.stock > 0 {
        if market.price > account.avg_cost {
            let sell_qty_max = account.stock;
            let sell_qty = rng.rand_int(1, 10);
            let final_qty = if sell_qty > sell_qty_max { sell_qty_max } else { sell_qty };
            let price_offset = rng.rand_int(0, 100);
            let sell_price = market.price + price_offset * 1000;
            orders.submit_limit_sell(sell_price, final_qty);
        }
    }
}