let initialized = false;
let stop_loss_threshold = 0;
let active_ticks = 0;

fn on_tick() {
    if !initialized {
        stop_loss_threshold = rng.rand_int(1_000_000, 5_000_000);
        active_ticks = market.total_ticks * 20 / 100;
        initialized = true;
    }

    if !market.trading_enabled { return; }

    if account.unrealized_pnl < -stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    if market.tick >= active_ticks {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.buy_volume > 3 * market.sell_volume {
        let cash_for_stock = account.cash * 10 / 100;
        if cash_for_stock > 0 && market.price > 0 {
            let amount = cash_for_stock / market.price;
            if amount > 0 {
                orders.submit_market_buy(amount);
            }
        }
    }
}