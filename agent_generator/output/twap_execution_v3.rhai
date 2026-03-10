let initialized = false;
let target_position = 0;
let slice_size = 0;
let interval_ticks = 0;
let stop_loss_threshold = 0;
let last_buy_tick = 0;
let price_history = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        target_position = rng.rand_int(40000, 60000);
        slice_size = rng.rand_int(400, 600);
        interval_ticks = rng.rand_int(3, 8);
        stop_loss_threshold = -rng.rand_int(500000, 3000000);
        
        for i in 0..5 {
            price_history.push(market.price);
        }
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    price_history.remove(0);
    price_history.push(market.price);
    
    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    if price_history.len() >= 5 {
        let old_price = price_history[0];
        let jump_threshold = old_price * 102 / 100;
        if market.price > jump_threshold && account.stock < target_position {
            let to_buy = target_position - account.stock;
            let buy_amount = if to_buy < slice_size { to_buy } else { slice_size };
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            return;
        }
    }
    
    if market.price > account.avg_cost && account.stock > 0 {
        let sell_amount = if account.stock < slice_size { account.stock } else { slice_size };
        orders.submit_market_sell(sell_amount);
    } else if market.tick - last_buy_tick >= interval_ticks && account.stock < target_position {
        let to_buy = target_position - account.stock;
        let buy_amount = if to_buy < slice_size { to_buy } else { slice_size };
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
            last_buy_tick = market.tick;
        }
    }
}