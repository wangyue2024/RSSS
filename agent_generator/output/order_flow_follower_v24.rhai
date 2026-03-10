let initialized = false;
let lot_size = 0;
let std_dev_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_lot = account.total_equity * 5 / 100;
        lot_size = rng.rand_int(1, max_lot);
        std_dev_threshold = market.price * 10 / 100;
    }

    if !market.trading_enabled { return; }

    let current_tick = market.tick;

    let i = 0;
    while i < my_orders.pending_count() {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    if market.std_dev > std_dev_threshold { return; }

    let has_pending_buy = false;
    let has_pending_sell = false;
    let j = 0;
    while j < my_orders.pending_count() {
        let side = my_orders.pending_side(j);
        if side == 0 {
            has_pending_buy = true;
        } else {
            has_pending_sell = true;
        }
        j += 1;
    }

    if !has_pending_buy && market.buy_volume > 3 * market.sell_volume {
        let ask_price = market.ask_price_0;
        let cost = lot_size * ask_price;
        if account.cash >= cost {
            orders.submit_limit_buy(ask_price, lot_size);
        }
    }

    if !has_pending_sell && account.stock > 0 {
        let bid_price = market.bid_price_0;
        if bid_price > account.avg_cost {
            let sell_amount = if lot_size > account.stock { account.stock } else { lot_size };
            if sell_amount > 0 {
                orders.submit_limit_sell(bid_price, sell_amount);
            }
        }
    }
}