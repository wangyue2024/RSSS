let initialized = false;
let vwap_dip_threshold = 0;
let stop_loss_threshold = 0;
let last_eval_tick = -1;

fn on_tick() {
    if !initialized {
        initialized = true;
        vwap_dip_threshold = rng.rand_int(100, 300);
        stop_loss_threshold = rng.rand_int(-500000, -100000);
    }

    if !market.trading_enabled { return; }

    if market.tick >= market.total_ticks / 5 {
        let cancel_count = my_orders.pending_count();
        let c = 0;
        while c < cancel_count {
            orders.submit_cancel(my_orders.pending_id(c));
            c += 1;
        }
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }

    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    if market.tick % 50 != 0 || market.tick == last_eval_tick {
        return;
    }
    last_eval_tick = market.tick;

    let cancel_count = my_orders.pending_count();
    let c = 0;
    while c < cancel_count {
        orders.submit_cancel(my_orders.pending_id(c));
        c += 1;
    }

    let price = market.price;
    let vwap = market.vwap;
    let diff_percent = (vwap - price) * 10000 / vwap;

    if diff_percent > vwap_dip_threshold && account.cash > 1000000 {
        let buy_amount = account.cash * 50 / (100 * price);
        if buy_amount > 0 {
            orders.submit_limit_buy(price, buy_amount);
        }
    } else if price >= vwap && account.stock > 0 {
        orders.submit_limit_sell(price, account.stock);
    }
}