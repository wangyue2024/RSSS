let initialized = false;
let lot_size = 0;
let threshold = 0;
let max_std_dev = 0;
let morning_end_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        morning_end_tick = market.total_ticks * 2 / 10;
        lot_size = (account.total_equity * rng.rand_int(10, 500)) / 10000;
        threshold = rng.rand_int(50, 200);
        max_std_dev = market.price * 2 / 100;
    }

    if !market.trading_enabled { return; }

    if market.tick >= morning_end_tick {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }

    if market.std_dev > max_std_dev {
        return;
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let price = market.price;
    let vwap = market.vwap;
    let price_below_vwap = (vwap - price) * 10000 / vwap;

    if account.stock == 0 {
        if price_below_vwap >= threshold {
            if account.cash >= price {
                let buy_amount = clamp_val(lot_size, 1, account.cash / price);
                if buy_amount > 0 {
                    orders.submit_limit_buy(price, buy_amount);
                }
            }
        }
    } else {
        if price > account.avg_cost && price >= vwap {
            let sell_amount = account.stock;
            if sell_amount > 0 {
                orders.submit_limit_sell(price, sell_amount);
            }
        }
    }
}