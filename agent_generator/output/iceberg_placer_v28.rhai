let initialized = false;
let total_to_sell = 0;
let iceberg_size = 0;
let remaining_to_sell = 0;
let stop_loss_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        total_to_sell = 50000;
        iceberg_size = 100;
        remaining_to_sell = total_to_sell;
        stop_loss_threshold = -rng.rand_int(10000, 50000);
    }
    
    if !market.trading_enabled { return; }
    
    let i = 0;
    let pending_count = my_orders.pending_count();
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let j = 0;
        while j < fill_cnt {
            remaining_to_sell -= my_orders.fill_amount(j);
            j += 1;
        }
    }
    
    if remaining_to_sell > 0 {
        let order_amount = if iceberg_size < remaining_to_sell { iceberg_size } else { remaining_to_sell };
        if market.ask_price_0 > 0 {
            orders.submit_limit_sell(market.ask_price_0, order_amount);
        }
    }
}