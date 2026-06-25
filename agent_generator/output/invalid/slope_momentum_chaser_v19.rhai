let initialized = false;
let recent_prices = [];
let recent_slopes = [];
let lot_size = 0;
let panic_mode = false;
let panic_sell_price = 0;
let order_placed_tick = 0;
let current_order_id = -1;

fn on_tick() {
    if !initialized {
        initialized = true;
        let risk_capital = account.total_equity * 5 / 100;
        if risk_capital < 1_000_000 {
            risk_capital = 1_000_000;
        }
        lot_size = rng.rand_int(100, risk_capital / 1_000_000);
        if lot_size < 100 {
            lot_size = 100;
        }
    }

    if !market.trading_enabled { return; }

    let std_dev_threshold = market.price * 5 / 100;
    if market.std_dev > std_dev_threshold {
        return;
    }

    recent_prices.push(market.price);
    if recent_prices.len() > 20 {
        recent_prices.remove(0);
    }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        let placed = my_orders.pending_placed_tick(i);
        if market.tick - placed >= 3 {
            orders.submit_cancel(oid);
            if oid == current_order_id {
                current_order_id = -1;
            }
        }
        i += 1;
    }

    if recent_prices.len() < 5 {
        return;
    }

    let current_slope = arr_slope(recent_prices);
    recent_slopes.push(current_slope);
    if recent_slopes.len() > 3 {
        recent_slopes.remove(0);
    }

    let slope_threshold = market.price * 1 / 1000;

    if panic_mode {
        if account.stock > 0 && market.price <= panic_sell_price * 95 / 100 {
            orders.submit_market_sell(account.stock);
            panic_mode = false;
        } else if market.price > panic_sell_price * 105 / 100 {
            panic_mode = false;
        }
        return;
    }

    if recent_slopes.len() >= 3 {
        let slope_accel = recent_slopes[recent_slopes.len() - 1] - recent_slopes[0];
        let buy_condition = current_slope > slope_threshold && slope_accel > 0;
        let panic_condition = current_slope < -slope_threshold;

        if panic_condition && account.stock > 0 {
            panic_mode = true;
            panic_sell_price = market.price;
            orders.submit_market_sell(account.stock);
            current_order_id = -1;
            return;
        }

        if buy_condition && account.stock == 0 && current_order_id == -1 {
            let buy_price = market.ask_price_0;
            let amount = lot_size;
            if amount * buy_price <= account.cash {
                orders.submit_limit_buy(buy_price, amount);
                current_order_id = my_orders.pending_id(my_orders.pending_count() - 1);
                order_placed_tick = market.tick;
            }
        }
    }

    let fill_count = my_orders.fill_count();
    if fill_count > 0 {
        current_order_id = -1;
    }
}