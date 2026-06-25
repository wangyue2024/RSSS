let initialized = false;
let base_lot_size = 0;
let current_lot_size = 0;
let last_trade_profitable = true;
let last_position_avg_cost = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(50, 200);
        current_lot_size = base_lot_size;
        last_position_avg_cost = account.avg_cost;
    }

    if !market.trading_enabled { return; }

    // Cancel all pending orders each tick
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    // Martingale sizing: check if last trade was loss
    if account.stock > 0 {
        if market.price < last_position_avg_cost {
            last_trade_profitable = false;
        }
    }

    if last_trade_profitable {
        current_lot_size = base_lot_size;
    } else {
        current_lot_size = base_lot_size * 2;
    }

    // Order flow logic
    let buy_vol = market.buy_volume;
    let sell_vol = market.sell_volume;

    if buy_vol > 3 * sell_vol {
        // Buy condition
        let amount = current_lot_size;
        if amount > 0 {
            orders.submit_market_buy(amount);
        }
    } else if sell_vol > 3 * buy_vol {
        // Sell condition - only if price > avg_cost (diamond hands)
        if market.price > account.avg_cost && account.stock > 0 {
            let amount = current_lot_size;
            if amount > account.stock {
                amount = account.stock;
            }
            if amount > 0 {
                orders.submit_market_sell(amount);
            }
        }
    }

    // Update state for next tick
    if account.stock > 0 {
        last_position_avg_cost = account.avg_cost;
    }
}