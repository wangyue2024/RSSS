let initialized = false;
let personality = 0;
let lot_size = 0;
let order_timeout = 3;

fn on_tick() {
    if !initialized {
        initialized = true;
        personality = rng.rand_int(0, 1);
        
        if personality == 0 {
            let max_shares = (account.cash * 50 / 100) / market.price;
            if max_shares < 1 { max_shares = 1; }
            lot_size = rng.rand_int(1, max_shares);
        } else {
            let max_shares = (account.total_equity * 5 / 100) / market.price;
            if max_shares < 1 { max_shares = 1; }
            lot_size = rng.rand_int(1, max_shares);
        }
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick > order_timeout {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if personality == 1 && market.std_dev > 5000000 {
        return;
    }
    
    if my_orders.pending_count() > 0 { return; }
    
    if market.history_len() < 2 { return; }
    
    let current_price = market.price;
    let prev_price = market.history_price(1);
    
    if current_price < prev_price {
        let buy_price = current_price - 100;
        if buy_price > 0 {
            let buy_amount = lot_size;
            if buy_amount > 0 {
                orders.submit_limit_buy(buy_price, buy_amount);
            }
        }
    } else if current_price > prev_price && account.stock > 0 {
        let sell_price = current_price + 100;
        let sell_amount = if lot_size > account.stock { account.stock } else { lot_size };
        if sell_amount > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}