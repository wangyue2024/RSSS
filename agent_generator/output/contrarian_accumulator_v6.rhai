let initialized = false;
let base_lot = 0;
let lot_multiplier = 0;
let max_lot_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = rng.rand_int(20, 100);
        lot_multiplier = rng.rand_int(2, 5);
        max_lot_size = base_lot * lot_multiplier;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.rsi_14 < 3000 {
        let limit_buy_price = market.price * 99 / 100;
        let affordable_amount = (account.cash * 50) / (10000 * limit_buy_price);
        let buy_amount = affordable_amount;
        if buy_amount > max_lot_size {
            buy_amount = max_lot_size;
        }
        if buy_amount > 0 {
            orders.submit_limit_buy(limit_buy_price, buy_amount);
        }
    } else if market.rsi_14 > 7000 && account.stock > 0 {
        let limit_sell_price = market.price * 101 / 100;
        let sell_amount = max_lot_size;
        if sell_amount > account.stock {
            sell_amount = account.stock;
        }
        if sell_amount > 0 {
            orders.submit_limit_sell(limit_sell_price, sell_amount);
        }
    }
}