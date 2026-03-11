let initialized = false;
let fair_value = 0;
let lot_size = 0;
let price_history = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        lot_size = account.total_equity * rng.rand_int(1, 5) / 100;
        if lot_size == 0 {
            lot_size = 1000;
        }
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }

    if market.std_dev > fair_value * 2 / 100 {
        return;
    }

    if price_history.len() < 5 {
        return;
    }

    let delayed_price = price_history[0];

    if delayed_price < fair_value {
        let buy_amount = 0;
        let tier1_threshold = fair_value * 95 / 100;
        let tier2_threshold = fair_value * 90 / 100;

        if delayed_price < tier2_threshold {
            buy_amount = lot_size * 2;
        } else if delayed_price < tier1_threshold {
            buy_amount = lot_size;
        }

        if buy_amount > 0 && account.cash > delayed_price * buy_amount {
            let limit_price = delayed_price;
            orders.submit_limit_buy(limit_price, buy_amount);
        }
    }
}