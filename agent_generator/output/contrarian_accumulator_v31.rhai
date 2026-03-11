let initialized = false;
let base_lot_size = 0;

fn round_to_dollar(price_micros) {
    let remainder = price_micros % 1_000_000;
    if remainder >= 500_000 {
        return price_micros - remainder + 1_000_000;
    } else {
        return price_micros - remainder;
    }
}

fn on_tick() {
    if !initialized {
        base_lot_size = rng.rand_int(20, 100);
        initialized = true;
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

    let rsi = market.rsi_14;
    let price = market.price;
    let avg_cost = account.avg_cost;

    if rsi < 3000 {
        let raw_limit_price = price - 500_000;
        let limit_price = round_to_dollar(raw_limit_price);
        if limit_price <= 0 {
            limit_price = 1_000_000;
        }

        let max_by_cash = (account.cash * 50) / (100 * limit_price);
        let buy_amount = base_lot_size;
        if max_by_cash < buy_amount {
            buy_amount = max_by_cash;
        }
        if buy_amount < 1 {
            buy_amount = 1;
        }

        if buy_amount >= 1 && limit_price > 0 {
            orders.submit_limit_buy(limit_price, buy_amount);
        }
    } else if rsi > 7000 && price > avg_cost && account.stock > 0 {
        let raw_limit_price = price + 500_000;
        let limit_price = round_to_dollar(raw_limit_price);

        let sell_amount = base_lot_size;
        if account.stock < sell_amount {
            sell_amount = account.stock;
        }

        if sell_amount >= 1 && limit_price > avg_cost {
            orders.submit_limit_sell(limit_price, sell_amount);
        }
    }
}