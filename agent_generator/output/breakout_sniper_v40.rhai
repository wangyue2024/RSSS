let initialized = false;
let max_position = 0;
let stop_loss_ticks = 0;
let morning_ticks = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        max_position = rng.rand_int(500, 2000);
        stop_loss_ticks = rng.rand_int(5, 15);
        morning_ticks = market.total_ticks / 5;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    if market.tick >= morning_ticks {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }
    
    let current_price = market.price;
    let high_20 = market.high_20;
    
    if account.stock > 0 {
        let stop_price = account.avg_cost - (stop_loss_ticks * 10000);
        if current_price < stop_price {
            orders.submit_market_sell(account.stock);
        }
    }
    
    if current_price > high_20 && account.stock < max_position {
        let buy_amount = (max_position - account.stock) / 4;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
    }
}