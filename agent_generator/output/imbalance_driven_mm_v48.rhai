let initialized = false;
let shift_per_unit = 0;
let base_spread = 0;
let order_amount = 0;
let bid_id = -1;
let ask_id = -1;
let bid_placed_tick = -1;
let ask_placed_tick = -1;

fn on_tick() {
    if !initialized {
        initialized = true;
        shift_per_unit = rng.rand_int(5, 20);
        base_spread = rng.rand_int(200, 600);
        order_amount = rng.rand_int(50, 200);
    }

    if !market.trading_enabled { return; }

    let current_tick = market.tick;

    if bid_id != -1 && bid_placed_tick != -1 && (current_tick - bid_placed_tick) >= 3 {
        orders.submit_cancel(bid_id);
        bid_id = -1;
        bid_placed_tick = -1;
    }
    if ask_id != -1 && ask_placed_tick != -1 && (current_tick - ask_placed_tick) >= 3 {
        orders.submit_cancel(ask_id);
        ask_id = -1;
        ask_placed_tick = -1;
    }

    let mid_price = market.price;
    let imbalance = market.order_imbalance;
    let shift = imbalance * shift_per_unit;

    let half_spread = base_spread / 2;
    let bid_offset = -half_spread + shift;
    let ask_offset = half_spread + shift;

    let new_bid_price = mid_price + bid_offset;
    let new_ask_price = mid_price + ask_offset;

    if new_bid_price <= 0 { new_bid_price = 1; }
    if new_ask_price <= new_bid_price { new_ask_price = new_bid_price + 1; }

    if bid_id == -1 {
        bid_id = orders.submit_limit_buy(new_bid_price, order_amount);
        if bid_id != -1 {
            bid_placed_tick = current_tick;
        }
    }

    if ask_id == -1 {
        ask_id = orders.submit_limit_sell(new_ask_price, order_amount);
        if ask_id != -1 {
            ask_placed_tick = current_tick;
        }
    }
}