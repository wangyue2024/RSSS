let initialized = false;
let fair_value_micros = 0;
let small_amount = 10;
let aggressive_amount = 50;

fn on_tick() {
    if !initialized {
        fair_value_micros = rng.rand_int(95_000_000, 105_000_000);
        initialized = true;
    }

    if !market.trading_enabled {
        return;
    }

    if market.tick % 50 != 0 {
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let current_price = market.price;
    let ninety_five_percent = fair_value_micros * 95 / 100;
    let ninety_percent = fair_value_micros * 90 / 100;

    if current_price < ninety_percent {
        orders.submit_limit_buy(current_price, aggressive_amount);
    } else if current_price < ninety_five_percent {
        orders.submit_limit_buy(current_price, small_amount);
    }
}