let initialized = false;
let total_iceberg = 0;
let slice_size = 0;
let remaining_iceberg = 0;
let active_slice_id = 0;
let last_ask_price = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        total_iceberg = rng.rand_int(5000, 20000);
        slice_size = rng.rand_int(5, 25);
        remaining_iceberg = total_iceberg;
        active_slice_id = 0;
        last_ask_price = 0;
    }
    
    if market.tick >= market.total_ticks / 5 {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        active_slice_id = 0;
        return;
    }
    
    let fill_count = my_orders.fill_count();
    let filled = false;
    let i = 0;
    while i < fill_count {
        if my_orders.fill_id(i) == active_slice_id && my_orders.fill_side(i) == 1 {
            filled = true;
            break;
        }
        i += 1;
    }
    
    if filled {
        remaining_iceberg -= slice_size;
        if remaining_iceberg < 0 {
            remaining_iceberg = 0;
        }
        active_slice_id = 0;
    }
    
    let current_ask = market.ask_price_0;
    if current_ask <= 0 {
        return;
    }
    
    let need_new_order = false;
    if active_slice_id == 0 && remaining_iceberg > 0 {
        need_new_order = true;
    } else if active_slice_id != 0 {
        let pending_count = my_orders.pending_count();
        let found = false;
        let j = 0;
        while j < pending_count {
            if my_orders.pending_id(j) == active_slice_id {
                found = true;
                if my_orders.pending_price(j) != current_ask - 1 {
                    orders.submit_cancel(active_slice_id);
                    need_new_order = true;
                }
                break;
            }
            j += 1;
        }
        if !found {
            need_new_order = true;
        }
    }
    
    if need_new_order && remaining_iceberg > 0 {
        let sell_price = current_ask - 1;
        let sell_amount = slice_size;
        if sell_amount > remaining_iceberg {
            sell_amount = remaining_iceberg;
        }
        if sell_amount > 0 && sell_price > 0 {
            active_slice_id = orders.submit_limit_sell(sell_price, sell_amount);
            last_ask_price = sell_price;
        }
    }
}