let initialized = false;
let lot_size = 0;
let iceberg_target = 0;
let iceberg_remaining = 0;
let chunk_size = 0;
let current_sell_order_id = -1;

fn on_tick() {
    if !initialized {
        initialized = true;
        let risk_multiplier = rng.rand_int(3, 5);
        lot_size = (account.cash * risk_multiplier) / 10;
        chunk_size = lot_size / 1000;
        if chunk_size < 1 { chunk_size = 1; }
        iceberg_target = lot_size;
        iceberg_remaining = iceberg_target;
    }

    if !market.trading_enabled { return; }

    if market.tick >= market.total_ticks * 1 / 5 {
        if current_sell_order_id != -1 {
            orders.submit_cancel(current_sell_order_id);
            current_sell_order_id = -1;
        }
        return;
    }

    if market.tick % 50 != 0 {
        let fill_cnt = my_orders.fill_count();
        if fill_cnt > 0 {
            let i = 0;
            while i < fill_cnt {
                if my_orders.fill_side(i) == 1 && iceberg_remaining > 0 {
                    iceberg_remaining = iceberg_remaining - my_orders.fill_amount(i);
                    if iceberg_remaining > 0 {
                        let replenish_amount = chunk_size;
                        if replenish_amount > iceberg_remaining {
                            replenish_amount = iceberg_remaining;
                        }
                        if market.ask_price_0 > 0 {
                            current_sell_order_id = orders.submit_limit_sell(market.ask_price_0, replenish_amount);
                        }
                    } else {
                        current_sell_order_id = -1;
                    }
                }
                i += 1;
            }
        }
        return;
    }

    if current_sell_order_id != -1 {
        orders.submit_cancel(current_sell_order_id);
        current_sell_order_id = -1;
    }

    if iceberg_remaining <= 0 {
        iceberg_remaining = iceberg_target;
    }

    if iceberg_remaining > 0 && market.ask_price_0 > 0 {
        let sell_amount = chunk_size;
        if sell_amount > iceberg_remaining {
            sell_amount = iceberg_remaining;
        }
        current_sell_order_id = orders.submit_limit_sell(market.ask_price_0, sell_amount);
    }
}