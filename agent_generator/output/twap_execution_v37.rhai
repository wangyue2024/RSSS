let initialized = false;
let target_position = 0;
let slice_size = 0;
let interval_ticks = 0;
let next_trade_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        target_position = 50000;
        slice_size = rng.rand_int(25000, 12500);
        interval_ticks = rng.rand_int(1, 5);
        next_trade_tick = market.tick + rng.rand_int(0, interval_ticks);
    }

    if !market.trading_enabled {
        return;
    }

    let current_position = account.stock;
    let remaining_to_target = target_position - current_position;

    if remaining_to_target <= 0 {
        return;
    }

    if market.tick >= next_trade_tick {
        let max_cash_for_trade = account.cash * 50 / 100;
        let max_affordable_shares = max_cash_for_trade / market.price;
        let aggressive_slice = slice_size * 3 / 2;

        let buy_amount = aggressive_slice;
        if buy_amount > max_affordable_shares {
            buy_amount = max_affordable_shares;
        }
        if buy_amount > remaining_to_target {
            buy_amount = remaining_to_target;
        }

        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }

        next_trade_tick = market.tick + interval_ticks;
    }
}