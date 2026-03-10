let initialized = false;
let buy_vol_history = [];
let sell_vol_history = [];
let price_history = [];
let LOOKBACK_TICKS = 5;
let TRADE_AMOUNT = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
    }

    if !market.trading_enabled { return; }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    buy_vol_history.push(market.buy_volume);
    sell_vol_history.push(market.sell_volume);
    price_history.push(market.price);

    if buy_vol_history.len() > LOOKBACK_TICKS {
        buy_vol_history.remove(0);
        sell_vol_history.remove(0);
        price_history.remove(0);
    }

    if buy_vol_history.len() < LOOKBACK_TICKS {
        return;
    }

    let old_buy_vol = buy_vol_history[0];
    let old_sell_vol = sell_vol_history[0];
    let old_price = price_history[0];

    if old_buy_vol > 3 * old_sell_vol {
        orders.submit_limit_buy(old_price, TRADE_AMOUNT);
    } else if old_sell_vol > 3 * old_buy_vol {
        orders.submit_limit_sell(old_price, TRADE_AMOUNT);
    }
}