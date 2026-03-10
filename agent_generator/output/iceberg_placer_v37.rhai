let initialized = false;
let total_target_sell = 0;
let small_order_size = 0;
let stop_loss_threshold = 0;
let last_placed_order_id = -1;
let panic_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        total_target_sell = account.stock;
        small_order_size = total_target_sell / 100;
        if small_order_size < 1 { small_order_size = 1; }
        stop_loss_threshold = rng.rand_int(-2000000, -500000);
    }
    
    if !market.trading_enabled { return; }
    if panic_triggered { return; }
    
    if account.unrealized_pnl < stop_loss_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        panic_triggered = true;
        
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    let total_filled_this_tick = 0;
    let fill_cnt = my_orders.fill_count();
    let j = 0;
    while j < fill_cnt {
        let fill_side = my_orders.fill_side(j);
        if fill_side == 1 {
            total_filled_this_tick += my_orders.fill_amount(j);
        }
        j += 1;
    }
    
    if total_filled_this_tick > 0 {
        let pending_cnt = my_orders.pending_count();
        let k = 0;
        while k < pending_cnt {
            let oid = my_orders.pending_id(k);
            orders.submit_cancel(oid);
            k += 1;
        }
        last_placed_order_id = -1;
        
        if account.stock > 0 && market.ask_price_0 > 0 {
            let order_size = small_order_size;
            if order_size > account.stock { order_size = account.stock; }
            orders.submit_limit_sell(market.ask_price_0, order_size);
        }
    } else {
        let has_pending = false;
        let pending_count = my_orders.pending_count();
        let l = 0;
        while l < pending_count {
            if my_orders.pending_side(l) == 1 {
                has_pending = true;
                break;
            }
            l += 1;
        }
        
        if !has_pending && account.stock > 0 && market.ask_price_0 > 0 {
            let order_size = small_order_size;
            if order_size > account.stock { order_size = account.stock; }
            orders.submit_limit_sell(market.ask_price_0, order_size);
        }
    }
}