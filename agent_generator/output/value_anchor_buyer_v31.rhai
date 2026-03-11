let initialized = false;
let fair_value = 0;
let price_history = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        return;
    }

    if !market.trading_enabled { return; }

    let pc = my_orders.pending_count();
    let i = 0;
    while i < pc {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    if price_history.len() < 5 {
        return;
    }
    let delayed_price = price_history[0];

    let ninety_five_percent = fair_value * 95 / 100;
    let ninety_percent = fair_value * 90 / 100;

    let buy_condition = delayed_price < fair_value;
    let small_buy = delayed_price < ninety_five_percent;
    let aggressive_buy = delayed_price < ninety_percent;

    let rounded_price = ((delayed_price + 500_000) / 1_000_000) * 1_000_000;

    if buy_condition {
        let amount = 0;
        if aggressive_buy {
            amount = 500;
        } else if small_buy {
            amount = 100;
        }
        if amount > 0 && account.cash > rounded_price {
            let max_shares = account.cash / rounded_price;
            if amount > max_shares {
                amount = max_shares;
            }
            if amount > 0 {
                orders.submit_limit_buy(rounded_price, amount);
            }
        }
    } else {
        let sell_condition = delayed_price > account.avg_cost && account.stock > 0;
        if sell_condition {
            let amount = 100;
            if amount > account.stock {
                amount = account.stock;
            }
            if amount > 0 {
                orders.submit_limit_sell(rounded_price, amount);
            }
        }
    }
}