let initialized = false;
let base_spread = 0;
let imbalance_threshold = 0;
let order_size = 0;
let prev_imbalance = 0;

fn round_to_dollar(price) {
    let remainder = price % 1_000_000;
    if remainder >= 500_000 {
        price - remainder + 1_000_000
    } else {
        price - remainder
    }
}

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(20_000, 100_000);
        imbalance_threshold = rng.rand_int(10_000_000, 30_000_000);
        order_size = rng.rand_int(100, 500);
        prev_imbalance = 0;
    }

    if !market.trading_enabled {
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let current_imbalance = market.order_imbalance;
    let imbalance_change = abs_val(current_imbalance - prev_imbalance);
    prev_imbalance = current_imbalance;

    if imbalance_change < 1_000_000 {
        return;
    }

    let mid_price = market.price;
    let adjustment = (current_imbalance * base_spread) / (imbalance_threshold * 2);
    let adjusted_mid = mid_price + adjustment;

    let raw_bid = adjusted_mid - base_spread / 2;
    let raw_ask = adjusted_mid + base_spread / 2;

    let bid_price = round_to_dollar(raw_bid);
    let ask_price = round_to_dollar(raw_ask);

    if bid_price > 0 && bid_price < ask_price {
        let bid_amount = order_size;
        if account.cash >= bid_price * bid_amount / 1_000_000 {
            orders.submit_limit_buy(bid_price, bid_amount);
        }
    }

    if ask_price > bid_price {
        let ask_amount = order_size;
        if account.stock >= ask_amount {
            orders.submit_limit_sell(ask_price, ask_amount);
        }
    }
}