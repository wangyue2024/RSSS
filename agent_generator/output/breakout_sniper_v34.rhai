let initialized = false;
let panic_threshold = 0;
let stop_loss_offset = 0;
let last_eval_tick = -50;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(5000, 20000);
        stop_loss_offset = rng.rand_int(1000, 5000);
    }

    if !market.trading_enabled { return; }

    if account.stock > 0 {
        let stop_price = account.avg_cost - stop_loss_offset;
        if market.price < stop_price && account.unrealized_pnl < 0 {
            orders.submit_market_sell(account.stock);
            return;
        }
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    if market.tick - last_eval_tick >= 50 {
        last_eval_tick = market.tick;

        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }

        if account.stock == 0 && market.price > market.high_20 {
            let buy_amount = (account.cash * 80 / 100) / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        }
    }
}