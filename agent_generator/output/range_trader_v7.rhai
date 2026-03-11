let initialized = false;
let base_lot = 0;
let price_history = [];
let last_tick_action = -10;

fn on_tick() {
    if !initialized {
        base_lot = (account.cash / 2) / market.price;
        if base_lot < 100 {
            base_lot = 100;
        }
        initialized = true;
    }

    if !market.trading_enabled { return; }

    price_history.push(market.price);
    if price_history.len() > 25 {
        price_history.remove(0);
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if price_history.len() < 25 {
        return;
    }

    let delayed_price = price_history[price_history.len() - 6];
    let delayed_high = delayed_price;
    let delayed_low = delayed_price;
    let start_idx = price_history.len() - 26;
    let end_idx = price_history.len() - 6;
    let j = start_idx;
    while j <= end_idx {
        let p = price_history[j];
        if p > delayed_high { delayed_high = p; }
        if p < delayed_low { delayed_low = p; }
        j += 1;
    }

    let spread = delayed_high - delayed_low;
    let spread_ratio = (spread * 10000) / delayed_price;

    let dynamic_lot = base_lot;
    if spread_ratio < 50 {
        dynamic_lot = base_lot * 3 / 2;
    }

    let buy_price = delayed_low + (spread * 2 / 100);
    let sell_price = delayed_high - (spread * 2 / 100);

    if buy_price < sell_price && buy_price > 0 {
        let max_buy = account.cash / buy_price;
        let buy_lot = dynamic_lot;
        if buy_lot > max_buy { buy_lot = max_buy; }
        if buy_lot > 0 {
            orders.submit_limit_buy(buy_price, buy_lot);
        }

        let sell_lot = dynamic_lot;
        if sell_lot > account.stock { sell_lot = account.stock; }
        if sell_lot > 0 {
            orders.submit_limit_sell(sell_price, sell_lot);
        }
    }
}