let initialized = false;
let base_lot_size = 0;
let loss_streak = 0;
let prev_slope = 0;
let lookback = 10;
let slope_threshold = 2000;
let panic_slope = -1500;

fn on_tick() {
    if !initialized {
        initialized = true;
        let total_cap = account.total_equity;
        base_lot_size = total_cap * rng.rand_int(100, 500) / 10000;
        if base_lot_size == 0 {
            base_lot_size = 100000;
        }
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

    if market.history_len() < lookback {
        return;
    }

    let prices = [];
    let idx = 0;
    while idx < lookback {
        prices.push(market.history_price(idx));
        idx += 1;
    }
    let current_slope = arr_slope(prices);

    let in_loss = account.stock > 0 && market.price < account.avg_cost;
    if in_loss {
        loss_streak = loss_streak + 1;
        if loss_streak > 10 {
            loss_streak = 10;
        }
    } else {
        loss_streak = 0;
    }

    let multiplier = 1;
    let j = 0;
    while j < loss_streak {
        multiplier = multiplier * 2;
        j += 1;
    }
    let lot_size = base_lot_size * multiplier;
    if lot_size > account.cash / 2 {
        lot_size = account.cash / 2;
    }

    let amount = lot_size * 1_000_000 / market.price;
    if amount < 1 {
        amount = 1;
    }

    if current_slope > slope_threshold && current_slope > prev_slope {
        let max_buy = account.cash / market.price;
        let buy_amount = amount;
        if buy_amount > max_buy {
            buy_amount = max_buy;
        }
        if buy_amount > 0 {
            orders.submit_limit_buy(market.price, buy_amount);
        }
    }

    if prev_slope > 0 && current_slope < panic_slope {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
    }

    prev_slope = current_slope;
}