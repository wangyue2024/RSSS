let initialized = false;
let entry_price = 0;
let has_position = false;
let panic_threshold = 0;
let price_history = [];
let history_delay = 5;
let take_profit_order_id = 0;
let stop_loss_order_id = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = rng.rand_int(-50_000, -10_000);
    }

    if !market.trading_enabled { return; }

    if market.tick >= market.total_ticks / 5 {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }

    price_history.push(market.price);
    if price_history.len() > history_delay {
        price_history.remove(0);
    }

    if price_history.len() < history_delay {
        return;
    }

    let delayed_price = price_history[0];

    if !has_position && account.stock == 0 {
        if rng.rand_bool(1) {
            let buy_amount = 100;
            orders.submit_market_buy(buy_amount);
            entry_price = delayed_price;
            has_position = true;
            
            let tp_price = entry_price * 105 / 100;
            take_profit_order_id = orders.submit_limit_sell(tp_price, 100);
            
            let sl_price = entry_price * 98 / 100;
            stop_loss_order_id = orders.submit_limit_sell(sl_price, 100);
        }
        return;
    }

    if has_position && account.stock > 0 {
        if account.unrealized_pnl < panic_threshold {
            orders.submit_market_sell(account.stock);
            
            let pending_cnt = my_orders.pending_count();
            let i = 0;
            while i < pending_cnt {
                orders.submit_cancel(my_orders.pending_id(i));
                i += 1;
            }
            
            has_position = false;
            return;
        }

        if account.stock == 0 {
            has_position = false;
            let pending_cnt = my_orders.pending_count();
            let i = 0;
            while i < pending_cnt {
                orders.submit_cancel(my_orders.pending_id(i));
                i += 1;
            }
        } else {
            let sl_price = entry_price * 98 / 100;
            if delayed_price <= sl_price {
                orders.submit_market_sell(account.stock);
                
                let pending_cnt = my_orders.pending_count();
                let i = 0;
                while i < pending_cnt {
                    orders.submit_cancel(my_orders.pending_id(i));
                    i += 1;
                }
                
                has_position = false;
            }
        }
    }
}