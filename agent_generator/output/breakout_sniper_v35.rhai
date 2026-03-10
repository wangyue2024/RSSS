let initialized = false;
let my_lot_size = 0;
let breakout_threshold = 0;
let stop_loss_offset = 0;
let last_eval_tick = -50;
let pending_order_id = 0;
let pending_order_placed_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_lot = account.total_equity * 5 / 100 / market.price;
        if max_lot <= 0 {
            my_lot_size = 1;
        } else {
            my_lot_size = rng.rand_int(1, max_lot);
        }
        breakout_threshold = market.price * 2 / 1000;
        stop_loss_offset = market.price * 5 / 1000;
    }
    
    if !market.trading_enabled { return; }
    
    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if pending_order_id != 0 {
        if market.tick - pending_order_placed_tick >= 3 {
            orders.submit_cancel(pending_order_id);
            pending_order_id = 0;
            pending_order_placed_tick = 0;
        }
    }
    
    if market.tick - last_eval_tick >= 50 && account.stock == 0 {
        last_eval_tick = market.tick;
        
        if market.std_dev > market.price * 5 / 100 {
            return;
        }
        
        if market.price > market.high_20 + breakout_threshold {
            let target_price = market.ask_price_0;
            if target_price > 0 {
                pending_order_id = orders.submit_limit_buy(target_price, my_lot_size);
                pending_order_placed_tick = market.tick;
            }
        }
    }
    
    if account.stock > 0 {
        let stop_level = account.avg_cost - stop_loss_offset;
        if market.price <= stop_level {
            orders.submit_market_sell(account.stock);
        }
    }
}