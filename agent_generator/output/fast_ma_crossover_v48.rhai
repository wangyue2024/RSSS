let initialized = false;
let prev_ma5 = 0;
let prev_ma20 = 0;
let bet_pct = 0;

fn on_tick() {
    if !initialized {
        bet_pct = rng.rand_int(25, 50);
        prev_ma5 = market.ma_5;
        prev_ma20 = market.ma_20;
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

    let ma5 = market.ma_5;
    let ma20 = market.ma_20;

    let buy_cross = ma5 > ma20 && prev_ma5 <= prev_ma20;
    let sell_cross = ma5 < ma20 && prev_ma5 >= prev_ma20;

    if buy_cross && account.cash > 0 && market.ask_price_0 > 0 {
        let max_shares = account.cash / market.ask_price_0;
        let shares = (max_shares * bet_pct) / 100;
        if shares > 0 {
            orders.submit_market_buy(shares);
        }
    }

    if sell_cross && account.stock > 0 {
        orders.submit_market_sell(account.stock);
    }

    prev_ma5 = ma5;
    prev_ma20 = ma20;
}