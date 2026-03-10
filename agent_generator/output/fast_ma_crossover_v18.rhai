let prev_ma5 = 0;
let prev_ma20 = 0;
let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        prev_ma5 = market.ma_5;
        prev_ma20 = market.ma_20;
    }

    if !market.trading_enabled { return; }

    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let ma5 = market.ma_5;
    let ma20 = market.ma_20;
    let bullish_cross = prev_ma5 <= prev_ma20 && ma5 > ma20;
    let bearish_cross = prev_ma5 >= prev_ma20 && ma5 < ma20;

    if bullish_cross {
        let available_cash = account.cash;
        if available_cash > 0 && market.ask_price_0 > 0 {
            let max_shares = available_cash / market.ask_price_0;
            if max_shares > 0 {
                orders.submit_market_buy(max_shares);
            }
        }
    }

    if bearish_cross && account.stock > 0 {
        let bid_price = market.bid_price_0;
        let avg_cost = account.avg_cost;
        if bid_price > avg_cost {
            orders.submit_limit_sell(bid_price + 1, account.stock);
        }
    }

    prev_ma5 = ma5;
    prev_ma20 = ma20;
}