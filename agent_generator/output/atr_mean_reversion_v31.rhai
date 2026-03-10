let initialized = false;
let trade_amount = 0;
let buy_threshold = 0;
let sell_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        trade_amount = rng.rand_int(90, 110);
        buy_threshold = 150;
        sell_threshold = 150;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.ma_20 == 0 || market.atr_14 == 0 { return; }

    let current_price = market.price;
    let ma = market.ma_20;
    let atr = market.atr_14;

    let deviation = current_price - ma;
    let atr_threshold = (atr * 150) / 100;

    let buy_signal = deviation < 0 && abs_val(deviation) > atr_threshold;
    let sell_signal = deviation > 0 && deviation > atr_threshold;

    let can_buy = account.cash >= current_price && trade_amount > 0;
    let can_sell = account.stock >= trade_amount && trade_amount > 0;

    if buy_signal && can_buy && market.bid_price_0 > 0 {
        let bid_price = market.bid_price_0 + 1;
        let amount = trade_amount;
        orders.submit_limit_buy(bid_price, amount);
    }

    if sell_signal && can_sell && market.ask_price_0 > 0 {
        let ask_price = market.ask_price_0;
        let amount = trade_amount;
        orders.submit_limit_sell(ask_price, amount);
    }
}