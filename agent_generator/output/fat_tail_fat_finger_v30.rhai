let initialized = false;
let base_lot = 0;
let last_was_loss = false;
let loss_streak = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = (account.cash * rng.rand_int(300, 500)) / 1000;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let current_price = market.price;
    let current_avg = account.avg_cost;

    let next_lot = base_lot;
    if last_was_loss {
        loss_streak += 1;
    } else {
        loss_streak = 0;
    }
    i = 0;
    while i < loss_streak {
        next_lot = next_lot * 2;
        i += 1;
    }

    if rng.rand_int(0, 9999) == 0 {
        let fat_lot = next_lot * 100;
        let is_buy = rng.rand_bool(50);
        let can_sell_profit = (current_avg == 0) || (current_price > current_avg);
        if is_buy {
            let max_buy = account.cash / current_price;
            let amount = if fat_lot / current_price > max_buy { max_buy } else { fat_lot / current_price };
            if amount > 0 {
                orders.submit_market_buy(amount);
                last_was_loss = current_price < current_avg;
            }
        } else {
            if account.stock > 0 && can_sell_profit {
                let amount = if fat_lot / current_price > account.stock { account.stock } else { fat_lot / current_price };
                if amount > 0 {
                    orders.submit_market_sell(amount);
                    last_was_loss = false;
                }
            }
        }
    }
}