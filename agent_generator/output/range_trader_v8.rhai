let initialized = false;
let base_amount = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_amount = rng.rand_int(80, 120);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.high_20 == 0 || market.low_20 == 0 { return; }
    
    let spread = market.high_20 - market.low_20;
    if spread <= 0 { return; }
    
    let range_narrow = spread * 100 / market.price < 200;
    let amount = base_amount * (if range_narrow { 2 } else { 1 });
    
    let buy_offset = spread * 1 / 100;
    if buy_offset < 1 { buy_offset = 1; }
    let buy_price = market.low_20 + buy_offset;
    
    let sell_offset = spread * 1 / 100;
    if sell_offset < 1 { sell_offset = 1; }
    let sell_price = market.high_20 - sell_offset;
    
    if buy_price > 0 && buy_price < market.price && account.cash >= buy_price * amount {
        orders.submit_limit_buy(buy_price, amount);
    }
    
    if sell_price > 0 && sell_price > market.price && account.stock >= amount {
        orders.submit_limit_sell(sell_price, amount);
    }
}