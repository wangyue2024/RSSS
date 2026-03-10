let initialized = false;
let lot_percent = 0;
let sell_percent = 0;

fn round_to_dollar(price) {
    let rounding_base = 1_000_000;
    return ((price + 500_000) / rounding_base) * rounding_base;
}

fn on_tick() {
    if !initialized {
        lot_percent = rng.rand_int(25, 50);
        sell_percent = rng.rand_int(50, 100);
        initialized = true;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let ma = market.ma_20;
    let std = market.std_dev;
    let lower_raw = ma - 2 * std;
    let upper_raw = ma + 2 * std;
    let lower_band = round_to_dollar(lower_raw);
    let upper_band = round_to_dollar(upper_raw);

    let buy_price = lower_band;
    let sell_price = upper_band;

    if buy_price > 0 && account.cash > 0 {
        let cash_to_use = account.cash * lot_percent / 100;
        let buy_amount = cash_to_use / buy_price;
        if buy_amount > 0 {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    }

    if account.stock > 0 && sell_price > account.avg_cost {
        let sell_amount = account.stock * sell_percent / 100;
        if sell_amount > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}