let initialized = false;
let lot_size_pct = 0;
let last_prices = [];
let pending_buy_id = -1;
let pending_buy_ticks = 0;
let stop_loss_offset = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size_pct = rng.rand_int(25, 50);
        stop_loss_offset = rng.rand_int(500, 2000);
    }

    if !market.trading_enabled { return; }

    last_prices.push(market.price);
    if last_prices.len() > 3 {
        last_prices.remove(0);
    }

    let fomo_triggered = false;
    if last_prices.len() >= 3 {
        let old_price = last_prices[0];
        let change_pct = (market.price - old_price) * 10000 / old_price;
        if change_pct > 200 {
            fomo_triggered = true;
            let buy_amount = account.cash * lot_size_pct / (100 * market.price);
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        }
    }

    if !fomo_triggered {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        pending_buy_id = -1;
        pending_buy_ticks = 0;

        if market.price > market.high_20 {
            let buy_amount = account.cash * lot_size_pct / (100 * market.price);
            if buy_amount > 0 {
                let order_id = orders.submit_limit_buy(market.price, buy_amount);
                pending_buy_id = order_id;
                pending_buy_ticks = market.tick;
            }
        }
    }

    if pending_buy_id != -1 && (market.tick - pending_buy_ticks) > 3 {
        orders.submit_cancel(pending_buy_id);
        pending_buy_id = -1;
        pending_buy_ticks = 0;
    }

    if account.stock > 0 {
        let stop_price = account.avg_cost - stop_loss_offset;
        if market.price < stop_price {
            orders.submit_market_sell(account.stock);
        }
    }
}