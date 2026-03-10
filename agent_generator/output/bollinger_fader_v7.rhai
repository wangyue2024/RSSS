let initialized = false;
let stop_loss_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_threshold = -account.total_equity * rng.rand_int(1, 5) / 100;
    }

    if !market.trading_enabled { return; }

    // Panic stop-loss check
    if account.unrealized_pnl < stop_loss_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        // Cancel all orders
        let p_count = my_orders.pending_count();
        let i = 0;
        while i < p_count {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }

    // Cancel all pending orders
    let p_count = my_orders.pending_count();
    let i = 0;
    while i < p_count {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }

    // Calculate Bollinger Bands
    let middle = market.ma_20;
    let upper_band = middle + 2 * market.std_dev;
    let lower_band = middle - 2 * market.std_dev;

    // Place limit buy at lower band if we have cash
    let buy_amount = 10;
    let buy_cost = lower_band * buy_amount;
    if account.cash >= buy_cost && buy_amount > 0 {
        orders.submit_limit_buy(lower_band, buy_amount);
    }

    // Place limit sell at upper band if we have stock
    let sell_amount = 10;
    if account.stock >= sell_amount && sell_amount > 0 {
        orders.submit_limit_sell(upper_band, sell_amount);
    }
}