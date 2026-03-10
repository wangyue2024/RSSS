let initialized = false;
let lot_size = 0;
let panic_threshold = 0;
let stop_offset = 0;
let std_dev_max = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let five_percent = account.total_equity * 5 / 100;
        let max_shares = five_percent / market.price;
        lot_size = rng.rand_int(1, max_shares);
        panic_threshold = -rng.rand_int(1000, 5000);
        stop_offset = rng.rand_int(10000, 30000);
        std_dev_max = rng.rand_int(20000, 50000);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed = my_orders.pending_placed_tick(i);
        if market.tick - placed > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if account.stock > 0 {
        if account.unrealized_pnl <= panic_threshold {
            orders.submit_market_sell(account.stock);
            return;
        }
        
        let stop_price = account.avg_cost - stop_offset;
        if market.price <= stop_price {
            orders.submit_market_sell(account.stock);
            return;
        }
    }
    
    if market.std_dev > std_dev_max {
        return;
    }
    
    if account.stock == 0 && my_orders.pending_count() == 0 {
        if market.price > market.high_20 {
            let buy_price = market.ask_price_0;
            orders.submit_limit_buy(buy_price, lot_size);
        }
    }
}