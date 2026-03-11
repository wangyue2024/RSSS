let initialized = false;
let fair_value_micros = 0;
let last_decision_tick = -100;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        initialized = true;
        fair_value_micros = rng.rand_int(95_000_000, 105_000_000);
    }

    if market.tick % 50 != 0 { return; }
    last_decision_tick = market.tick;

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let current_price = market.price;
    let threshold_95 = fair_value_micros * 95 / 100;
    let threshold_90 = fair_value_micros * 90 / 100;

    if current_price < threshold_90 && account.cash > 10_000_000 {
        let cash_to_use = account.cash * 25 / 100;
        let amount = cash_to_use / current_price;
        if amount > 0 {
            orders.submit_limit_buy(current_price, amount);
        }
    } else if current_price < threshold_95 && account.cash > 5_000_000 {
        let cash_to_use = account.cash * 10 / 100;
        let amount = cash_to_use / current_price;
        if amount > 0 {
            orders.submit_limit_buy(current_price, amount);
        }
    }
}