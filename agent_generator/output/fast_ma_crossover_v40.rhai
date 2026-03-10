let initialized = false;
let stop_loss_threshold = 0;
let prev_ma5 = 0;
let prev_ma20 = 0;
let position_held = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_threshold = -rng.rand_int(500_000, 2_000_000);
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.tick * 5 >= market.total_ticks { return; }

    if account.unrealized_pnl < stop_loss_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
            position_held = false;
        }
        return;
    }

    let current_ma5 = market.ma_5;
    let current_ma20 = market.ma_20;

    if current_ma5 > current_ma20 && prev_ma5 <= prev_ma20 && !position_held {
        if account.cash > 0 {
            let buy_price = market.ask_price_0 + 1;
            let max_shares = account.cash / buy_price;
            if max_shares > 0 {
                orders.submit_limit_buy(buy_price, max_shares);
                position_held = true;
            }
        }
    }

    if current_ma5 < current_ma20 && prev_ma5 >= prev_ma20 && position_held {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
            position_held = false;
        }
    }

    prev_ma5 = current_ma5;
    prev_ma20 = current_ma20;
}