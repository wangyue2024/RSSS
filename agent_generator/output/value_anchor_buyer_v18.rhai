let initialized = false;
let fair_value = 0;
let lot_size = 0;
let max_std_dev = 1_000_000;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        let five_pct_cap = account.total_equity * 5 / 100;
        let max_shares = five_pct_cap / fair_value;
        if max_shares < 1 {
            lot_size = 1;
        } else {
            lot_size = rng.rand_int(1, max_shares);
        }
        initialized = true;
    }

    if market.std_dev > max_std_dev {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let current_price = market.price;
    let threshold1 = fair_value * 95 / 100;
    let threshold2 = fair_value * 90 / 100;

    let desired_amount = 0;
    if current_price < threshold2 {
        desired_amount = 3 * lot_size;
    } else if current_price < threshold1 {
        desired_amount = lot_size;
    }

    if desired_amount > 0 {
        let max_affordable = account.cash / current_price;
        let amount = desired_amount;
        if max_affordable < amount {
            amount = max_affordable;
        }
        if amount > 0 {
            orders.submit_limit_buy(current_price, amount);
        }
    }
}