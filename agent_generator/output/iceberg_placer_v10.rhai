let initialized = false;
let lot_size = 0;
let sell_target = 0;
let remaining_to_sell = 0;
let current_order_id = -1;
let current_order_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        
        let max_lot_value = account.total_equity * 5 / 100;
        let max_lot_shares = max_lot_value / market.price;
        if max_lot_shares < 1 {
            max_lot_shares = 1;
        }
        lot_size = rng.rand_int(1, max_lot_shares);
        
        let target_multiplier = rng.rand_int(20, 100);
        sell_target = lot_size * target_multiplier;
        if sell_target > account.stock {
            sell_target = account.stock;
        }
        remaining_to_sell = sell_target;
    }
    
    if !market.trading_enabled {
        return;
    }
    
    let volatility_threshold = market.price * 2 / 100;
    if market.std_dev > volatility_threshold {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        current_order_id = -1;
        return;
    }
    
    let fill_count = my_orders.fill_count();
    let i = 0;
    while i < fill_count {
        let fill_id = my_orders.fill_id(i);
        if fill_id == current_order_id {
            let fill_amount = my_orders.fill_amount(i);
            if remaining_to_sell >= fill_amount {
                remaining_to_sell -= fill_amount;
            } else {
                remaining_to_sell = 0;
            }
            current_order_id = -1;
        }
        i += 1;
    }
    
    if current_order_id == -1 {
        if remaining_to_sell <= 0 {
            return;
        }
        
        let order_amount = lot_size;
        if order_amount > remaining_to_sell {
            order_amount = remaining_to_sell;
        }
        
        if market.ask_price_0 > 0 {
            current_order_price = market.ask_price_0;
            current_order_id = orders.submit_limit_sell(current_order_price, order_amount);
        } else if market.price > 0 {
            current_order_price = market.price;
            current_order_id = orders.submit_limit_sell(current_order_price, order_amount);
        }
    } else {
        let found = false;
        let pending_count = my_orders.pending_count();
        let j = 0;
        while j < pending_count {
            if my_orders.pending_id(j) == current_order_id {
                found = true;
                break;
            }
            j += 1;
        }
        
        if !found {
            current_order_id = -1;
        } else if market.ask_price_0 > 0 && market.ask_price_0 != current_order_price {
            orders.submit_cancel(current_order_id);
            current_order_id = -1;
        }
    }
}