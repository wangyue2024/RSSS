let initialized = false;
let total_sell_target = 0;
let chunk_size = 0;
let last_action_tick = -100;
let pending_sell_id = -1;

fn on_tick() {
    if !initialized {
        initialized = true;
        total_sell_target = 500000 * account.stock / 1000000;
        chunk_size = total_sell_target / 1000;
        if chunk_size < 100 { chunk_size = 100; }
    }

    if !market.trading_enabled { return; }

    let tick = market.tick;
    
    let fills_this_tick = my_orders.fill_count();
    let i = 0;
    while i < fills_this_tick {
        if my_orders.fill_side(i) == 1 {
            let fill_amount = my_orders.fill_amount(i);
            if total_sell_target > 0 {
                total_sell_target -= fill_amount;
                if total_sell_target < 0 { total_sell_target = 0; }
            }
        }
        i += 1;
    }

    let current_chunk = if chunk_size > total_sell_target { total_sell_target } else { chunk_size };

    if pending_sell_id != -1 {
        let found = false;
        let pending_count = my_orders.pending_count();
        let j = 0;
        while j < pending_count {
            if my_orders.pending_id(j) == pending_sell_id {
                found = true;
                break;
            }
            j += 1;
        }
        if !found {
            pending_sell_id = -1;
        }
    }

    let should_act = false;
    if pending_sell_id == -1 && total_sell_target > 0 && current_chunk > 0 {
        should_act = true;
    }

    if tick % 50 == 0 || should_act {
        if pending_sell_id != -1 {
            orders.submit_cancel(pending_sell_id);
            pending_sell_id = -1;
        }

        if total_sell_target > 0 && current_chunk > 0 && market.ask_price_0 > 0 {
            let sell_price = market.ask_price_0 + 1;
            pending_sell_id = orders.submit_limit_sell(sell_price, current_chunk);
            last_action_tick = tick;
        }
    }
}