let initialized = false;
let max_lot_size = 0;
let inventory_threshold = 1000;
let base_spread = 2_000_000;
let max_std_dev = 5_000_000;
let min_position = -2000;
let max_position = 2000;

fn on_tick() {
    if !initialized {
        initialized = true;
        let five_percent_cap = account.total_equity * 5 / 100;
        max_lot_size = five_percent_cap / market.price;
        if max_lot_size < 1 {
            max_lot_size = 1;
        }
    }

    if !market.trading_enabled { return; }

    if market.std_dev > max_std_dev {
        return;
    }

    let best_bid = market.bid_price_0;
    let best_ask = market.ask_price_0;
    if best_bid <= 0 || best_ask <= 0 {
        return;
    }

    let mid_price = (best_bid + best_ask) / 2;
    let inventory = account.stock;
    let skew_factor = 0;

    if inventory > inventory_threshold {
        skew_factor = 50;
    } else if inventory <= 0 {
        skew_factor = -50;
    }

    let cancel_cnt = my_orders.pending_count();
    let i = 0;
    while i < cancel_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let current_position = account.stock;
    if current_position <= min_position && current_position >= max_position {
        return;
    }

    let buy_distance = base_spread * (100 - skew_factor) / 100;
    let sell_distance = base_spread * (100 + skew_factor) / 100;

    let raw_bid_price = mid_price - buy_distance;
    let raw_ask_price = mid_price + sell_distance;

    let round_bid_price = ((raw_bid_price + 500_000) / 1_000_000) * 1_000_000;
    let round_ask_price = ((raw_ask_price + 500_000) / 1_000_000) * 1_000_000;

    if round_bid_price <= 0 || round_ask_price <= 0 || round_bid_price >= round_ask_price {
        return;
    }

    let lot_size = max_lot_size;
    if lot_size > 100 {
        lot_size = 100;
    }

    if current_position < max_position {
        orders.submit_limit_buy(round_bid_price, lot_size);
    }
    if current_position > min_position {
        orders.submit_limit_sell(round_ask_price, lot_size);
    }
}