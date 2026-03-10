let initialized = false;
let stop_loss_threshold = 0;
let base_lot_size = 0;
let current_lot_size = 0;
let last_trade_was_loss = false;
let pending_order_ticks = [];
let panic_mode = false;
let last_avg_cost_track = 0;
let last_trade_tick = -1000;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_threshold = -1 * rng.rand_int(100000, 500000);
        base_lot_size = rng.rand_int(50, 200);
        current_lot_size = base_lot_size;
        pending_order_ticks = [];
    }

    if !market.trading_enabled {
        return;
    }

    let current_tick = market.tick;

    let i = 0;
    let pending_cnt = my_orders.pending_count();
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let last_fill_idx = fill_cnt - 1;
        let fill_price = my_orders.fill_price(last_fill_idx);
        let fill_side = my_orders.fill_side(last_fill_idx);
        last_trade_tick = current_tick;

        if account.stock == 0 {
            last_avg_cost_track = 0;
        } else {
            last_avg_cost_track = account.avg_cost;
        }

        if last_avg_cost_track != 0 {
            if (fill_side == 0 && fill_price < last_avg_cost_track) || (fill_side == 1 && fill_price > last_avg_cost_track) {
                last_trade_was_loss = true;
                current_lot_size = current_lot_size * 2;
            } else {
                last_trade_was_loss = false;
                current_lot_size = base_lot_size;
            }
        }
    }

    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        panic_mode = true;
        return;
    }

    if panic_mode && account.stock == 0 {
        panic_mode = false;
    }

    if panic_mode {
        return;
    }

    let exhaustion_signal = false;
    if market.history_len() >= 60 {
        if market.price > market.ma_60 {
            let vol_very_low = market.volume < 1000;
            if vol_very_low {
                exhaustion_signal = true;
            }
        }
    }

    if exhaustion_signal && account.stock == 0 && current_tick - last_trade_tick > 10 {
        let target_price = market.bid_price_0 - 5000;
        if target_price > 0 {
            orders.submit_limit_sell(target_price, current_lot_size);
        }
    }

    if account.stock > 0 {
        let tp_price = account.avg_cost - 10000;
        if tp_price > 0 && market.price <= tp_price {
            orders.submit_limit_buy(tp_price, account.stock);
        }
    }
}