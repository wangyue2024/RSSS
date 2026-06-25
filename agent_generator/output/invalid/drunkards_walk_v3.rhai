let initialized = false;
let base_lot = 0;
let current_lot = 0;
let max_lot = 0;
let last_fill_side = -1;
let last_fill_price = 0;
let last_was_loss = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = rng.rand_int(100, 500);
        current_lot = base_lot;
        max_lot = base_lot * 100;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if last_fill_side >= 0 {
        let avg = account.avg_cost;
        if avg > 0 {
            if last_fill_side == 0 {
                last_was_loss = market.price < avg;
            } else {
                last_was_loss = market.price > avg;
            }
        }
    }
    
    if last_was_loss {
        current_lot = current_lot * 2;
        if current_lot > max_lot {
            current_lot = max_lot;
        }
    } else {
        current_lot = base_lot;
    }
    
    let roll = rng.rand_int(0, 99);
    
    if roll < 5 {
        let qty = rng.rand_int(current_lot / 2, current_lot * 3 / 2);
        let order_type = rng.rand_int(0, 1);
        if order_type == 0 {
            orders.submit_market_buy(qty);
        } else {
            let offset = rng.rand_int(-50000, 50000);
            let price = market.price + offset;
            if price > 0 {
                orders.submit_limit_buy(price, qty);
            }
        }
    } else if roll > 95 {
        let qty = rng.rand_int(current_lot / 2, current_lot * 3 / 2);
        let order_type = rng.rand_int(0, 1);
        if order_type == 0 {
            orders.submit_market_sell(qty);
        } else {
            let offset = rng.rand_int(-50000, 50000);
            let price = market.price + offset;
            if price > 0 {
                orders.submit_limit_sell(price, qty);
            }
        }
    }
    
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let idx = fill_cnt - 1;
        last_fill_side = my_orders.fill_side(idx);
        last_fill_price = my_orders.fill_price(idx);
    }
}