let initialized = false;
let fair_value = 0;
let base_lot_percent = 0;
let martingale_multiplier = 1;
let last_avg_cost_track = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        base_lot_percent = rng.rand_int(10, 50);
        last_avg_cost_track = account.avg_cost;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.stock > 0 && market.price < last_avg_cost_track {
        martingale_multiplier = martingale_multiplier * 2;
        if martingale_multiplier > 16 {
            martingale_multiplier = 16;
        }
    } else {
        martingale_multiplier = 1;
    }

    last_avg_cost_track = account.avg_cost;

    if market.price < fair_value {
        let discount = (fair_value - market.price) * 100 / fair_value;
        let percent_to_use = base_lot_percent;

        if discount > 10 {
            percent_to_use = 50;
        } else if discount > 5 {
            percent_to_use = 25;
        }

        let adjusted_percent = percent_to_use * martingale_multiplier;
        if adjusted_percent > 100 {
            adjusted_percent = 100;
        }

        let buy_amount = (account.cash * adjusted_percent) / (100 * market.price);
        if buy_amount > 0 {
            orders.submit_limit_buy(market.price, buy_amount);
        }
    }

    if market.price > fair_value && market.price > account.avg_cost && account.stock > 0 {
        orders.submit_limit_sell(market.price, account.stock);
    }
}