let initialized = false;
let stop_loss_offset = 0;
let entry_price = 0;
let position_active = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_offset = rng.rand_int(3_000, 8_000);
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= market.total_ticks / 5 {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        position_active = false;
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let fill_cnt = my_orders.fill_count();
    let j = 0;
    while j < fill_cnt {
        let fill_side = my_orders.fill_side(j);
        if fill_side == 0 {
            position_active = true;
            entry_price = account.avg_cost;
        } else if fill_side == 1 {
            position_active = false;
        }
        j += 1;
    }
    
    if position_active && account.stock > 0 {
        let stop_level = entry_price - stop_loss_offset;
        if market.price <= stop_level {
            orders.submit_market_sell(account.stock);
            position_active = false;
        }
    } else if account.stock == 0 && market.price > market.high_20 {
        let buy_amount = (account.cash * 80 / 100) / market.price;
        if buy_amount > 0 {
            orders.submit_limit_buy(market.price, buy_amount);
        }
    }
}