let initialized = false;
let prev_ma5 = 0;
let prev_ma20 = 0;
let price_history = [];
const HISTORY_LEN = 5;
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        price_history = [market.price];
        return;
    }

    if !market.trading_enabled { return; }

    let current_price = market.price;
    if price_history.len() < HISTORY_LEN {
        price_history.push(current_price);
    } else {
        price_history.remove_at(0);
        price_history.push(current_price);
    }

    fomo_triggered = false;
    if price_history.len() == HISTORY_LEN {
        let old_price = price_history[0];
        if old_price > 0 {
            let price_change_pct = (current_price - old_price) * 10000 / old_price;
            if price_change_pct > 200 {
                fomo_triggered = true;
            }
        }
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if fomo_triggered {
        if account.cash > 0 {
            let buy_amount = account.cash / current_price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        }
        prev_ma5 = market.ma_5;
        prev_ma20 = market.ma_20;
        return;
    }

    let ma5 = market.ma_5;
    let ma20 = market.ma_20;
    
    if ma5 == 0 || ma20 == 0 {
        prev_ma5 = ma5;
        prev_ma20 = ma20;
        return;
    }

    let bullish_cross = prev_ma5 <= prev_ma20 && ma5 > ma20;
    let bearish_cross = prev_ma5 >= prev_ma20 && ma5 < ma20;

    if bullish_cross && account.cash > 0 {
        let buy_amount = account.cash / current_price;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
    } else if bearish_cross && account.stock > 0 {
        orders.submit_market_sell(account.stock);
    }

    prev_ma5 = ma5;
    prev_ma20 = ma20;
}