let initialized = false;
let stop_loss_pnl = 0;
let prev_ma5 = 0;
let prev_ma20 = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_pnl = -rng.rand_int(50_000, 200_000);
    }
    
    if !market.trading_enabled { return; }
    
    let current_ma5 = market.ma_5;
    let current_ma20 = market.ma_20;
    
    let ma_cross_up = (prev_ma5 <= prev_ma20) && (current_ma5 > current_ma20);
    let ma_cross_down = (prev_ma5 >= prev_ma20) && (current_ma5 < current_ma20);
    
    if account.unrealized_pnl < stop_loss_pnl && account.stock > 0 {
        let cnt = my_orders.pending_count();
        let j = 0;
        while j < cnt {
            let oid = my_orders.pending_id(j);
            orders.submit_cancel(oid);
            j += 1;
        }
        orders.submit_market_sell(account.stock);
        prev_ma5 = current_ma5;
        prev_ma20 = current_ma20;
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if ma_cross_up && account.stock == 0 {
        orders.submit_market_buy(account.cash / market.ask_price_0);
    } else if ma_cross_down && account.stock > 0 {
        orders.submit_market_sell(account.stock);
    }
    
    prev_ma5 = current_ma5;
    prev_ma20 = current_ma20;
}