let initialized = false;
let base_lot_size = 0;
let target_position = 0;
let tick_interval = 0;
let last_order_tick = 0;
let current_lot_size = 0;
let last_fill_price = 0;
let last_trade_loss = false;
let morning_session_end = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        base_lot_size = rng.rand_int(400, 600);
        target_position = rng.rand_int(40000, 60000);
        tick_interval = rng.rand_int(5, 15);
        current_lot_size = base_lot_size;
        last_order_tick = -tick_interval;
        morning_session_end = market.total_ticks / 5;
        initialized = true;
    }
    
    if market.tick >= morning_session_end {
        return;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if account.stock >= target_position {
        return;
    }
    
    if my_orders.fill_count() > 0 {
        let last_idx = my_orders.fill_count() - 1;
        last_fill_price = my_orders.fill_price(last_idx);
        
        if last_fill_price > market.price {
            last_trade_loss = true;
            current_lot_size = current_lot_size * 2;
            if current_lot_size > 5000 { current_lot_size = 5000; }
        } else {
            last_trade_loss = false;
            current_lot_size = base_lot_size;
        }
    }
    
    if market.tick - last_order_tick >= tick_interval {
        let remaining = target_position - account.stock;
        if remaining > 0 {
            let order_amount = current_lot_size;
            if order_amount > remaining { order_amount = remaining; }
            
            if market.bid_price_0 > 0 {
                let limit_price = market.bid_price_0;
                orders.submit_limit_buy(limit_price, order_amount);
                last_order_tick = market.tick;
            } else {
                orders.submit_market_buy(order_amount);
                last_order_tick = market.tick;
            }
        }
    }
}