let initialized = false;
let base_spread_ticks = 10;
let base_lot_size = 100;
let max_lot_size = 1000;
let loss_streak = 0;
let last_trade_side = -1;
let last_trade_price = 0;
let last_trade_evaluated = true;

fn on_tick() {
    if !market.trading_enabled { return; }

    // Morning Person: only active first 20% of session
    if market.tick >= market.total_ticks * 20 / 100 {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }

    if !initialized {
        initialized = true;
        base_spread_ticks = rng.rand_int(5, 20);
        base_lot_size = rng.rand_int(50, 200);
    }

    // Process fills from previous tick
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let i = 0;
        while i < fill_cnt {
            let fill_side = my_orders.fill_side(i);
            let fill_price = my_orders.fill_price(i);
            if i == fill_cnt - 1 {
                last_trade_side = fill_side;
                last_trade_price = fill_price;
                last_trade_evaluated = false;
            }
            i += 1;
        }
    }

    // Evaluate last trade for martingale
    if !last_trade_evaluated && last_trade_side >= 0 {
        let is_loss = false;
        if last_trade_side == 0 {
            if market.price < last_trade_price {
                is_loss = true;
            }
        } else {
            if market.price > last_trade_price {
                is_loss = true;
            }
        }
        if is_loss {
            loss_streak += 1;
        } else {
            loss_streak = 0;
        }
        last_trade_evaluated = true;
    }

    // Cancel all pending orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }

    // Calculate current lot size with martingale doubling
    let current_lot_size = base_lot_size;
    let j = 0;
    while j < loss_streak {
        current_lot_size *= 2;
        if current_lot_size > max_lot_size {
            current_lot_size = max_lot_size;
            break;
        }
        j += 1;
    }

    // Volatility adaptive spread
    let vol_factor = market.std_dev / 1000;
    let spread_multiplier = 100 + vol_factor;
    let spread_ticks = base_spread_ticks * spread_multiplier / 100;
    let spread_micros = spread_ticks * 10000;

    let mid_price = market.price;
    let buy_price = mid_price - spread_micros / 2;
    let sell_price = mid_price + spread_micros / 2;

    // Adjust to tick size (10000 micros per tick)
    buy_price = buy_price - buy_price % 10000;
    sell_price = sell_price - sell_price % 10000;

    // Ensure prices are valid
    if buy_price <= 0 || sell_price <= 0 || buy_price >= sell_price {
        return;
    }

    // Place buy order if enough cash
    let max_buy_shares = account.cash / buy_price;
    if max_buy_shares > 0 {
        let buy_amount = current_lot_size;
        if buy_amount > max_buy_shares {
            buy_amount = max_buy_shares;
        }
        if buy_amount > 0 {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    }

    // Place sell order if enough stock
    if account.stock > 0 {
        let sell_amount = current_lot_size;
        if sell_amount > account.stock {
            sell_amount = account.stock;
        }
        if sell_amount > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}