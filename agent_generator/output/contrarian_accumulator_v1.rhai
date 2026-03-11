let initialized = false;
let last_buy_tick = -100;
let last_sell_tick = -100;
let base_amount = 0;
let cooldown_ticks = 10;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_amount = rng.rand_int(20, 100);
    }

    if !market.trading_enabled { return; }
    let current_tick = market.tick;

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    let has_pending_buy = false;
    let has_pending_sell = false;
    let pending_count2 = my_orders.pending_count();
    let j = 0;
    while j < pending_count2 {
        let side = my_orders.pending_side(j);
        if side == 0 {
            has_pending_buy = true;
        } else {
            has_pending_sell = true;
        }
        j += 1;
    }

    if market.rsi_14 < 3000 && !has_pending_buy && current_tick - last_buy_tick >= cooldown_ticks {
        let base_price = market.bid_price_0;
        let half_dollar = 500_000;
        let rounded = ((base_price + half_dollar) / 1_000_000) * 1_000_000;
        let buy_price = rounded + 1;
        let cash_needed = buy_price * base_amount;
        if account.cash >= cash_needed {
            orders.submit_limit_buy(buy_price, base_amount);
            last_buy_tick = current_tick;
        }
    }

    if market.rsi_14 > 7000 && !has_pending_sell && current_tick - last_sell_tick >= cooldown_ticks {
        let base_price = market.ask_price_0;
        let half_dollar = 500_000;
        let rounded = ((base_price + half_dollar) / 1_000_000) * 1_000_000;
        let sell_price = rounded;
        if account.stock >= base_amount {
            orders.submit_limit_sell(sell_price, base_amount);
            last_sell_tick = current_tick;
        }
    }
}