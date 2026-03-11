let initialized = false;
let lot_size = 0;
let tick_counter = 0;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        initialized = true;
        let cash_percent = rng.rand_int(30, 50);
        let cash_to_use = account.cash * cash_percent / 100;
        lot_size = cash_to_use / market.price;
        if lot_size == 0 {
            lot_size = 1;
        }
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    tick_counter += 1;
    if tick_counter % 10 != 0 {
        return;
    }

    let equity = account.total_equity;
    if equity == 0 {
        return;
    }
    let stock_value = account.stock * market.price;
    let stock_pct = stock_value * 10000 / equity;

    if stock_pct > 5500 && market.price > account.avg_cost {
        let sell_amount = lot_size;
        if sell_amount > account.stock {
            sell_amount = account.stock;
        }
        if sell_amount > 0 {
            orders.submit_limit_sell(market.price, sell_amount);
        }
    } else if stock_pct < 4500 {
        let buy_amount = lot_size;
        let max_affordable = account.cash / market.price;
        if buy_amount > max_affordable {
            buy_amount = max_affordable;
        }
        if buy_amount > 0 {
            let bid_price = market.price + 1;
            orders.submit_limit_buy(bid_price, buy_amount);
        }
    }
}