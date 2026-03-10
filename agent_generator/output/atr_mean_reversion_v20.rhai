let initialized = false;
let base_lot = 100;
let current_lot = 100;
let price_buffer = [];
let delayed_price = 0;
let last_trade_loss = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = rng.rand_int(50, 200);
        current_lot = base_lot;
    }

    if !market.trading_enabled { return; }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    price_buffer.push(market.price);
    if price_buffer.len() > 5 {
        price_buffer.remove(0);
    }

    if price_buffer.len() < 5 {
        return;
    }
    delayed_price = price_buffer[0];

    let atr = market.atr_14;
    let ma20 = market.ma_20;
    let deviation_upper = ma20 + (atr * 150) / 100;
    let deviation_lower = ma20 - (atr * 150) / 100;

    if account.stock != 0 {
        let cost_per_share = account.avg_cost;
        if (account.stock > 0 && market.price < cost_per_share) || (account.stock < 0 && market.price > cost_per_share) {
            last_trade_loss = true;
        } else {
            last_trade_loss = false;
        }
    }

    if last_trade_loss {
        current_lot = base_lot * 2;
    } else {
        current_lot = base_lot;
    }

    if delayed_price > deviation_upper {
        let sell_price = deviation_upper - 1;
        if sell_price > market.bid_price_0 {
            orders.submit_limit_sell(sell_price, current_lot);
        }
    } else if delayed_price < deviation_lower {
        let buy_price = deviation_lower + 1;
        if buy_price < market.ask_price_0 {
            orders.submit_limit_buy(buy_price, current_lot);
        }
    }
}