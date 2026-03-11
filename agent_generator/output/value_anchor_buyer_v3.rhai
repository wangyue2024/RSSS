let initialized = false;
let fair_value = 0;
let initial_lot_size = 0;
let current_lot_size = 0;
let last_trade_was_loss = false;

fn on_tick() {
    if !initialized {
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        let five_percent_capital = account.total_equity * 5 / 100;
        if market.price > 0 {
            initial_lot_size = rng.rand_int(1, five_percent_capital / market.price);
        } else {
            initial_lot_size = rng.rand_int(1, 100);
        }
        current_lot_size = initial_lot_size;
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    if market.std_dev > 5_000_000 {
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.stock > 0 && market.price > 0 {
        last_trade_was_loss = market.price < account.avg_cost;
    }
    
    if last_trade_was_loss {
        current_lot_size = initial_lot_size * 2;
    } else {
        current_lot_size = initial_lot_size;
    }
    
    let price = market.price;
    let aggressive_trigger = fair_value * 90 / 100;
    let small_trigger = fair_value * 95 / 100;
    
    if price < aggressive_trigger && price > 0 {
        let buy_amount = current_lot_size * 2;
        let max_affordable = account.cash / price;
        if buy_amount > max_affordable {
            buy_amount = max_affordable;
        }
        if buy_amount > 0 {
            orders.submit_limit_buy(price, buy_amount);
        }
    } else if price < small_trigger && price > 0 {
        let buy_amount = current_lot_size;
        let max_affordable = account.cash / price;
        if buy_amount > max_affordable {
            buy_amount = max_affordable;
        }
        if buy_amount > 0 {
            orders.submit_limit_buy(price, buy_amount);
        }
    }
}