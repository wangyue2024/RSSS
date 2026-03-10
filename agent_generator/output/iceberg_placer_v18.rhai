let initialized = false;
let total_to_sell = 0;
let slice_size = 0;
let sold_so_far = 0;
let pending_sell_id = -1;
let order_placed_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        total_to_sell = (account.stock * rng.rand_int(40, 50)) / 100;
        slice_size = total_to_sell / 100;
        if slice_size == 0 {
            slice_size = 1;
        }
    }

    if !market.trading_enabled { return; }

    let current_price = market.price;
    let avg_cost = account.avg_cost;

    let fill_cnt = my_orders.fill_count();
    let i = 0;
    while i < fill_cnt {
        let fill_id = my_orders.fill_id(i);
        if fill_id == pending_sell_id {
            let fill_amt = my_orders.fill_amount(i);
            sold_so_far += fill_amt;
            pending_sell_id = -1;
        }
        i += 1;
    }

    let is_pending_still_there = false;
    let pending_cnt = my_orders.pending_count();
    let j = 0;
    while j < pending_cnt {
        let oid = my_orders.pending_id(j);
        if oid == pending_sell_id {
            if (market.tick - order_placed_tick) > 3 {
                orders.submit_cancel(pending_sell_id);
                pending_sell_id = -1;
            }
        }
        j += 1;
    }

    if sold_so_far >= total_to_sell {
        if pending_sell_id != -1 {
            orders.submit_cancel(pending_sell_id);
            pending_sell_id = -1;
        }
        return;
    }

    if pending_sell_id == -1 && sold_so_far < total_to_sell && current_price > avg_cost {
        let remaining = total_to_sell - sold_so_far;
        let order_amt = if slice_size < remaining { slice_size } else { remaining };
        let sell_price = market.ask_price_0;
        if sell_price > 0 && order_amt > 0 {
            pending_sell_id = orders.submit_limit_sell(sell_price, order_amt);
            order_placed_tick = market.tick;
        }
    }
}