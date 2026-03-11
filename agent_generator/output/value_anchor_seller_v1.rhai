let initialized = false;
let fair_value_micros = 0;
let panic_threshold = 0;
let small_sell_pct = 500;
let aggressive_sell_pct = 2000;

fn on_tick() {
    if !initialized {
        initialized = true;
        let random_adj = rng.rand_int(-5, 5);
        fair_value_micros = 100_000_000 * (100 + random_adj) / 100;
        panic_threshold = -rng.rand_int(10_000_000, 50_000_000);
        small_sell_pct = 500;
        aggressive_sell_pct = 2000;
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.unrealized_pnl < panic_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }

    if account.stock <= 0 { return; }

    let five_percent_above = fair_value_micros * 105 / 100;
    let ten_percent_above = fair_value_micros * 110 / 100;
    let current_price = market.price;

    if current_price > ten_percent_above {
        let sell_amount = account.stock * aggressive_sell_pct / 10000;
        if sell_amount <= 0 { sell_amount = 1; }
        if sell_amount > account.stock { sell_amount = account.stock; }
        orders.submit_limit_sell(current_price, sell_amount);
    } else if current_price > five_percent_above {
        let sell_amount = account.stock * small_sell_pct / 10000;
        if sell_amount <= 0 { sell_amount = 1; }
        if sell_amount > account.stock { sell_amount = account.stock; }
        orders.submit_limit_sell(current_price, sell_amount);
    }
}