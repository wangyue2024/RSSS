let initialized = false;
let fair_value = 0;
let threshold_5 = 0;
let threshold_10 = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        threshold_5 = fair_value * 95 / 100;
        threshold_10 = fair_value * 90 / 100;
    }

    if !market.trading_enabled { return; }
    if market.tick >= market.total_ticks / 5 { return; }

    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }

    let current_price = market.price;
    if current_price >= fair_value { return; }

    let buy_amount = 0;
    if current_price < threshold_10 {
        buy_amount = 500;
    } else if current_price < threshold_5 {
        buy_amount = 100;
    }

    if buy_amount > 0 {
        let max_affordable = account.cash / current_price;
        let amount_to_buy = buy_amount;
        if max_affordable < amount_to_buy {
            amount_to_buy = max_affordable;
        }
        if amount_to_buy > 0 {
            orders.submit_limit_buy(current_price, amount_to_buy);
        }
    }
}