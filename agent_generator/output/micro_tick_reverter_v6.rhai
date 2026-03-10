let initialized = false;
let prev_price = 0;
let lot_size_factor = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size_factor = rng.rand_int(40, 50);
        prev_price = market.price;
        return;
    }

    if !market.trading_enabled {
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if prev_price == 0 {
        prev_price = market.price;
        return;
    }

    let price_change = market.price - prev_price;
    let spread = market.ask_price_0 - market.bid_price_0;

    if price_change < 0 {
        let max_cash_to_use = account.cash * lot_size_factor / 100;
        let amount = max_cash_to_use / market.price;
        if amount > 0 {
            let buy_price = market.bid_price_0 - 1;
            if buy_price > 0 {
                orders.submit_limit_buy(buy_price, amount);
            }
        }
    } else if price_change > 0 {
        let max_stock_to_sell = account.stock * lot_size_factor / 100;
        if max_stock_to_sell > 0 {
            let sell_price = market.ask_price_0 + 1;
            orders.submit_limit_sell(sell_price, max_stock_to_sell);
        }
    }

    prev_price = market.price;
}