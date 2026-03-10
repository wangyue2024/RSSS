let initialized = false;
let lot_size = 0;
let buy_pressure_threshold = 0;
let sell_pressure_threshold = 0;
let round_spacing = 1_000_000;
let price_history = [];
let fomo_triggered = false;
let fomo_ticks_remaining = 0;
let imbalance_sensitivity = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        buy_pressure_threshold = rng.rand_int(30, 50);
        sell_pressure_threshold = rng.rand_int(-50, -30);
        imbalance_sensitivity = rng.rand_int(5, 15);
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    price_history.push(market.price);
    if price_history.len() > 10 {
        price_history.remove(0);
    }

    if fomo_triggered {
        fomo_ticks_remaining -= 1;
        if fomo_ticks_remaining <= 0 {
            fomo_triggered = false;
        }
    }

    if !fomo_triggered && price_history.len() == 10 {
        let old_price = price_history[0];
        let change_pct = (market.price - old_price) * 100 / old_price;
        if change_pct > 2 || change_pct < -2 {
            fomo_triggered = true;
            fomo_ticks_remaining = rng.rand_int(5, 15);
            let max_buy_shares = account.cash / market.price;
            let buy_shares = max_buy_shares * 50 / 100;
            if buy_shares > 0 {
                orders.submit_market_buy(buy_shares);
            }
            return;
        }
    }

    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    let imbalance = market.order_imbalance;
    let imbalance_shift = imbalance * imbalance_sensitivity / 100;

    let base_bid = mid_price + imbalance_shift - 50_000;
    let base_ask = mid_price + imbalance_shift + 50_000;

    let rounded_bid = (base_bid / round_spacing) * round_spacing;
    let rounded_ask = (base_ask / round_spacing) * round_spacing;

    if lot_size == 0 {
        let max_shares = account.cash * 50 / 100 / market.price;
        lot_size = rng.rand_int(max_shares * 30 / 100, max_shares * 70 / 100);
        if lot_size < 100 {
            lot_size = 100;
        }
    }

    let current_lot = lot_size;
    let buy_amount = current_lot;
    let sell_amount = current_lot;

    if account.cash >= rounded_bid * buy_amount && buy_amount > 0 {
        orders.submit_limit_buy(rounded_bid, buy_amount);
    }

    if account.stock >= sell_amount && sell_amount > 0 {
        orders.submit_limit_sell(rounded_ask, sell_amount);
    }
}