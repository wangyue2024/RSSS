let initialized = false;
let entered = false;
let entry_price = 0;
let lot_size = 0;
let take_profit_order_id = 0;
let will_enter_randomly = false;
let last_fomo_check = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        will_enter_randomly = rng.rand_bool(50);
        last_fomo_check = market.total_ticks;
    }

    if !market.trading_enabled { return; }

    let current_price = market.price;
    let std_dev_high = market.std_dev * 10000 > current_price * 100;

    if entered && account.stock > 0 {
        let take_profit_pending = false;
        let i = 0;
        let pending_cnt = my_orders.pending_count();
        while i < pending_cnt {
            if my_orders.pending_id(i) == take_profit_order_id {
                take_profit_pending = true;
                break;
            }
            i += 1;
        }

        if !take_profit_pending {
            entered = false;
            entry_price = 0;
            lot_size = 0;
        } else {
            let stop_price = entry_price * 98 / 100;
            if current_price <= stop_price {
                orders.submit_cancel(take_profit_order_id);
                orders.submit_market_sell(account.stock);
                entered = false;
                entry_price = 0;
                lot_size = 0;
            }
        }
    }

    if !entered {
        let fomo_triggered = false;
        if market.total_ticks - last_fomo_check >= 5 {
            last_fomo_check = market.total_ticks;
            if market.history_len() >= 5 {
                let min_price = current_price;
                let j = 0;
                while j < 5 {
                    let p = market.history_price(j);
                    if p < min_price {
                        min_price = p;
                    }
                    j += 1;
                }
                if (current_price - min_price) * 100 >= min_price * 2 {
                    fomo_triggered = true;
                }
            }
        }

        if !std_dev_high && (fomo_triggered || (will_enter_randomly && !std_dev_high)) {
            let max_capital = account.total_equity * 5 / 100;
            let max_shares = max_capital / current_price;
            if max_shares > 0 {
                let shares = rng.rand_int(1, max_shares);
                orders.submit_market_buy(shares);
                entry_price = current_price;
                lot_size = shares;
                entered = true;
                let tp_price = entry_price * 105 / 100;
                take_profit_order_id = orders.submit_limit_sell(tp_price, lot_size);
                if fomo_triggered {
                    will_enter_randomly = false;
                }
            }
        }
    }
}