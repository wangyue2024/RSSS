let initialized = false;
let lot_size = 0;
let panic_threshold = 0;
let cooldown_ticks = 0;
let last_trade_tick = 0;

fn round_to_dollar(price) {
    let rem = price % 1_000_000;
    if rem < 500_000 {
        price - rem
    } else {
        price - rem + 1_000_000
    }
}

fn on_tick() {
    if !initialized {
        initialized = true;
        let capital = account.total_equity;
        let max_lot_value = capital * 5 / 100;
        let price = market.price;
        if price > 0 {
            let max_shares = max_lot_value / price;
            if max_shares < 20 {
                lot_size = max_shares;
            } else {
                let upper = if max_shares > 100 { 100 } else { max_shares };
                lot_size = rng.rand_int(20, upper);
            }
        }
        if lot_size < 1 { lot_size = 1; }
        panic_threshold = -rng.rand_int(10_000, 100_000);
        cooldown_ticks = rng.rand_int(50, 200);
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    if market.std_dev > (market.price * 200 / 10000) {
        return;
    }

    let current_tick = market.tick;
    if current_tick - last_trade_tick < cooldown_ticks {
        return;
    }

    let rsi = market.rsi_14;
    let price = market.price;

    if rsi < 3000 && account.cash > 0 {
        let target_price = price * 9950 / 10000;
        let buy_price = round_to_dollar(target_price);
        if buy_price > 0 && buy_price < price {
            let max_affordable = account.cash / buy_price;
            let buy_amount = if max_affordable < lot_size { max_affordable } else { lot_size };
            if buy_amount > 0 {
                orders.submit_limit_buy(buy_price, buy_amount);
                last_trade_tick = current_tick;
            }
        }
    } else if rsi > 7000 && account.stock > 0 {
        let target_price = price * 10050 / 10000;
        let sell_price = round_to_dollar(target_price);
        if sell_price > price && sell_price > 0 {
            let sell_amount = if account.stock < lot_size { account.stock } else { lot_size };
            if sell_amount > 0 {
                orders.submit_limit_sell(sell_price, sell_amount);
                last_trade_tick = current_tick;
            }
        }
    }
}