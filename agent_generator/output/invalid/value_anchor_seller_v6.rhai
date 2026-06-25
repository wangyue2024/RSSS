let initialized = false;
let fair_value_micros = 0;
let base_lot = 100;
let current_lot = 100;
let last_evaluation_tick = -100;
let delayed_price = 0;
let price_history = [];
let last_trade_profit = 0;
let last_avg_cost = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value_micros = 100_000_000 + rng.rand_int(-5_000_000, 5_000_000);
        base_lot = rng.rand_int(80, 120);
        current_lot = base_lot;
    }

    if !market.trading_enabled {
        return;
    }

    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }

    if price_history.len() == 5 {
        delayed_price = price_history[0];
    }

    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let latest_fill_idx = fill_cnt - 1;
        let fill_side = my_orders.fill_side(latest_fill_idx);
        if fill_side == 1 {
            last_trade_profit = (my_orders.fill_price(latest_fill_idx) - last_avg_cost) * my_orders.fill_amount(latest_fill_idx);
        }
    }

    if account.stock > 0 {
        last_avg_cost = account.avg_cost;
    }

    if market.tick - last_evaluation_tick >= 50 && price_history.len() == 5 {
        last_evaluation_tick = market.tick;

        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }

        if last_trade_profit < 0 {
            current_lot = current_lot * 2;
        } else {
            current_lot = base_lot;
        }
        current_lot = clamp_val(current_lot, base_lot, base_lot * 16);

        if delayed_price > fair_value_micros && account.stock > 0 {
            let sell_amount = 0;
            let threshold1 = fair_value_micros * 105 / 100;
            let threshold2 = fair_value_micros * 110 / 100;

            if delayed_price > threshold2 {
                sell_amount = current_lot * 4;
            } else if delayed_price > threshold1 {
                sell_amount = current_lot;
            }

            if sell_amount > 0 {
                sell_amount = clamp_val(sell_amount, 1, account.stock);
                if sell_amount > 0 {
                    orders.submit_limit_sell(delayed_price, sell_amount);
                }
            }
        }
    }
}