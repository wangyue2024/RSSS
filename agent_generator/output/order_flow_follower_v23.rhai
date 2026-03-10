let initialized = false;
let stop_loss_threshold = 0;
let fomo_triggered = false;
let last_price_memory = 0;
let ticks_in_memory = 0;
let lookback_window = 10;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_threshold = -rng.rand_int(50_000, 200_000);
        last_price_memory = market.price;
        ticks_in_memory = 0;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    ticks_in_memory += 1;
    if ticks_in_memory >= lookback_window {
        let price_change_pct = (market.price - last_price_memory) * 10000 / last_price_memory;
        if price_change_pct > 200 {
            fomo_triggered = true;
        }
        last_price_memory = market.price;
        ticks_in_memory = 0;
    }

    if fomo_triggered {
        if account.cash > 100_000_000 {
            let buy_amount = 100;
            orders.submit_market_buy(buy_amount);
        }
        fomo_triggered = false;
    } else {
        if market.buy_volume > 3 * market.sell_volume {
            if account.cash > 100_000_000 {
                let buy_amount = 50;
                orders.submit_market_buy(buy_amount);
            }
        }
    }
}