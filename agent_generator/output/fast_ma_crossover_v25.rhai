let initialized = false;
let panic_threshold = 0;
let last_ma_diff = 0;
let morning_ticks = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = rng.rand_int(-500_000, -50_000);
        morning_ticks = market.total_ticks / 5;
    }

    if !market.trading_enabled { return; }

    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    if market.tick >= morning_ticks { return; }

    let ma_diff = market.ma_5 - market.ma_20;
    let golden_cross = last_ma_diff <= 0 && ma_diff > 0;
    let death_cross = last_ma_diff >= 0 && ma_diff < 0;

    if golden_cross && account.cash > 0 {
        let amount = 1000;
        if amount * market.price > account.cash {
            amount = account.cash / market.price;
        }
        if amount > 0 {
            orders.submit_market_buy(amount);
        }
    }

    if death_cross && account.stock > 0 {
        orders.submit_market_sell(account.stock);
    }

    last_ma_diff = ma_diff;
}