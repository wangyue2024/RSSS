let initialized = false;
let fair_value = 0;
let stop_loss_threshold = 0;
let active = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        stop_loss_threshold = -rng.rand_int(1_000_000, 10_000_000);
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.tick * 5 < market.total_ticks {
        active = true;
    } else {
        active = false;
    }

    if account.unrealized_pnl < stop_loss_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }

    if !active { return; }

    let current_price = market.price;

    if current_price < fair_value {
        let buy_amount = 0;
        if current_price < fair_value * 90 / 100 {
            buy_amount = 500;
        } else if current_price < fair_value * 95 / 100 {
            buy_amount = 100;
        }
        if buy_amount > 0 {
            orders.submit_limit_buy(current_price, buy_amount);
        }
    }
}