let initialized = false;
let trade_capital = 0;
let lot_size = 0;
let prev_tick = -1;

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_cap = (account.total_equity * 5) / 100;
        trade_capital = rng.rand_int(1, max_cap);
        if trade_capital < market.price {
            trade_capital = market.price;
        }
        lot_size = trade_capital / market.price;
        if lot_size <= 0 {
            lot_size = 1;
        }
    }

    if !market.trading_enabled { return; }
    if market.tick == prev_tick { return; }
    prev_tick = market.tick;

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let std_dev_threshold = market.price / 20;
    if market.std_dev > std_dev_threshold {
        return;
    }

    let deviation = abs_val(market.price - market.ma_20);
    let atr_threshold = (market.atr_14 * 3) / 2;
    let buy_signal = false;
    let sell_signal = false;

    if deviation > atr_threshold {
        if market.price < market.ma_20 {
            buy_signal = true;
        } else {
            sell_signal = true;
        }
    }

    if buy_signal {
        let base_price = if market.bid_price_0 > 0 { market.bid_price_0 } else { market.price };
        let bid_price = base_price + 1;
        let available_cash = account.cash - 1000000;
        let max_shares = available_cash / bid_price;
        let shares_to_buy = if max_shares < lot_size { max_shares } else { lot_size };
        if shares_to_buy > 0 {
            orders.submit_limit_buy(bid_price, shares_to_buy);
        }
    }

    if sell_signal {
        let base_price = if market.ask_price_0 > 0 { market.ask_price_0 } else { market.price };
        let ask_price = base_price - 1;
        let shares_to_sell = if account.stock < lot_size { account.stock } else { lot_size };
        if shares_to_sell > 0 {
            orders.submit_limit_sell(ask_price, shares_to_sell);
        }
    }
}