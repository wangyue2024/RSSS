let entered = false;
let take_profit_placed = false;

fn on_tick() {
    if !market.trading_enabled { return; }

    if market.tick > market.total_ticks / 5 {
        return;
    }

    if account.stock == 0 {
        entered = false;
        take_profit_placed = false;
    }

    if !entered {
        let fomo_triggered = false;
        if market.history_len() >= 5 {
            let old_price = market.history_price(5);
            if (market.price - old_price) * 100 > old_price * 2 {
                fomo_triggered = true;
            }
        }

        if fomo_triggered {
            let amount = 100;
            orders.submit_market_buy(amount);
            entered = true;
        } else {
            if rng.rand_bool(1) {
                let amount = 100;
                orders.submit_market_buy(amount);
                entered = true;
            }
        }
    }

    if entered && account.stock > 0 {
        if market.price <= account.avg_cost && take_profit_placed {
            let pending_cnt = my_orders.pending_count();
            let i = 0;
            while i < pending_cnt {
                let oid = my_orders.pending_id(i);
                orders.submit_cancel(oid);
                i += 1;
            }
            take_profit_placed = false;
        }

        if market.price > account.avg_cost && !take_profit_placed {
            let take_profit_price = account.avg_cost * 105 / 100;
            orders.submit_limit_sell(take_profit_price, account.stock);
            take_profit_placed = true;
        }
    }
}