let initialized = false;
let fair_value = 0;
let base_lot_size = 0;
let last_trade_loss = false;
let last_prices = [];
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        base_lot_size = (account.cash / market.price) * 50 / 100;
        if base_lot_size < 100 { base_lot_size = 100; }
    }

    if !market.trading_enabled { return; }

    // Update price history for FOMO check
    last_prices.push(market.price);
    if last_prices.len() > 5 {
        last_prices.remove(0);
    }

    // Cancel all pending orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }

    // Determine if last trade was a loss
    if account.avg_cost > 0 && market.price < account.avg_cost {
        last_trade_loss = true;
    } else {
        last_trade_loss = false;
    }

    // Martingale sizing
    let current_lot_size = base_lot_size;
    if last_trade_loss {
        current_lot_size = base_lot_size * 2;
    }

    // FOMO check: 2% jump in last 5 ticks
    if last_prices.len() >= 5 {
        let old_price = last_prices[0];
        if old_price > 0 && market.price > old_price * 102 / 100 {
            fomo_triggered = true;
        }
    }

    if fomo_triggered {
        // Abandon strategy, market buy
        let buy_amount = current_lot_size;
        let max_buy = account.cash / market.price;
        if buy_amount > max_buy { buy_amount = max_buy; }
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
        fomo_triggered = false;
        return;
    }

    // Value anchor buying logic
    if market.price < fair_value {
        let buy_amount = 0;
        if market.price < fair_value * 90 / 100 {
            // Aggressive buy
            buy_amount = current_lot_size;
        } else if market.price < fair_value * 95 / 100 {
            // Small buy
            buy_amount = current_lot_size * 10 / 100;
            if buy_amount < 100 { buy_amount = 100; }
        }

        if buy_amount > 0 {
            let max_buy = account.cash / market.price;
            if buy_amount > max_buy { buy_amount = max_buy; }
            if buy_amount > 0 {
                // Place limit order at current price for immediate execution
                orders.submit_limit_buy(market.price, buy_amount);
            }
        }
    }
}