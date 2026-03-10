let initialized = false;
let lot_size = 0;
let spread_micros = 0;
let max_volatility = 50_000;

fn on_tick() {
    if !initialized {
        initialized = true;
        spread_micros = rng.rand_int(100, 5000);
        let five_percent_capital = (account.total_equity * 5) / 100;
        if market.price > 0 {
            let max_shares = five_percent_capital / market.price;
            let fraction = rng.rand_int(1, 80);
            lot_size = (max_shares * fraction) / 100;
            if lot_size < 1 {
                lot_size = 1;
            }
        } else {
            lot_size = 100;
        }
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

    if market.std_dev > max_volatility {
        return;
    }

    let mid_price = market.price;
    let buy_price = mid_price - spread_micros;
    let sell_price = mid_price + spread_micros;

    if buy_price < 1 {
        buy_price = 1;
    }

    if account.cash >= (buy_price * lot_size) {
        orders.submit_limit_buy(buy_price, lot_size);
    }

    if account.stock >= lot_size {
        orders.submit_limit_sell(sell_price, lot_size);
    }
}