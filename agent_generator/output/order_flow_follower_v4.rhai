let initialized = false;
let base_lot = 0;
let multiplier = 1;
let stop_threshold = 0;

fn on_tick() {
    if !initialized {
        base_lot = 100;
        multiplier = 1;
        stop_threshold = -rng.rand_int(500_000, 2_000_000);
        initialized = true;
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.unrealized_pnl < stop_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        multiplier = 1;
        return;
    }

    if market.buy_volume > 3 * market.sell_volume {
        let buy_amount = base_lot * multiplier;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
            if account.stock > 0 && market.price < account.avg_cost {
                multiplier = multiplier * 2;
                if multiplier > 16 {
                    multiplier = 16;
                }
            } else {
                multiplier = 1;
            }
        }
    }
}