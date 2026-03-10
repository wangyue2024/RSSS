let initialized = false;
let prev_ma5 = 0;
let prev_ma20 = 0;
let risk_percentage = 0;

fn round_to_dollar(price) {
    let half = 500_000;
    ((price + half) / 1_000_000) * 1_000_000
}

fn on_tick() {
    if !initialized {
        initialized = true;
        prev_ma5 = market.ma_5;
        prev_ma20 = market.ma_20;
        risk_percentage = rng.rand_int(45, 50);
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
    let bullish_cross = ma5 > ma20 && prev_ma5 <= prev_ma20;
    let bearish_cross = ma5 < ma20 && prev_ma5 >= prev_ma20;
    
    if bullish_cross {
        let buy_cash = account.cash * risk_percentage / 100;
        let buy_amount = buy_cash / market.price;
        if buy_amount > 0 {
            let round_price = round_to_dollar(market.price);
            orders.submit_limit_buy(round_price, buy_amount);
        }
    } else if bearish_cross && account.stock > 0 && market.price > account.avg_cost {
        let round_price = round_to_dollar(market.price);
        if round_price > account.avg_cost {
            orders.submit_limit_sell(round_price, account.stock);
        }
    }
    
    prev_ma5 = ma5;
    prev_ma20 = ma20;
}