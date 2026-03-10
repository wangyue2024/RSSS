let initialized = false;
let has_entered = false;
let entry_price = 0;
let panic_threshold = 0;
let take_profit_id = 0;
let stop_loss_id = 0;
let session_ticks = 0;

fn on_tick() {
    if !initialized {
        panic_threshold = -rng.rand_int(10_000, 50_000);
        initialized = true;
    }

    if !market.trading_enabled { return; }

    if session_ticks == 0 {
        session_ticks = market.total_ticks;
    }

    let is_morning = market.tick < session_ticks / 5;

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        if oid != take_profit_id && oid != stop_loss_id {
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    if !has_entered && is_morning && account.stock == 0 {
        if rng.rand_bool(5) {
            let bid = market.bid_price_0;
            if bid != 0 {
                let buy_price = bid + 1;
                let cash_available = account.cash;
                let amount = cash_available / buy_price;
                if amount > 0 {
                    orders.submit_limit_buy(buy_price, amount);
                }
            }
        }
    }

    let fill_cnt = my_orders.fill_count();
    i = 0;
    while i < fill_cnt {
        let side = my_orders.fill_side(i);
        if side == 0 && account.stock > 0 && entry_price == 0 {
            entry_price = account.avg_cost;
            has_entered = true;

            let take_profit_price = entry_price * 105 / 100;
            take_profit_id = orders.submit_limit_sell(take_profit_price, account.stock);

            let stop_price = entry_price * 98 / 100;
            stop_loss_id = orders.submit_limit_sell(stop_price, account.stock);
        }
        i += 1;
    }

    if account.stock > 0 && entry_price != 0 {
        if account.unrealized_pnl < panic_threshold {
            orders.submit_market_sell(account.stock);
            if take_profit_id != 0 {
                orders.submit_cancel(take_profit_id);
                take_profit_id = 0;
            }
            if stop_loss_id != 0 {
                orders.submit_cancel(stop_loss_id);
                stop_loss_id = 0;
            }
            entry_price = 0;
            has_entered = false;
        }

        let stop_price = entry_price * 98 / 100;
        if market.price <= stop_price && stop_loss_id != 0 {
            orders.submit_cancel(stop_loss_id);
            orders.submit_market_sell(account.stock);
            if take_profit_id != 0 {
                orders.submit_cancel(take_profit_id);
                take_profit_id = 0;
            }
            stop_loss_id = 0;
            entry_price = 0;
            has_entered = false;
        }
    }

    if account.stock == 0 {
        entry_price = 0;
        has_entered = false;
        take_profit_id = 0;
        stop_loss_id = 0;
    }
}