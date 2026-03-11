let initialized = false;
let fair_value = 0;
let my_aggression = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = 100_000_000 * rng.rand_int(97, 103) / 100;
        my_aggression = rng.rand_int(80, 120);
    }

    if !market.trading_enabled {
        return;
    }

    let current_tick = market.tick;
    let price = market.price;

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        let placed = my_orders.pending_placed_tick(i);
        if (current_tick - placed) > 3 {
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    if price > fair_value {
        let threshold1 = fair_value * 105 / 100;
        let threshold2 = fair_value * 110 / 100;
        let sell_amount = 0;

        if price > threshold2 {
            sell_amount = 5 * my_aggression / 100;
        } else if price > threshold1 {
            sell_amount = 2 * my_aggression / 100;
        }

        if sell_amount > 0 && account.stock >= sell_amount {
            let sell_price = market.bid_price_0;
            if sell_price == 0 {
                sell_price = price;
            }
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}