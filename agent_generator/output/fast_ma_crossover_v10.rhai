let initialized = false;
let lot_size = 0;
let price_history = [];
let morning_phase = false;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        initialized = true;
        let max_lot = account.total_equity * 5 / 100;
        if max_lot < 1 { max_lot = 1; }
        lot_size = rng.rand_int(1, max_lot);
    }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    morning_phase = market.tick < market.total_ticks / 5;
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }

    if !morning_phase { return; }
    if market.std_dev > 200_000 { return; }
    if price_history.len() < 5 { return; }

    let old_price = price_history[0];
    if old_price == 0 { return; }

    let old_ma5 = 0;
    let old_ma20 = 0;
    let history_len = market.history_len();
    if history_len >= 25 {
        let prices5 = [];
        let prices20 = [];
        let j = 0;
        while j < 25 {
            if j < 5 {
                prices5.push(market.history_price(j));
            }
            prices20.push(market.history_price(j));
            j += 1;
        }
        old_ma5 = arr_mean(prices5);
        old_ma20 = arr_mean(prices20);
    } else {
        return;
    }

    let current_ma5 = market.ma_5;
    let current_ma20 = market.ma_20;

    if current_ma5 > current_ma20 && old_ma5 <= old_ma20 && account.stock == 0 {
        orders.submit_market_buy(lot_size);
    }
    if current_ma5 < current_ma20 && old_ma5 >= old_ma20 && account.stock > 0 {
        orders.submit_market_sell(account.stock);
    }
}