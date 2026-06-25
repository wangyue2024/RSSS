let initialized = false;
let stop_loss_threshold = 0;
let trade_percent = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_threshold = -rng.rand_int(100000, 500000);
        trade_percent = rng.rand_int(1500, 3000);
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    let deviation = market.price - market.ma_20;
    let atr_threshold = (market.atr_14 * 15) / 10;

    if deviation > atr_threshold && account.stock > 0 {
        let sell_amount = (account.stock * trade_percent) / 10000;
        if sell_amount > 0 {
            let sell_price = market.price - (market.atr_14 * 5) / 100;
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    } else if deviation < -atr_threshold {
        let cash_to_use = (account.cash * trade_percent) / 10000;
        if cash_to_use > 0 && market.price > 0 {
            let buy_amount = cash_to_use / market.price;
            if buy_amount > 0 {
                let buy_price = market.price + (market.atr_14 * 5) / 100;
                orders.submit_limit_buy(buy_price, buy_amount);
            }
        }
    }
}