let initialized = false;
let base_lot_size = 0;
let loss_streak = 0;
let last_trade_profit = 0;
let current_lot_size = 0;
let vwap_threshold = 0;
let exit_threshold = 0;
let max_streak = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(50, 200);
        vwap_threshold = rng.rand_int(50, 200);
        exit_threshold = rng.rand_int(10, 50);
        max_streak = rng.rand_int(1, 4);
        current_lot_size = base_lot_size;
    }

    if !market.trading_enabled { return; }

    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }

    if account.stock > 0 {
        let avg_cost = account.avg_cost;
        let exit_target = avg_cost + (avg_cost * exit_threshold / 10000);
        if market.price >= exit_target {
            let sell_amount = account.stock;
            if sell_amount > 0 {
                orders.submit_limit_sell(market.price, sell_amount);
                last_trade_profit = (market.price - avg_cost) * sell_amount;
                if last_trade_profit < 0 {
                    loss_streak += 1;
                } else {
                    loss_streak = 0;
                }
            }
        }
    } else {
        let vwap = market.vwap;
        if vwap > 0 && market.price > 0 {
            let diff_pct = (vwap - market.price) * 10000 / vwap;
            if diff_pct > vwap_threshold {
                let effective_streak = loss_streak;
                if effective_streak > max_streak {
                    effective_streak = max_streak;
                }
                current_lot_size = base_lot_size * (1 << effective_streak);
                let cash_available = account.cash;
                let max_affordable = cash_available / market.price;
                if max_affordable > 0 {
                    let buy_amount = current_lot_size;
                    if buy_amount > max_affordable {
                        buy_amount = max_affordable;
                    }
                    if buy_amount > 0 {
                        orders.submit_limit_buy(market.price, buy_amount);
                    }
                }
            }
        }
    }
}