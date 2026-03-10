let initialized = false;
let target_shares = 0;
let remaining_to_buy = 0;
let base_slice = 10000;
let participation_rate = 10;
let total_ticks_session = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        target_shares = rng.rand_int(50000, 200000);
        remaining_to_buy = target_shares;
        base_slice = rng.rand_int(8000, 12000);
        participation_rate = rng.rand_int(8, 15);
    }

    if !market.trading_enabled { return; }

    if total_ticks_session == 0 {
        total_ticks_session = market.total_ticks;
    }

    if market.tick >= total_ticks_session / 5 {
        let pc = my_orders.pending_count();
        let j = 0;
        while j < pc {
            orders.submit_cancel(my_orders.pending_id(j));
            j += 1;
        }
        return;
    }

    let fc = my_orders.fill_count();
    let i = 0;
    while i < fc {
        let side = my_orders.fill_side(i);
        let amt = my_orders.fill_amount(i);
        if side == 0 {
            remaining_to_buy -= amt;
        }
        i += 1;
    }

    let pc = my_orders.pending_count();
    let j = 0;
    while j < pc {
        orders.submit_cancel(my_orders.pending_id(j));
        j += 1;
    }

    if remaining_to_buy <= 0 { return; }

    let hist_len = market.history_len();
    let lookback = 5;
    if lookback > hist_len {
        lookback = hist_len;
    }
    let total_volume = 0;
    let k = 0;
    while k < lookback {
        total_volume += market.history_volume(hist_len - 1 - k);
        k += 1;
    }
    let avg_volume = total_volume / lookback;
    let recent_vol = market.volume;
    if recent_vol == 0 { recent_vol = 1; }

    let volume_ratio = recent_vol * 100 / avg_volume;
    let dynamic_slice = base_slice * volume_ratio / 100;
    let slice = dynamic_slice;
    if slice < 100 { slice = 100; }
    if slice > remaining_to_buy { slice = remaining_to_buy; }

    let vwap = market.vwap;
    let bid_price = vwap + 1;

    if slice > 0 && account.cash >= bid_price * slice {
        orders.submit_limit_buy(bid_price, slice);
    }

    if account.stock > 0 && market.price > account.avg_cost {
        let ask_price = market.ask_price_0;
        if ask_price > 0 && ask_price > account.avg_cost {
            let sell_amt = account.stock / 10;
            if sell_amt > 0 {
                orders.submit_limit_sell(ask_price, sell_amt);
            }
        }
    }
}