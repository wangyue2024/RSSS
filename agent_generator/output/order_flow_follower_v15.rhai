let initialized = false;
let stop_loss_threshold = 0;
let trade_size = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_threshold = -rng.rand_int(10_000, 100_000);
    }

    if !market.trading_enabled {
        return;
    }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    if market.buy_volume > 3 * market.sell_volume && market.price > 0 {
        let max_affordable = account.cash / market.price;
        let buy_amount = trade_size;
        if max_affordable < buy_amount {
            buy_amount = max_affordable;
        }
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
    }

    if market.sell_volume > 3 * market.buy_volume && account.stock > 0 {
        let sell_amount = trade_size;
        if account.stock < sell_amount {
            sell_amount = account.stock;
        }
        if sell_amount > 0 {
            orders.submit_market_sell(sell_amount);
        }
    }
}