let initialized = false;
let total_sell_target = 0;
let lot_size = 0;
let pending_sell_id = -1;
let placed_price = 0;
let std_dev_threshold = 0;
let max_position = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let capital_percent = rng.rand_int(1, 4);
        max_position = account.total_equity * capital_percent / 100;
        total_sell_target = account.stock;
        if total_sell_target > max_position {
            total_sell_target = max_position;
        }
        let lot_value = account.total_equity * rng.rand_int(1, 4) / 100;
        lot_size = lot_value / market.price;
        if lot_size < 1 {
            lot_size = 1;
        }
        std_dev_threshold = market.price * 2 / 100;
    }
    
    if !market.trading_enabled { return; }
    
    let safe_to_trade = market.std_dev < std_dev_threshold;
    
    let fill_count = my_orders.fill_count();
    let i = 0;
    while i < fill_count {
        let fid = my_orders.fill_id(i);
        if fid == pending_sell_id {
            total_sell_target -= my_orders.fill_amount(i);
            pending_sell_id = -1;
            placed_price = 0;
        }
        i += 1;
    }
    
    if !safe_to_trade && pending_sell_id != -1 {
        orders.submit_cancel(pending_sell_id);
        pending_sell_id = -1;
        placed_price = 0;
        return;
    }
    
    if !safe_to_trade {
        return;
    }
    
    if pending_sell_id == -1 && total_sell_target > 0 && market.ask_price_0 > 0 {
        let sell_amount = lot_size;
        if sell_amount > total_sell_target {
            sell_amount = total_sell_target;
        }
        placed_price = market.ask_price_0;
        pending_sell_id = orders.submit_limit_sell(placed_price, sell_amount);
    }
}