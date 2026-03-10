let initialized = false;
let base_lot_size = 1000;
let current_lot_size = base_lot_size;
let last_trade_was_loss = false;
let entry_avg_cost = 0;
let position = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        current_lot_size = base_lot_size;
        last_trade_was_loss = false;
        entry_avg_cost = 0;
        position = 0;
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.stock == 0 {
        if last_trade_was_loss {
            current_lot_size = current_lot_size * 2;
            if current_lot_size > 1000000 {
                current_lot_size = 1000000;
            }
        } else {
            current_lot_size = base_lot_size;
        }

        let threshold = market.vwap * 50 / 10000;
        if market.price < market.vwap - threshold {
            let max_affordable = account.cash / market.price;
            let buy_amount = current_lot_size;
            if buy_amount > max_affordable {
                buy_amount = max_affordable;
            }
            if buy_amount > 0 {
                orders.submit_limit_buy(market.price, buy_amount);
            }
        }
    } else {
        if market.price >= market.vwap {
            orders.submit_limit_sell(market.vwap, account.stock);
        } else if account.avg_cost > 0 && market.price < account.avg_cost * 98 / 100 {
            last_trade_was_loss = true;
            orders.submit_market_sell(account.stock);
        }
    }

    if account.stock > 0 && account.avg_cost > 0 {
        if market.price < account.avg_cost * 98 / 100 {
            last_trade_was_loss = true;
        } else if market.price > account.avg_cost * 102 / 100 {
            last_trade_was_loss = false;
        }
    }
}