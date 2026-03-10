let initialized = false;
let spread_micros = 0;
let order_amount = 0;
let diamond_hands_active = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        spread_micros = rng.rand_int(10_000, 50_000);
        order_amount = rng.rand_int(10, 50);
        diamond_hands_active = true;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_price = market.price;
    
    let raw_buy_price = current_price - spread_micros;
    let raw_sell_price = current_price + spread_micros;
    
    let round_buy_price = ((raw_buy_price + 500_000) / 1_000_000) * 1_000_000;
    let round_sell_price = ((raw_sell_price + 500_000) / 1_000_000) * 1_000_000;
    
    if round_buy_price > 0 {
        let cost = round_buy_price * order_amount;
        if account.cash >= cost {
            orders.submit_limit_buy(round_buy_price, order_amount);
        }
    }
    
    if diamond_hands_active && market.price > account.avg_cost {
        if account.stock >= order_amount {
            orders.submit_limit_sell(round_sell_price, order_amount);
        }
    }
}