let initialized = false;
let target_position = 50_000;
let slice_size = 500;
let interval_ticks = 5;
let last_action_tick = -1000;
let pending_limit_id = -1;
let limit_placed_tick = 0;
let price_history = [];
let fomo_triggered = false;

fn round_to_dollar(price) {
    let remainder = price % 1_000_000;
    if remainder >= 500_000 {
        price + (1_000_000 - remainder)
    } else {
        price - remainder
    }
}

fn on_tick() {
    if !initialized {
        initialized = true;
        if !market.trading_enabled { return; }
    }

    if !market.trading_enabled { return; }

    let current_tick = market.tick;
    let remaining_to_target = target_position - account.stock;

    if remaining_to_target <= 0 {
        if my_orders.pending_count() > 0 {
            let count = my_orders.pending_count();
            let i = 0;
            while i < count {
                let oid = my_orders.pending_id(i);
                orders.submit_cancel(oid);
                i += 1;
            }
        }
        return;
    }

    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }

    if price_history.len() == 5 {
        let old_price = price_history[0];
        let current_price = market.price;
        let change = (current_price - old_price) * 10000 / old_price;
        if abs_val(change) > 200 {
            fomo_triggered = true;
        }
    }

    if fomo_triggered {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        pending_limit_id = -1;

        let to_buy = min(slice_size, remaining_to_target);
        if to_buy > 0 {
            orders.submit_market_buy(to_buy);
        }
        last_action_tick = current_tick;
        return;
    }

    let cancel_current = false;
    if pending_limit_id != -1 {
        let found = false;
        let pcount = my_orders.pending_count();
        let j = 0;
        while j < pcount {
            if my_orders.pending_id(j) == pending_limit_id {
                found = true;
                break;
            }
            j += 1;
        }
        if !found {
            pending_limit_id = -1;
        } else if (current_tick - limit_placed_tick) >= 3 {
            orders.submit_cancel(pending_limit_id);
            pending_limit_id = -1;
            cancel_current = true;
        }
    }

    let slice_needed = min(slice_size, remaining_to_target);
    if slice_needed <= 0 { return; }

    if pending_limit_id == -1 && (current_tick - last_action_tick >= interval_ticks || cancel_current) {
        let rounded_price = round_to_dollar(market.price);
        let limit_id = orders.submit_limit_buy(rounded_price, slice_needed);
        pending_limit_id = limit_id;
        limit_placed_tick = current_tick;
        last_action_tick = current_tick;
    }
}