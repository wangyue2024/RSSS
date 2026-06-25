let initialized = false;
let trade_active = false;
let lot_size = 0;
let last_trade_was_loss = false;
let take_profit_order_id = -1;
let entry_avg_cost = 0;
let stop_loss_price = 0;
let take_profit_price = 0;

fn on_tick() {
    if !initialized {
        let five_percent_capital = account.total_equity * 5 / 100;
        if market.price > 0 {
            let max_shares = five_percent_capital / market.price;
            if max_shares > 0 {
                lot_size = rng.rand_int(1, max_shares);
            } else {
                lot_size = 1;
            }
        }
        initialized = true;
    }

    if !market.trading_enabled { return; }

    let vol_threshold = market.price * 2 / 100;
    if market.std_dev > vol_threshold {
        let pending_cnt = my_orders.pending_count();
        let j = 0;
        while j < pending_cnt {
            orders.submit_cancel(my_orders.pending_id(j));
            j += 1;
        }
        trade_active = false;
        take_profit_order_id = -1;
        return;
    }

    if trade_active {
        let stop_triggered = market.price <= stop_loss_price;
        let take_profit_filled = false;

        let i = 0;
        let pcount = my_orders.pending_count();
        while i < pcount {
            if my_orders.pending_id(i) == take_profit_order_id {
                take_profit_filled = false;
                break;
            }
            i += 1;
        }

        let fcount = my_orders.fill_count();
        i = 0;
        while i < fcount {
            if my_orders.fill_id(i) == take_profit_order_id {
                take_profit_filled = true;
                break;
            }
            i += 1;
        }

        if stop_triggered {
            if take_profit_order_id != -1 {
                orders.submit_cancel(take_profit_order_id);
            }
            if account.stock > 0 {
                orders.submit_market_sell(account.stock);
            }
            if market.price < entry_avg_cost {
                last_trade_was_loss = true;
                lot_size = lot_size * 2;
            } else {
                last_trade_was_loss = false;
            }
            trade_active = false;
            take_profit_order_id = -1;
        } else if take_profit_filled {
            if market.price < entry_avg_cost {
                last_trade_was_loss = true;
                lot_size = lot_size * 2;
            } else {
                last_trade_was_loss = false;
            }
            trade_active = false;
            take_profit_order_id = -1;
        }
        return;
    }

    if account.stock == 0 && !trade_active {
        let cost_estimate = market.price * lot_size;
        if account.cash >= cost_estimate && rng.rand_bool(50) {
            orders.submit_market_buy(lot_size);
            entry_avg_cost = account.avg_cost;
            stop_loss_price = entry_avg_cost * 98 / 100;
            take_profit_price = entry_avg_cost * 105 / 100;
            take_profit_order_id = orders.submit_limit_sell(take_profit_price, lot_size);
            trade_active = true;
        }
    }
}