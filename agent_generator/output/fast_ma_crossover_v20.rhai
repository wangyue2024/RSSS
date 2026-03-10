let initialized = false;
let prev_ma5_above = false;
let active_ticks = 0;
let max_active_ticks = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        prev_ma5_above = market.ma_5 > market.ma_20;
        max_active_ticks = market.total_ticks / 5;
    }
    
    if !market.trading_enabled { return; }
    
    let current_ma5_above = market.ma_5 > market.ma_20;
    
    if market.tick < max_active_ticks {
        active_ticks = 1;
    } else {
        active_ticks = 0;
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    if active_ticks == 0 { return; }
    
    let buy_signal = current_ma5_above && !prev_ma5_above;
    let sell_signal = !current_ma5_above && prev_ma5_above;
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if buy_signal {
        let max_buy_shares = account.cash / market.price;
        if max_buy_shares > 0 {
            orders.submit_market_buy(max_buy_shares);
        }
    }
    
    if sell_signal && market.price > account.avg_cost && account.stock > 0 {
        orders.submit_market_sell(account.stock);
    }
    
    prev_ma5_above = current_ma5_above;
}