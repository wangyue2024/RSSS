let initialized = false;
let decision_tick = 0;
let vwap_threshold = 0;
let order_amount = 0;
let last_buy_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        vwap_threshold = rng.rand_int(5000, 20000);
        order_amount = rng.rand_int(10, 50) * 100;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed = my_orders.pending_placed_tick(i);
        if current_tick - placed >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if current_tick % 50 != 0 { return; }
    
    let current_price = market.price;
    let vwap = market.vwap;
    let price_diff = vwap - current_price;
    
    if account.stock == 0 {
        if price_diff > vwap_threshold {
            let buy_price = current_price + 1;
            let max_price = vwap - 1;
            if buy_price > max_price {
                buy_price = max_price;
            }
            if buy_price > 0 {
                orders.submit_limit_buy(buy_price, order_amount);
                last_buy_price = buy_price;
            }
        }
    } else {
        let sell_threshold = last_buy_price + vwap_threshold / 10;
        if current_price >= sell_threshold {
            orders.submit_limit_sell(vwap, account.stock);
        }
    }
}