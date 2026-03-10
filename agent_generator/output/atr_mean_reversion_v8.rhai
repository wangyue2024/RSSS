let initialized = false;
let panic_threshold = 0;
let price_history = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = rng.rand_int(5_000, 25_000);
    }

    if !market.trading_enabled { return; }

    let total_ticks = market.total_ticks;
    let current_tick = market.tick;

    if current_tick >= total_ticks / 5 {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }

    if account.unrealized_pnl < -panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }

    if price_history.len() < 5 {
        return;
    }

    let delayed_price = price_history[0];
    let delayed_atr = market.atr_14;
    let delayed_ma = market.ma_20;
    let deviation = delayed_price - delayed_ma;
    let atr_threshold = delayed_atr * 3 / 2;

    if deviation > atr_threshold {
        if account.stock > 0 {
            let sell_amount = account.stock;
            let limit_price = delayed_ma;
            orders.submit_limit_sell(limit_price, sell_amount);
        }
    } else if deviation < -atr_threshold {
        if account.cash > 0 {
            let buy_price = delayed_ma;
            let max_shares = account.cash / buy_price;
            let buy_amount = max_shares * 1 / 10;
            if buy_amount > 0 {
                orders.submit_limit_buy(buy_price, buy_amount);
            }
        }
    }
}