// Global variables
let initialized = false;
let risk_mode = 0;
let lot_size = 0;
let prev_price = 0;
let recent_prices = [];

fn on_tick() {
    // Cancel all pending orders
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if !market.trading_enabled {
        return;
    }

    if !initialized {
        risk_mode = rng.rand_int(0, 1);
        let cash_available = account.cash;
        let total_capital = account.total_equity;
        let current_price = market.price;

        if risk_mode == 1 {
            let percent = rng.rand_int(250, 500);
            let cash_to_use = cash_available * percent / 1000;
            lot_size = cash_to_use / current_price;
        } else {
            let percent = rng.rand_int(10, 50);
            let capital_to_use = total_capital * percent / 1000;
            lot_size = capital_to_use / current_price;
        }

        if lot_size < 1 {
            lot_size = 1;
        }

        prev_price = current_price;
        recent_prices.push(current_price);
        initialized = true;
        return;
    }

    // Update price window for FOMO (5 ticks)
    if recent_prices.len() < 5 {
        recent_prices.push(market.price);
    } else {
        recent_prices.remove(0);
        recent_prices.push(market.price);
    }

    // Check FOMO condition
    if recent_prices.len() == 5 {
        let old_price = recent_prices[0];
        let current_price = market.price;
        let change_bps = (current_price - old_price) * 10000 / old_price;
        if change_bps > 200 {
            orders.submit_market_buy(lot_size);
            prev_price = current_price;
            return;
        }
    }

    // Risk-averse: skip if volatility is high
    if risk_mode == 0 {
        let high_std_dev_threshold = market.price * 5 / 100;
        if market.std_dev > high_std_dev_threshold {
            return;
        }
    }

    let current_price = market.price;
    if prev_price != 0 {
        let price_change = current_price - prev_price;
        let offset = current_price / 2000;
        if offset < 1 {
            offset = 1;
        }

        if price_change < 0 {
            let buy_price = current_price - offset;
            orders.submit_limit_buy(buy_price, lot_size);
        } else if price_change > 0 {
            let sell_price = current_price + offset;
            orders.submit_limit_sell(sell_price, lot_size);
        }
    }

    prev_price = current_price;
}