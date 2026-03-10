let initialized = false;
let my_quote_amount = 0;
let my_base_spread = 0;
let my_vol_multiplier = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        my_quote_amount = rng.rand_int(80, 120);
        my_base_spread = rng.rand_int(40, 60);
        my_vol_multiplier = rng.rand_int(8, 12);
    }

    if !market.trading_enabled { return; }

    let is_morning = market.tick < (market.total_ticks / 5);
    let is_evaluation_tick = market.tick % 50 == 0;

    if !is_morning || !is_evaluation_tick {
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let fair_price = market.price;
    let vol_factor = market.std_dev;

    let spread_offset = (vol_factor * my_vol_multiplier) / 1_000_000;
    let total_spread = my_base_spread + spread_offset;

    let buy_price = fair_price - total_spread;
    let sell_price = fair_price + total_spread;

    let buy_amount = my_quote_amount;
    let sell_amount = my_quote_amount;

    let max_buy_with_cash = account.cash / buy_price;
    let actual_buy = if buy_amount > max_buy_with_cash { max_buy_with_cash } else { buy_amount };
    let actual_sell = if sell_amount > account.stock { account.stock } else { sell_amount };

    if actual_buy > 0 && buy_price > 0 {
        orders.submit_limit_buy(buy_price, actual_buy);
    }
    if actual_sell > 0 && sell_price > 0 {
        orders.submit_limit_sell(sell_price, actual_sell);
    }
}