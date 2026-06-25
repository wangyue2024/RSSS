let initialized = false;
let base_lot = 1000;
let current_lot = base_lot;
let last_trade_profit = 0;
let last_decision_tick = -50;
let price_buffer = [];
let pending_tp_id = 0;
let pending_sl_id = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        current_lot = base_lot;
        last_trade_profit = 0;
        last_decision_tick = -50;
        price_buffer.clear();
        pending_tp_id = 0;
        pending_sl_id = 0;
    }

    if !market.trading_enabled {
        return;
    }

    price_buffer.push(market.price);
    if price_buffer.len() > 5 {
        price_buffer.remove(0);
    }

    if market.tick - last_decision_tick < 50 {
        return;
    }

    last_decision_tick = market.tick;

    if price_buffer.len() < 5 {
        return;
    }

    let delayed_price = price_buffer[0];
    let current_pos = account.stock;

    if current_pos == 0 {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        pending_tp_id = 0;
        pending_sl_id = 0;

        if rng.rand_bool(50) {
            let entry_price = delayed_price;
            let buy_amount = current_lot;

            if account.cash >= entry_price * buy_amount / 1000000 {
                orders.submit_limit_buy(entry_price, buy_amount);
            }
        }
    } else {
        let has_tp = false;
        let has_sl = false;
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            if oid == pending_tp_id {
                has_tp = true;
            } else if oid == pending_sl_id {
                has_sl = true;
            }
            i += 1;
        }

        if !has_tp && !has_sl {
            let avg_cost = account.avg_cost;
            let tp_price = avg_cost * 105 / 100;
            let sl_price = avg_cost * 98 / 100;

            pending_tp_id = 0;
            pending_sl_id = 0;

            pending_tp_id = rng.rand_int(1, 1000000);
            orders.submit_limit_sell(tp_price, current_pos);
            pending_sl_id = rng.rand_int(1000001, 2000000);
            orders.submit_limit_sell(sl_price, current_pos);
        }
    }

    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let i = 0;
        while i < fill_cnt {
            let fill_side = my_orders.fill_side(i);
            let fill_price = my_orders.fill_price(i);
            let fill_amount = my_orders.fill_amount(i);
            
            if fill_side == 1 {
                last_trade_profit = (fill_price - account.avg_cost) * fill_amount;
                if last_trade_profit < 0 {
                    current_lot = current_lot * 2;
                } else {
                    current_lot = base_lot;
                }
            }
            i += 1;
        }
    }
}