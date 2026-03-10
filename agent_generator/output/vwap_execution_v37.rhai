let initialized = false;
let price_queue = [];
let volume_queue = [];
let remaining_target = 100000;
let participation_rate = 10;

fn on_tick() {
    if !initialized {
        initialized = true;
        participation_rate = rng.rand_int(5, 15);
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    price_queue.push(market.price);
    volume_queue.push(market.volume);

    if price_queue.len() > 5 {
        price_queue.remove(0);
        volume_queue.remove(0);
    }

    if price_queue.len() < 5 { return; }

    let delayed_price = price_queue[0];
    let delayed_volume = volume_queue[0];

    let fill_count = my_orders.fill_count();
    i = 0;
    while i < fill_count {
        let fill_side = my_orders.fill_side(i);
        if fill_side == "buy" {
            let fill_amount = my_orders.fill_amount(i);
            remaining_target -= fill_amount;
        }
        i += 1;
    }

    if remaining_target <= 0 { return; }

    let slice_size = (delayed_volume * participation_rate) / 100;
    if slice_size == 0 && delayed_volume > 0 {
        slice_size = 1;
    }
    if slice_size > remaining_target {
        slice_size = remaining_target;
    }
    if slice_size > 0 {
        orders.submit_limit_buy(delayed_price, slice_size);
    }
}