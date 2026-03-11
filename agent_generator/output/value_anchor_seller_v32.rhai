let initialized = false;
let fair_value = 0;
let base_lot_size = 0;
let current_lot_size = 0;
let last_trade_was_loss = false;
let last_avg_cost = 0;

fn on_tick() {
    if !initialized {
        fair_value = 100_000_000 + rng.rand_int(-2_000_000, 2_000_000);
        base_lot_size = rng.rand_int(500_000, 5_000_000);
        current_lot_size = base_lot_size;
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let threshold_aggressive = fair_value * 110 / 100;
    let threshold_moderate = fair_value * 105 / 100;
    
    if last_avg_cost != 0 && account.avg_cost != 0 {
        if market.price < last_avg_cost {
            last_trade_was_loss = true;
        }
    }
    last_avg_cost = account.avg_cost;
    
    if last_trade_was_loss {
        current_lot_size = current_lot_size * 2;
        last_trade_was_loss = false;
    } else {
        current_lot_size = base_lot_size;
    }
    
    let max_lot = account.cash * 50 / 100;
    if current_lot_size > max_lot {
        current_lot_size = max_lot;
    }
    
    if market.price > threshold_aggressive && account.stock > 0 {
        let sell_amount = current_lot_size / market.price;
        if sell_amount < 1 { sell_amount = 1; }
        if sell_amount > account.stock { sell_amount = account.stock; }
        orders.submit_limit_sell(market.price, sell_amount);
    } else if market.price > threshold_moderate && account.stock > 0 {
        let sell_amount = (current_lot_size / market.price) / 2;
        if sell_amount < 1 { sell_amount = 1; }
        if sell_amount > account.stock { sell_amount = account.stock; }
        orders.submit_limit_sell(market.price, sell_amount);
    }
}