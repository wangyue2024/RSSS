let initialized = false;
let target_shares = 50_000;
let lot_size = 0;
let ticks_between = 10;
let tick_counter = 0;
let last_trade_loss = false;
let fomo_triggered = false;
let price_history = [];
let last_fill_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size = rng.rand_int(500, 2500);
        ticks_between = rng.rand_int(5, 20);
    }

    if !market.trading_enabled { return; }

    let current_price = market.price;
    price_history.push(current_price);
    if price_history.len() > 10 {
        price_history.remove(0);
    }

    let position = account.stock;
    let remaining = target_shares - position;
    if remaining <= 0 { return; }

    let cash_available = account.cash;
    let max_buy_by_cash = cash_available / current_price;

    if price_history.len() >= 3 {
        let idx_old = price_history.len() - 3;
        let old_price = price_history[idx_old];
        let price_jump = (current_price - old_price) * 10000 / old_price;
        if price_jump > 200 && !fomo_triggered {
            fomo_triggered = true;
            let fomo_amount = min(remaining, max_buy_by_cash);
            if fomo_amount > 0 {
                orders.submit_market_buy(fomo_amount);
                return;
            }
        }
    }

    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let last_idx = fill_cnt - 1;
        last_fill_price = my_orders.fill_price(last_idx);
        if account.avg_cost > 0 && current_price < account.avg_cost {
            last_trade_loss = true;
        } else {
            last_trade_loss = false;
        }
    }

    if last_trade_loss {
        lot_size = lot_size * 2;
    }

    if tick_counter >= ticks_between {
        tick_counter = 0;
        fomo_triggered = false;

        let buy_amount = min(lot_size, min(remaining, max_buy_by_cash));
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
    } else {
        tick_counter += 1;
    }
}