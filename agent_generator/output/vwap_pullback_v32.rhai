let initialized = false;
let lot_cash_percent = 0;
let threshold_micros = 0;
let price_history = [];
let ticks_to_delay = 5;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_cash_percent = rng.rand_int(40, 50);
        threshold_micros = micros(0, 50000);
    }

    if !market.trading_enabled {
        return;
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    price_history.push(market.price);
    if price_history.len() > ticks_to_delay {
        price_history.remove(0);
    }

    if price_history.len() < ticks_to_delay {
        return;
    }

    let delayed_price = price_history[0];
    let vwap = market.vwap;

    if account.stock == 0 {
        let threshold = (vwap * 500) / 100000;
        if delayed_price < vwap - threshold {
            let buy_amount = (account.cash * lot_cash_percent) / (100 * delayed_price);
            if buy_amount > 0 {
                orders.submit_limit_buy(delayed_price, buy_amount);
            }
        }
    } else {
        if delayed_price >= vwap {
            orders.submit_limit_sell(vwap, account.stock);
        }
    }
}