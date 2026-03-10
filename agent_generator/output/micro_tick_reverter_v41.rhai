let initialized = false;
let base_lot = 0;
let current_lot = 0;
let last_position = 0;
let avg_entry_price = 0;
let in_loss = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_capital_frac = account.total_equity * 5 / 100;
        let max_shares = max_capital_frac / market.price;
        if max_shares < 1 {
            base_lot = 1;
        } else {
            base_lot = rng.rand_int(1, max_shares);
        }
        current_lot = base_lot;
    }
    
    if !market.trading_enabled {
        return;
    }
    
    let std_dev_threshold = market.price * 200 / 10000;
    if market.std_dev > std_dev_threshold {
        return;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.stock != last_position {
        last_position = account.stock;
        if account.stock != 0 {
            avg_entry_price = account.avg_cost;
        }
    }
    
    if account.stock > 0 && market.price < avg_entry_price {
        in_loss = true;
    } else if account.stock < 0 && market.price > avg_entry_price {
        in_loss = true;
    } else {
        in_loss = false;
    }
    
    if in_loss {
        current_lot = base_lot * 2;
    } else {
        current_lot = base_lot;
    }
    
    if current_lot <= 0 {
        return;
    }
    
    if market.history_len() < 2 {
        return;
    }
    
    let last_price = market.history_price(1);
    let price_changed = market.price != last_price;
    
    if !price_changed {
        return;
    }
    
    let order_offset = 100;
    if market.price < last_price {
        let buy_price = market.price - order_offset;
        if buy_price > 0 && account.cash >= buy_price * current_lot {
            orders.submit_limit_buy(buy_price, current_lot);
        }
    } else if market.price > last_price {
        let sell_price = market.price + order_offset;
        if account.stock >= current_lot || true {
            orders.submit_limit_sell(sell_price, current_lot);
        }
    }
}