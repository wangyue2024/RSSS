let initialized = false;
let stop_loss_threshold = 0;
let prev_ma_5 = 0;
let prev_ma_20 = 0;
let position_held = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_threshold = -rng.rand_int(10_000, 50_000);
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.stock > 0 && account.unrealized_pnl < stop_loss_threshold {
        orders.submit_market_sell(account.stock);
        position_held = false;
        return;
    }

    let current_ma_5 = market.ma_5;
    let current_ma_20 = market.ma_20;
    let ma5_above_ma20 = current_ma_5 > current_ma_20;
    let prev_ma5_above_ma20 = prev_ma_5 > prev_ma_20;

    if !position_held && ma5_above_ma20 && !prev_ma5_above_ma20 {
        let max_affordable = account.cash / market.price;
        let buy_amount = if max_affordable > 100 { 100 } else { max_affordable };
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
            position_held = true;
        }
    }

    if position_held && !ma5_above_ma20 && prev_ma5_above_ma20 {
        orders.submit_market_sell(account.stock);
        position_held = false;
    }

    prev_ma_5 = current_ma_5;
    prev_ma_20 = current_ma_20;
}