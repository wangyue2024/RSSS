let initialized = false;
let lot_size = 0;
let last_trade_was_loss = false;
let panic_threshold = 0;
let last_buy_price = 0;
let last_sell_price = 0;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        let capital = account.total_equity;
        let max_shares_by_capital = (capital * 5 / 100) / market.price;
        if max_shares_by_capital < 1 {
            lot_size = 1;
        } else {
            lot_size = rng.rand_int(1, max_shares_by_capital);
        }
        panic_threshold = rng.rand_int(-100000, -10000);
        initialized = true;
    }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let fill_count = my_orders.fill_count();
    let i = 0;
    while i < fill_count {
        let fill_side = my_orders.fill_side(i);
        let fill_price = my_orders.fill_price(i);
        if fill_side == 0 {
            last_buy_price = fill_price;
        } else {
            last_sell_price = fill_price;
            if last_buy_price != 0 && last_sell_price < last_buy_price {
                last_trade_was_loss = true;
            } else {
                last_trade_was_loss = false;
            }
        }
        i += 1;
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
    }

    let std_dev_threshold = market.price * 5 / 100;
    if market.std_dev > std_dev_threshold {
        return;
    }

    if last_trade_was_loss {
        lot_size = lot_size * 2;
        last_trade_was_loss = false;
    }

    let spread = market.high_20 - market.low_20;
    if spread < micros(0, 500) {
        lot_size = lot_size * 2;
    }

    let max_shares_by_capital = (account.total_equity * 5 / 100) / market.price;
    if max_shares_by_capital > 0 && lot_size > max_shares_by_capital {
        lot_size = max_shares_by_capital;
    }
    if lot_size <= 0 {
        lot_size = 1;
    }

    let buy_price = market.low_20 + micros(0, 100);
    let sell_price = market.high_20 - micros(0, 100);

    if buy_price >= sell_price {
        buy_price = market.low_20;
        sell_price = market.high_20;
        if buy_price >= sell_price {
            return;
        }
    }

    let cost = buy_price * lot_size;
    if cost > account.cash {
        lot_size = account.cash / buy_price;
        if lot_size == 0 {
            return;
        }
    }

    if lot_size > 0 {
        orders.submit_limit_buy(buy_price, lot_size);
    }

    if account.stock > 0 {
        let sell_amount = account.stock;
        if sell_amount > lot_size {
            sell_amount = lot_size;
        }
        orders.submit_limit_sell(sell_price, sell_amount);
    }
}