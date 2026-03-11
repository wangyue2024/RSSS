// Global variables persist across ticks
let initialized = false;
let fair_value = 0;
let panic_threshold = 0;
let base_lot_size = 100;
let current_lot_size = 0;
let last_buy_price = 0;
let total_loss = 0;

fn on_tick() {
    // Update last buy price from fills if any
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let i = 0;
        while i < fill_cnt {
            let side = my_orders.fill_side(i);
            if side == 0 {
                last_buy_price = my_orders.fill_price(i);
            }
            i += 1;
        }
    }

    // Lazy trader: only act every 50 ticks
    if market.tick % 50 != 0 {
        return;
    }

    if !market.trading_enabled {
        return;
    }

    // Cancel all pending orders first
    let pending_cnt = my_orders.pending_count();
    let j = 0;
    while j < pending_cnt {
        let oid = my_orders.pending_id(j);
        orders.submit_cancel(oid);
        j += 1;
    }

    // Initialize strategy parameters once
    if !initialized {
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        // Panic threshold: random between -5% to -1% of fair_value
        panic_threshold = -rng.rand_int(fair_value * 1 / 100, fair_value * 5 / 100);
        current_lot_size = base_lot_size;
        initialized = true;
    }

    // PANIC-PRONE: check unrealized PNL threshold
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        total_loss = 0;
        last_buy_price = 0;
        return;
    }

    // MARTINGALE SIZER: check if last trade was a loss
    if last_buy_price > 0 && market.price < last_buy_price {
        total_loss = total_loss + 1;
        if total_loss > 0 {
            current_lot_size = base_lot_size << total_loss;
        }
    } else {
        total_loss = 0;
        current_lot_size = base_lot_size;
    }

    let price = market.price;
    let max_buy_amount = account.cash / price;
    let buy_amount = 0;

    // VALUE ANCHOR: buy when below fair value
    if price < fair_value * 90 / 100 {
        // Aggressive buying: double the current lot size
        buy_amount = current_lot_size * 2;
    } else if price < fair_value * 95 / 100 {
        // Small buying: base current lot size
        buy_amount = current_lot_size;
    }

    if buy_amount > 0 && buy_amount <= max_buy_amount && buy_amount > 0 {
        orders.submit_limit_buy(price, buy_amount);
    }
}