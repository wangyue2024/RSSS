let initialized = false;
let lot_size = 0;
let iceberg_target = 0;
let remaining_to_sell = 0;
let last_fill_tick = 0;
let pending_sell_id = -1;

fn on_tick() {
    if !initialized {
        initialized = true;
        let risk_cap_pct = rng.rand_int(1, 5);
        let risk_cap_micros = (account.total_equity * risk_cap_pct) / 100;
        let shares_affordable = risk_cap_micros / market.price;
        if shares_affordable == 0 {
            lot_size = 1;
        } else {
            lot_size = shares_affordable;
        }
        iceberg_target = (account.stock * 50) / 100;
        remaining_to_sell = iceberg_target;
    }

    if !market.trading_enabled { return; }

    let vol_threshold = (market.price * 5) / 10000;
    if market.std_dev > vol_threshold {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        pending_sell_id = -1;
        return;
    }

    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let i = 0;
        while i < fill_cnt {
            let fill_id = my_orders.fill_id(i);
            if fill_id == pending_sell_id {
                remaining_to_sell = remaining_to_sell - my_orders.fill_amount(i);
                last_fill_tick = market.tick;
                pending_sell_id = -1;
            }
            i += 1;
        }
    }

    let has_pending = false;
    let pending_cnt = my_orders.pending_count();
    let j = 0;
    while j < pending_cnt {
        let oid = my_orders.pending_id(j);
        if oid == pending_sell_id {
            has_pending = true;
            break;
        }
        j += 1;
    }

    if pending_sell_id != -1 && !has_pending {
        pending_sell_id = -1;
    }

    if pending_sell_id == -1 && remaining_to_sell > 0 && account.stock > 0 {
        let best_ask = market.ask_price_0;
        if best_ask == 0 {
            best_ask = market.price;
        }
        let sell_qty = lot_size;
        if sell_qty > remaining_to_sell {
            sell_qty = remaining_to_sell;
        }
        if sell_qty > account.stock {
            sell_qty = account.stock;
        }
        if sell_qty > 0 {
            let new_id = orders.submit_limit_sell(best_ask, sell_qty);
            pending_sell_id = new_id;
        }
    }
}