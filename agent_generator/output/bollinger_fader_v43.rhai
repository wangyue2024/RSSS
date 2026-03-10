let initialized = false;
let base_lot = 100;
let last_trade_loss = false;
let next_tick_to_act = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = 100;
        last_trade_loss = false;
        next_tick_to_act = market.tick + 50;
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick < next_tick_to_act {
        return;
    }
    
    next_tick_to_act = market.tick + 50;
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let middle = market.ma_20;
    let std = market.std_dev;
    let lower_band = middle - 2 * std;
    let upper_band = middle + 2 * std;
    
    let current_lot = base_lot;
    if last_trade_loss {
        current_lot = base_lot * 2;
    }
    
    if lower_band > 0 {
        orders.submit_limit_buy(lower_band, current_lot);
    }
    
    if market.price > account.avg_cost && upper_band > 0 && account.stock > 0 {
        let sell_amount = if account.stock < current_lot { account.stock } else { current_lot };
        if sell_amount > 0 {
            orders.submit_limit_sell(upper_band, sell_amount);
        }
    }
    
    if account.stock > 0 {
        if market.price < account.avg_cost {
            last_trade_loss = true;
        } else {
            last_trade_loss = false;
        }
    }
}