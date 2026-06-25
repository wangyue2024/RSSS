let prev_ma5_above = false;
let initialized = false;
let buy_triggered = false;
let sell_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        prev_ma5_above = market.ma_5 > market.ma_20;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let current_ma5_above = market.ma_5 > market.ma_20;

    if current_ma5_above && !prev_ma5_above && !buy_triggered {
        let cash_available = account.cash;
        if cash_available > 0 {
            let target_price = if market.ask_price_0 != 0 { market.ask_price_0 } else { market.price };
            let buy_price = target_price + 1;
            let max_shares = cash_available / buy_price;
            if max_shares > 0 {
                orders.submit_limit_buy(buy_price, max_shares);
                buy_triggered = true;
                sell_triggered = false;
            }
        }
    } else if !current_ma5_above && prev_ma5_above && !sell_triggered {
        let stock_available = account.stock;
        if stock_available > 0 {
            let target_price = if market.bid_price_0 != 0 { market.bid_price_0 } else { market.price };
            let sell_price = target_price - 1;
            orders.submit_limit_sell(sell_price, stock_available);
            sell_triggered = true;
            buy_triggered = false;
        }
    }

    prev_ma5_above = current_ma5_above;
}