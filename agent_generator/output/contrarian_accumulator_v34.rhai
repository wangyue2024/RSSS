let initialized = false;
let price_history = [];
let rsi_history = [];
let trade_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        trade_size = rng.rand_int(20, 100);
    }

    if !market.trading_enabled { return; }

    price_history.push(market.price);
    rsi_history.push(market.rsi_14);

    if price_history.len() > 5 {
        price_history.remove(0);
        rsi_history.remove(0);
    }

    if price_history.len() < 5 {
        return;
    }

    let delayed_price = price_history[0];
    let delayed_rsi = rsi_history[0];

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if delayed_rsi < 3000 {
        let buy_price = delayed_price * 995 / 1000;
        orders.submit_limit_buy(buy_price, trade_size);
    } else if delayed_rsi > 7000 && account.stock > 0 {
        let sell_price = delayed_price * 1005 / 1000;
        let sell_amount = trade_size;
        if sell_amount > account.stock {
            sell_amount = account.stock;
        }
        if sell_amount > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}