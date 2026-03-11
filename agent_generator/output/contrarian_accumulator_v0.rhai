let initialized = false;
let base_lot_size = 0;
let current_lot_size = 0;
let last_decision_tick = -50;
let last_trade_loss = false;

fn on_tick() {
    if !market.trading_enabled {
        return;
    }

    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(20, 100);
        current_lot_size = base_lot_size;
    }

    let current_tick = market.tick;

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed = my_orders.pending_placed_tick(i);
        if current_tick - placed > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    if current_tick - last_decision_tick < 50 {
        return;
    }
    last_decision_tick = current_tick;

    if account.stock > 0 && market.price < account.avg_cost {
        last_trade_loss = true;
    } else {
        last_trade_loss = false;
    }

    if last_trade_loss {
        current_lot_size = current_lot_size * 2;
        if current_lot_size > 100 {
            current_lot_size = 100;
        }
    } else {
        current_lot_size = base_lot_size;
    }

    if current_lot_size <= 0 {
        return;
    }

    let rsi = market.rsi_14;

    if rsi < 3000 {
        let bid_price = market.bid_price_0 - 10;
        if bid_price > 0 {
            orders.submit_limit_buy(bid_price, current_lot_size);
        }
    } else if rsi > 7000 && account.stock > 0 {
        let sell_amount = current_lot_size;
        if sell_amount > account.stock {
            sell_amount = account.stock;
        }
        let ask_price = market.ask_price_0 + 10;
        if ask_price > 0 && sell_amount > 0 {
            orders.submit_limit_sell(ask_price, sell_amount);
        }
    }
}