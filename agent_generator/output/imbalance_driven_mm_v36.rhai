let initialized = false;
let last_action_tick = -50;
let my_spread = 2_000_000;
let my_order_size = 100;

fn round_to_dollar(price_micros) {
    let half_dollar = 500_000;
    let full_dollar = 1_000_000;
    let remainder = price_micros % full_dollar;
    if remainder >= half_dollar {
        price_micros + (full_dollar - remainder)
    } else {
        price_micros - remainder
    }
}

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        initialized = true;
        my_spread = 2_000_000 + rng.rand_int(0, 4) * 500_000;
    }

    let current_tick = market.tick;

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed = my_orders.pending_placed_tick(i);
        if current_tick - placed > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    if current_tick % 50 == 0 && current_tick != last_action_tick {
        last_action_tick = current_tick;

        let mid_price = market.price;
        let imbalance = market.order_imbalance;

        let shift_factor = imbalance * 200 / 10000;
        let shifted_mid = mid_price + shift_factor;

        let bid_target = shifted_mid - my_spread / 2;
        let ask_target = shifted_mid + my_spread / 2;

        let rounded_bid = round_to_dollar(bid_target);
        let rounded_ask = round_to_dollar(ask_target);

        if rounded_bid > 0 && rounded_ask > rounded_bid {
            let cash_needed = rounded_bid * my_order_size;
            if account.cash >= cash_needed {
                orders.submit_limit_buy(rounded_bid, my_order_size);
            }

            if account.stock >= my_order_size {
                orders.submit_limit_sell(rounded_ask, my_order_size);
            }
        }
    }
}