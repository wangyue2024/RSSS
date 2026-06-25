let initialized = false;
let lot_size = 0;
let panic_threshold = 0;
let delayed_price = 0;
let price_history = [];
let tick_counter = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let five_percent = account.total_equity * 5 / 100;
        lot_size = rng.rand_int(1, five_percent / 1000);
        if lot_size == 0 { lot_size = 1; }
        panic_threshold = -rng.rand_int(50000, 200000);
    }

    if !market.trading_enabled { return; }

    tick_counter += 1;

    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    if price_history.len() == 5 {
        delayed_price = price_history[0];
    }

    let pnl = account.unrealized_pnl;
    if pnl < panic_threshold {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }

    let std_dev_threshold = market.price * 5 / 100;
    if market.std_dev > std_dev_threshold {
        return;
    }

    if price_history.len() < 5 {
        return;
    }

    let rebalance_interval = 10;
    if tick_counter % rebalance_interval != 0 {
        return;
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let stock_value = account.stock * market.price;
    let total = account.total_equity;
    if total == 0 {
        return;
    }

    let stock_pct = stock_value * 100 / total;
    let target_pct = 50;
    let upper_band = 55;
    let lower_band = 45;

    if stock_pct > upper_band {
        let target_value = total * target_pct / 100;
        let excess_value = stock_value - target_value;
        let shares_to_sell = excess_value / delayed_price;
        if shares_to_sell > 0 {
            let sell_amount = shares_to_sell;
            if sell_amount > lot_size {
                sell_amount = lot_size;
            }
            if sell_amount > 0 {
                orders.submit_limit_sell(delayed_price, sell_amount);
            }
        }
    } else if stock_pct < lower_band {
        let target_value = total * target_pct / 100;
        let deficit_value = target_value - stock_value;
        let shares_to_buy = deficit_value / delayed_price;
        if shares_to_buy > 0 {
            let buy_amount = shares_to_buy;
            if buy_amount > lot_size {
                buy_amount = lot_size;
            }
            if buy_amount > 0 {
                orders.submit_limit_buy(delayed_price, buy_amount);
            }
        }
    }
}