let delayed_prices = [];
let has_entered = false;
let entry_tick = 0;
let entry_price = 0;
let take_profit_id = 0;
let stop_loss_id = 0;
let position_size = 0;

fn on_tick() {
    if !market.trading_enabled { return; }

    delayed_prices.push(market.price);
    if delayed_prices.len() > 5 {
        delayed_prices.remove(0);
    }

    if delayed_prices.len() < 5 { return; }
    let delayed_price = delayed_prices[0];

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        if oid != take_profit_id && oid != stop_loss_id {
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    if !has_entered {
        if rng.rand_bool(1) {
            let buy_amount = 100;
            orders.submit_market_buy(buy_amount);
            has_entered = true;
            entry_price = delayed_price;
            position_size = buy_amount;

            let raw_tp = entry_price * 105 / 100;
            let rounded_tp = ((raw_tp + 500_000) / 1_000_000) * 1_000_000;
            take_profit_id = orders.submit_limit_sell(rounded_tp, position_size);

            let stop_level = entry_price * 98 / 100;
            stop_loss_id = orders.submit_limit_sell(stop_level, position_size);
        }
    } else {
        let tp_active = false;
        let sl_active = false;
        let p = 0;
        while p < pending_cnt {
            let pid = my_orders.pending_id(p);
            if pid == take_profit_id { tp_active = true; }
            if pid == stop_loss_id { sl_active = true; }
            p += 1;
        }

        if !tp_active && !sl_active {
            has_entered = false;
            entry_price = 0;
            position_size = 0;
            take_profit_id = 0;
            stop_loss_id = 0;
        }
    }
}