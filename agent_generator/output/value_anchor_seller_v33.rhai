let initialized = false;
let fair_value = 0;
let base_lot_size = 0;
let current_lot_multiplier = 1;
let last_realized_pnl = 0;
let order_placed_tick = -1;
let pending_order_id = -1;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = 100_000_000 + rng.rand_int(-2_000_000, 2_000_000);
        base_lot_size = rng.rand_int(500, 2000);
        last_realized_pnl = account.realized_pnl;
    }

    if !market.trading_enabled { return; }

    let delta_pnl = account.realized_pnl - last_realized_pnl;
    if delta_pnl < 0 {
        current_lot_multiplier = current_lot_multiplier * 2;
    } else {
        current_lot_multiplier = 1;
    }
    last_realized_pnl = account.realized_pnl;

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        let placed = my_orders.pending_placed_tick(i);
        if market.tick - placed > 3 {
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    if account.stock <= 0 { return; }

    let price = market.price;
    let five_pct_thresh = fair_value * 105 / 100;
    let ten_pct_thresh = fair_value * 110 / 100;

    let sell_amount = 0;
    if price > ten_pct_thresh {
        sell_amount = base_lot_size * current_lot_multiplier * 2;
    } else if price > five_pct_thresh {
        sell_amount = base_lot_size * current_lot_multiplier;
    }

    if sell_amount > account.stock {
        sell_amount = account.stock;
    }
    if sell_amount > 0 {
        let target_price = market.bid_price_0;
        if target_price == 0 {
            target_price = price;
        }
        orders.submit_limit_sell(target_price, sell_amount);
    }
}