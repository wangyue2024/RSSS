let initialized = false;
let total_to_sell = 0;
let tip_size = 0;
let remaining_to_sell = 0;
let last_placed_order_id = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        total_to_sell = account.stock * 70 / 100;
        tip_size = total_to_sell / 200;
        if tip_size < 1 {
            tip_size = 1;
        }
        remaining_to_sell = total_to_sell;
    }

    if !market.trading_enabled {
        return;
    }

    let current_tick = market.tick;
    let total_ticks = market.total_ticks;
    let morning_active = current_tick < total_ticks / 5;

    if !morning_active {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }

    let fill_cnt = my_orders.fill_count();
    let i = 0;
    while i < fill_cnt {
        let fill_side = my_orders.fill_side(i);
        if fill_side == "sell" {
            let fill_amount = my_orders.fill_amount(i);
            remaining_to_sell = remaining_to_sell - fill_amount;
            if remaining_to_sell < 0 {
                remaining_to_sell = 0;
            }
        }
        i += 1;
    }

    let current_order_active = false;
    let pending_cnt = my_orders.pending_count();
    let j = 0;
    while j < pending_cnt {
        if my_orders.pending_id(j) == last_placed_order_id {
            current_order_active = true;
        }
        j += 1;
    }

    if !current_order_active && remaining_to_sell > 0 {
        let order_amount = tip_size;
        if order_amount > remaining_to_sell {
            order_amount = remaining_to_sell;
        }
        if order_amount > 0 {
            let best_ask = market.ask_price_0;
            if best_ask > 0 {
                last_placed_order_id = orders.submit_limit_sell(best_ask, order_amount);
            }
        }
    }
}