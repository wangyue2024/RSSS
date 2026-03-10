let initialized = false;
let stop_loss_threshold = 0;
let last_decision_tick = -50;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        stop_loss_threshold = -rng.rand_int(5000, 20000);
        initialized = true;
    }

    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }

    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    if market.tick - last_decision_tick >= 50 {
        last_decision_tick = market.tick;

        if market.buy_volume * 10000 > market.sell_volume * 30000 && market.ask_price_0 > 0 {
            let max_buy = account.cash / market.ask_price_0;
            let buy_amount = clamp_val(max_buy, 0, 100);
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        }
    }
}