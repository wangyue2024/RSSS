let price_history = [];
let volume_history = [];
let initialized = false;
let base_lot = 100;
let current_lot = base_lot;
let last_trade_price = 0;
let last_trade_side = 0;
let last_trade_was_loss = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = rng.rand_int(80, 120);
        current_lot = base_lot;
    }

    if !market.trading_enabled { return; }

    price_history.push(market.price);
    volume_history.push(market.volume);

    if price_history.len() > 5 {
        price_history.remove(0);
    }
    if volume_history.len() > 5 {
        volume_history.remove(0);
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let fill_cnt = my_orders.fill_count();
    i = 0;
    while i < fill_cnt {
        let side = my_orders.fill_side(i);
        let price = my_orders.fill_price(i);
        let amount = my_orders.fill_amount(i);

        if amount > 0 {
            last_trade_price = price;
            if side == 0 {
                last_trade_side = 1;
            } else {
                last_trade_side = -1;
            }

            if last_trade_side == 1 && market.price < last_trade_price {
                last_trade_was_loss = true;
            } else if last_trade_side == -1 && market.price > last_trade_price {
                last_trade_was_loss = true;
            } else {
                last_trade_was_loss = false;
            }

            if last_trade_was_loss {
                current_lot = current_lot * 2;
            } else {
                current_lot = base_lot;
            }
        }
        i += 1;
    }

    if price_history.len() < 5 || volume_history.len() < 5 {
        return;
    }

    let delayed_price = price_history[0];
    let delayed_volume = volume_history[0];
    let current_price = market.price;

    let price_change = (current_price - delayed_price).abs();
    let change_percent = price_change * 10000 / delayed_price;

    if change_percent > 200 {
        orders.submit_market_buy(current_lot);
        return;
    }

    if delayed_price > market.ma_60 && delayed_volume < 10 {
        orders.submit_market_sell(current_lot);
    }
}