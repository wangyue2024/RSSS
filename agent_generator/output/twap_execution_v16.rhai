let initialized = false;
let target_position = 50_000;
let base_slice = 500;
let current_slice = base_slice;
let ticks_between_orders = 5;
let last_order_tick = -999;
let last_fill_price = 0;
let avg_cost_at_last_fill = 0;
let panic_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(10000, 100000);
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel any pending order older than 3 ticks
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
    
    // Panic check: stop-loss
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    // Martingale sizing logic
    if last_fill_price > 0 && account.avg_cost > 0 {
        // Check if last trade was a loss
        if market.price < last_fill_price {
            current_slice = current_slice * 2;
        } else {
            current_slice = base_slice;
        }
    }
    
    // TWAP execution
    if market.tick - last_order_tick >= ticks_between_orders {
        let remaining = target_position - account.stock;
        if remaining > 0 {
            let slice = current_slice;
            if slice > remaining {
                slice = remaining;
            }
            if slice > 0 {
                orders.submit_limit_buy(market.bid_price_0, slice);
                last_order_tick = market.tick;
            }
        }
    }
    
    // Update last fill info for martingale
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        last_fill_price = my_orders.fill_price(fill_cnt - 1);
        avg_cost_at_last_fill = account.avg_cost;
    }
}