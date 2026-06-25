let initialized = false;
let target_position = 0;
let slice_amount = 0;
let ticks_between_slices = 0;
let tick_counter = 0;
let panic_mode = false;
let volatility_threshold = 0;

fn on_tick() {
    if !initialized {
        target_position = 50000;
        let cash_in_shares = account.cash / market.price;
        slice_amount = rng.rand_int(1, cash_in_shares * 5 / 100);
        if slice_amount < 1 {
            slice_amount = 1;
        }
        ticks_between_slices = rng.rand_int(5, 30);
        volatility_threshold = market.price * 200 / 10000;
        initialized = true;
    }

    if !market.trading_enabled { return; }

    let current_position = account.stock;
    let remaining_to_buy = target_position - current_position;

    if remaining_to_buy <= 0 {
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }

    let high_volatility = market.std_dev > volatility_threshold;

    if !panic_mode {
        if market.history_len() >= 3 {
            let current_price = market.price;
            let price_3_ago = market.history_price(2);
            if price_3_ago > 0 {
                let change = (current_price - price_3_ago) * 10000 / price_3_ago;
                if change > 200 {
                    panic_mode = true;
                }
            }
        }
    }

    if panic_mode {
        let panic_buy_amount = remaining_to_buy;
        if panic_buy_amount > 0 {
            orders.submit_market_buy(panic_buy_amount);
        }
        return;
    }

    if high_volatility {
        return;
    }

    tick_counter += 1;

    if tick_counter >= ticks_between_slices {
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }

        let buy_amount = slice_amount;
        if buy_amount > remaining_to_buy {
            buy_amount = remaining_to_buy;
        }

        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
            tick_counter = 0;
        }
    }
}