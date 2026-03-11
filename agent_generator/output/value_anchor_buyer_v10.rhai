let initialized = false;
let fair_value = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = rng.rand_int(95_000_000, 105_000_000);
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.tick >= market.total_ticks / 5 { return; }

    let current_price = market.price;
    let threshold_small = fair_value * 95 / 100;
    let threshold_aggressive = fair_value * 90 / 100;

    if current_price < fair_value {
        let bid_price = if market.bid_price_0 > 0 { market.bid_price_0 + 1 } else { current_price + 1 };
        if bid_price >= fair_value { return; }

        let amount;
        if current_price < threshold_aggressive {
            amount = 1000;
        } else if current_price < threshold_small {
            amount = 100;
        } else {
            amount = 10;
        }

        if bid_price > 0 && amount > 0 {
            orders.submit_limit_buy(bid_price, amount);
        }
    }
}