let initialized = false;
let lot_size = 20;
let last_realized_pnl = 0;
let base_lot = 20;
let max_lot = 1000;

fn on_tick() {
    if !initialized {
        initialized = true;
    }

    if !market.trading_enabled {
        return;
    }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if my_orders.fill_count() > 0 {
        let current_realized = account.realized_pnl;
        if current_realized < last_realized_pnl {
            lot_size = lot_size * 2;
            if lot_size > max_lot {
                lot_size = max_lot;
            }
        } else {
            lot_size = base_lot;
        }
        last_realized_pnl = current_realized;
    }

    let rsi = market.rsi_14;
    if rsi < 0 {
        return;
    }

    let current_price = market.price;

    if rsi < 3000 {
        let cost = current_price * lot_size;
        if account.cash >= cost {
            let target_bid = current_price * 99 / 100;
            let my_bid = target_bid + 1;
            orders.submit_limit_buy(my_bid, lot_size);
        }
    } else if rsi > 7000 && current_price > account.avg_cost {
        if account.stock >= lot_size {
            let target_ask = current_price * 101 / 100;
            let my_ask = target_ask - 1;
            orders.submit_limit_sell(my_ask, lot_size);
        }
    }
}