let initialized = false;
let price_history = [];
let round_base = 1_000_000;

fn on_tick() {
    if !initialized {
        initialized = true;
    }

    if !market.trading_enabled { return; }
    if market.tick >= market.total_ticks * 20 / 100 { return; }

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

    if price_history.len() < 5 { return; }

    let delayed_price = price_history[0];
    let ma20 = market.ma_20;
    let atr = market.atr_14;
    let threshold = atr * 3 / 2;

    let upper_band = ma20 + threshold;
    let lower_band = ma20 - threshold;

    let rounded_price = ((delayed_price + 500_000) / round_base) * round_base;

    if delayed_price > upper_band && account.stock > 0 {
        let amount = 100;
        if account.stock >= amount {
            orders.submit_limit_sell(rounded_price, amount);
        }
    } else if delayed_price < lower_band {
        let amount = 100;
        let cost = rounded_price * amount;
        if cost <= account.cash {
            orders.submit_limit_buy(rounded_price, amount);
        }
    }
}