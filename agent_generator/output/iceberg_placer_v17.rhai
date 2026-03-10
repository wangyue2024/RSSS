let initialized = false;
let target_sell_amount = 0;
let sold_amount = 0;
let lot_size = 0;
let last_fill_price = 0;
let last_avg_cost = 0;
let base_lot = 100;
let max_lot_multiplier = 64;

fn on_tick() {
    if !initialized {
        initialized = true;
        target_sell_amount = account.stock;
        lot_size = base_lot;
    }

    if !market.trading_enabled { return; }

    let remaining = target_sell_amount - sold_amount;
    if remaining <= 0 { return; }

    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let last_fill_idx = fill_cnt - 1;
        let fill_side = my_orders.fill_side(last_fill_idx);
        if fill_side == 1 {
            sold_amount += my_orders.fill_amount(last_fill_idx);
            last_fill_price = my_orders.fill_price(last_fill_idx);
            last_avg_cost = account.avg_cost;

            if last_avg_cost > 0 && last_fill_price < last_avg_cost {
                let new_lot = lot_size * 2;
                if new_lot <= base_lot * max_lot_multiplier {
                    lot_size = new_lot;
                }
            }
        }
    }

    if remaining > 0 && market.ask_price_0 > 0 {
        let order_amt = lot_size;
        if order_amt > remaining {
            order_amt = remaining;
        }
        if order_amt > 0 {
            orders.submit_limit_sell(market.ask_price_0, order_amt);
        }
    }
}