let initialized = false;
let order_size = 0;
let panic_threshold = 0;
let tick_counter = 0;

fn on_tick() {
    if !initialized {
        order_size = rng.rand_int(20, 100);
        panic_threshold = -1 * rng.rand_int(10000, 100000);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    tick_counter += 1;
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let placed = my_orders.pending_placed_tick(i);
        if market.tick - placed > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    if my_orders.pending_count() == 0 {
        if market.rsi_14 < 3000 {
            let buy_price = market.price * 99 / 100;
            let cost = buy_price * order_size;
            if cost <= account.cash {
                orders.submit_limit_buy(buy_price, order_size);
            }
        } else if market.rsi_14 > 7000 && account.stock >= order_size {
            let sell_price = market.price * 101 / 100;
            if sell_price > account.avg_cost {
                orders.submit_limit_sell(sell_price, order_size);
            }
        }
    }
}