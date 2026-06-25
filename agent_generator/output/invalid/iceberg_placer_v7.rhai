let initialized = false;
let target_sell_amount = 0;
let visible_lot_size = 0;
let pending_sell_id = -1;
let sold_amount = 0;
let last_avg_cost = 0;
let martingale_lot = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        target_sell_amount = 10_000;
        visible_lot_size = 100;
        martingale_lot = visible_lot_size;
    }
    
    if !market.trading_enabled { return; }
    
    let current_price = market.price;
    
    if sold_amount >= target_sell_amount {
        if pending_sell_id != -1 {
            orders.submit_cancel(pending_sell_id);
            pending_sell_id = -1;
        }
        return;
    }
    
    let had_loss = false;
    if my_orders.fill_count() > 0 {
        let i = 0;
        while i < my_orders.fill_count() {
            if my_orders.fill_side(i) == 1 {
                sold_amount += my_orders.fill_amount(i);
                let fill_price = my_orders.fill_price(i);
                if last_avg_cost > 0 && fill_price < last_avg_cost {
                    had_loss = true;
                }
            }
            i += 1;
        }
    }
    
    if had_loss {
        martingale_lot = martingale_lot * 2;
        martingale_lot = clamp_val(martingale_lot, 100, 10_000);
    }
    
    last_avg_cost = account.avg_cost;
    
    let remaining = target_sell_amount - sold_amount;
    if remaining <= 0 {
        return;
    }
    
    let current_lot = martingale_lot;
    if current_lot > remaining {
        current_lot = remaining;
    }
    
    let need_new_order = true;
    if pending_sell_id != -1 {
        let found = false;
        let i = 0;
        while i < my_orders.pending_count() {
            if my_orders.pending_id(i) == pending_sell_id {
                found = true;
                let remaining_amount = my_orders.pending_remaining(i);
                if remaining_amount == 0 {
                    orders.submit_cancel(pending_sell_id);
                    pending_sell_id = -1;
                } else {
                    need_new_order = false;
                }
                break;
            }
            i += 1;
        }
        if !found {
            pending_sell_id = -1;
        }
    }
    
    if need_new_order && current_lot > 0 && market.ask_price_0 > 0 {
        if pending_sell_id != -1 {
            orders.submit_cancel(pending_sell_id);
            pending_sell_id = -1;
        }
        
        let order_id = orders.submit_limit_sell(market.ask_price_0, current_lot);
        if order_id != -1 {
            pending_sell_id = order_id;
        }
    }
}