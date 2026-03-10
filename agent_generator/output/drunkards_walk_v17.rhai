fn on_tick() {
    if !market.trading_enabled { return; }
    
    // Cancel orders older than 3 ticks
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let placed = my_orders.pending_placed_tick(i);
        if (market.tick - placed) > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    // Random trade decision
    let roll = rng.rand_int(0, 99);
    let buy_chance = 5;
    let sell_chance = 4;
    
    if roll < buy_chance {
        // Random buy
        let offset = rng.rand_int(-2000, 2000);
        let price = market.price + offset;
        if price < 1 { price = 1; }
        let amount = rng.rand_int(1, 50);
        orders.submit_limit_buy(price, amount);
    } else if roll > (99 - sell_chance) {
        // Random sell
        let offset = rng.rand_int(-2000, 2000);
        let price = market.price + offset;
        if price < 1 { price = 1; }
        let amount = rng.rand_int(1, 50);
        orders.submit_limit_sell(price, amount);
    }
}