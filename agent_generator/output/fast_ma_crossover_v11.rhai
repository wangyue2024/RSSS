let initialized = false;
let prev_ma5 = 0;
let prev_ma20 = 0;
let base_lot = 100;
let current_lot = base_lot;
let max_lot = 1000;
let last_trade_profit = 0;
let in_position = false;
let last_avg_cost = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        prev_ma5 = market.ma_5;
        prev_ma20 = market.ma_20;
        return;
    }

    if !market.trading_enabled { return; }

    // Cancel all pending orders at the start of each tick
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    // Check for crossover
    let ma5 = market.ma_5;
    let ma20 = market.ma_20;
    let cross_up = (prev_ma5 <= prev_ma20) && (ma5 > ma20);
    let cross_down = (prev_ma5 >= prev_ma20) && (ma5 < ma20);

    // Update previous values for next tick
    prev_ma5 = ma5;
    prev_ma20 = ma20;

    // Martingale lot sizing logic
    if last_trade_profit < 0 {
        current_lot = current_lot * 2;
        if current_lot > max_lot {
            current_lot = max_lot;
        }
    } else {
        current_lot = base_lot;
    }

    // Trading logic
    if cross_up && !in_position {
        // Buy signal
        orders.submit_market_buy(current_lot);
        in_position = true;
        last_avg_cost = market.price; // approximate avg cost
    } else if cross_down && in_position {
        // Sell signal
        let sell_amount = account.stock;
        if sell_amount > 0 {
            orders.submit_market_sell(sell_amount);
            // Calculate approximate profit/loss
            last_trade_profit = (market.price - last_avg_cost) * sell_amount;
            in_position = false;
        }
    }
}