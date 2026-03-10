let initialized = false;
let max_wait_ticks = 3;
let base_lot_multiplier = 0;
let fomo_check_window = 5;
let fomo_percent_threshold = 20000;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_multiplier = rng.rand_int(250000, 500000);
    }
    if !market.trading_enabled { return; }
    let current_price = market.price;
    let ma20 = market.ma_20;
    let atr = market.atr_14;
    let threshold = atr * 15 / 10;
    let deviation = current_price - ma20;
    let abs_dev = abs_val(deviation);
    let cancel_any = false;
    let pcount = my_orders.pending_count();
    let i = 0;
    while i < pcount {
        let placed = my_orders.pending_placed_tick(i);
        if market.tick - placed > max_wait_ticks {
            orders.submit_cancel(my_orders.pending_id(i));
            cancel_any = true;
        }
        i += 1;
    }
    if cancel_any { return; }
    let fomo_triggered = false;
    if market.history_len() >= fomo_check_window {
        let past_price = market.history_price(fomo_check_window - 1);
        let price_change_pct = (current_price - past_price) * 1000000 / past_price;
        if price_change_pct > fomo_percent_threshold {
            fomo_triggered = true;
            let buy_amount = account.cash * base_lot_multiplier / 1000000;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        }
    }
    if fomo_triggered { return; }
    if abs_dev > threshold {
        let order_side = 0;
        if deviation > 0 {
            order_side = 2;
        } else {
            order_side = 1;
        }
        let lot_size = 0;
        if order_side == 1 {
            lot_size = account.cash * base_lot_multiplier / 1000000 / ma20;
        } else {
            lot_size = account.stock * base_lot_multiplier / 1000000;
        }
        if lot_size > 0 {
            if order_side == 1 {
                orders.submit_limit_buy(ma20, lot_size);
            } else {
                orders.submit_limit_sell(ma20, lot_size);
            }
        }
    }
}