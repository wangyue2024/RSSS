let initialized = false;
let panic_threshold = 0;
let base_lot_size = 1000;
let current_lot_size = 1000;
let last_trade_was_loss = false;
let morning_threshold = 0;

fn on_tick() {
    if !initialized {
        panic_threshold = -rng.rand_int(50000, 200000);
        morning_threshold = market.total_ticks / 5;
        initialized = true;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.tick >= morning_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        current_lot_size = base_lot_size;
        last_trade_was_loss = false;
        return;
    }

    if last_trade_was_loss {
        current_lot_size = current_lot_size * 2;
    } else {
        current_lot_size = base_lot_size;
    }

    if account.stock > 0 && market.price < account.avg_cost {
        last_trade_was_loss = true;
    } else {
        last_trade_was_loss = false;
    }

    if market.buy_volume > 3 * market.sell_volume {
        orders.submit_limit_buy(market.price, current_lot_size);
    }
}