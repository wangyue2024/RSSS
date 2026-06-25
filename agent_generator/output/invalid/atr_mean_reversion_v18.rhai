let initialized = false;
let lot_size = 0;
let panic_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let capital_percent = rng.rand_int(1, 5);
        let max_lot_value = account.total_equity * capital_percent / 100;
        if market.price > 0 {
            lot_size = max_lot_value / market.price;
            if lot_size < 1 {
                lot_size = 1;
            }
        } else {
            lot_size = 100;
        }
        let panic_pct = rng.rand_int(50, 150);
        panic_threshold = -account.total_equity * panic_pct / 10000;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let std_dev_threshold = market.price * 200 / 10000;
    if market.std_dev > std_dev_threshold {
        return;
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    let deviation = abs_val(market.price - market.ma_20);
    let atr_threshold = market.atr_14 * 3 / 2;

    if deviation > atr_threshold {
        if market.price > market.ma_20 && account.stock >= lot_size {
            orders.submit_limit_sell(market.price, lot_size);
        } else if market.price < market.ma_20 {
            let max_affordable = account.cash / market.price;
            let buy_amt = lot_size;
            if buy_amt > max_affordable {
                buy_amt = max_affordable;
            }
            if buy_amt > 0 {
                orders.submit_limit_buy(market.price, buy_amt);
            }
        }
    }
}