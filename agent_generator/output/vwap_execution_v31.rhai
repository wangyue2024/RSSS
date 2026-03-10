let initialized = false;
let base_lot = 100;
let martingale_factor = 1;
let total_target = 10000;
let bought_so_far = 0;
let last_fill_price = 0;
let morning_ticks = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = rng.rand_int(80, 120);
        total_target = rng.rand_int(8000, 12000);
        morning_ticks = market.total_ticks * 20 / 100;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let fill_cnt = my_orders.fill_count();
    i = 0;
    while i < fill_cnt {
        let fill_side = my_orders.fill_side(i);
        if fill_side == 0 {
            let fill_amount = my_orders.fill_amount(i);
            bought_so_far = bought_so_far + fill_amount;
            last_fill_price = my_orders.fill_price(i);
        }
        i += 1;
    }
    
    if last_fill_price > 0 {
        if market.price < last_fill_price {
            martingale_factor = martingale_factor * 2;
        } else {
            martingale_factor = 1;
        }
        last_fill_price = 0;
    }
    
    if market.tick < morning_ticks && bought_so_far < total_target {
        let volume_factor = if market.volume > 100000 { 2 } else { 1 };
        let current_lot = base_lot * volume_factor * martingale_factor;
        
        let remaining = total_target - bought_so_far;
        if current_lot > remaining {
            current_lot = remaining;
        }
        
        if current_lot > 0 && market.ask_price_0 > 0 {
            orders.submit_limit_buy(market.ask_price_0, current_lot);
        }
    }
}