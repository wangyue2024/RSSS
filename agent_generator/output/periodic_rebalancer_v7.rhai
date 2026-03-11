let initialized = false;
let lot_size = 0;
let last_rebalance_tick = -10;
let threshold_std_dev = 300_000;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        let total_cap = account.cash + account.stock * market.price;
        let five_percent_value = total_cap * 5 / 100;
        let max_shares = five_percent_value / market.price;
        if max_shares < 1 {
            lot_size = 1;
        } else {
            lot_size = rng.rand_int(1, max_shares);
        }
        initialized = true;
    }

    if market.std_dev > threshold_std_dev {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }

    if market.tick - last_rebalance_tick < 10 {
        return;
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let equity = account.total_equity;
    let stock_value = account.stock * market.price;
    let stock_pct = stock_value * 100 / equity;

    if stock_pct > 55 {
        let target_value = equity / 2;
        let excess_value = stock_value - target_value;
        let shares_to_sell = excess_value / market.price;
        let sell_amount = shares_to_sell;
        if sell_amount > lot_size {
            sell_amount = lot_size;
        }
        if sell_amount > 0 {
            let sell_price = market.bid_price_0;
            if sell_price == 0 {
                sell_price = market.price;
            }
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    } else if stock_pct < 45 {
        let target_value = equity / 2;
        let deficit_value = target_value - stock_value;
        let shares_to_buy = deficit_value / market.price;
        let buy_amount = shares_to_buy;
        if buy_amount > lot_size {
            buy_amount = lot_size;
        }
        if buy_amount > 0 {
            let buy_price = market.ask_price_0;
            if buy_price == 0 {
                buy_price = market.price;
            }
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    }

    last_rebalance_tick = market.tick;
}