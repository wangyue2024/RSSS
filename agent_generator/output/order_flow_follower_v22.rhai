let initialized = false;
let panic_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(10_000, 100_000);
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
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    if account.stock > 0 && market.price > account.avg_cost {
        let sell_price = market.bid_price_0;
        if sell_price > 0 {
            orders.submit_limit_sell(sell_price, account.stock);
        }
    }
    
    if market.buy_volume >= 3 * market.sell_volume {
        let buy_amount = 100;
        let buy_price = market.ask_price_0;
        if buy_price > 0 {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    }
}