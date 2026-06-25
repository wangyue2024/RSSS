let initialized = false;
let normal_order_size = 0;
let pending_tracker = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        normal_order_size = rng.rand_int(10, 100);
    }

    if !market.trading_enabled { return; }

    let current_tick = market.tick;

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let order_id = my_orders.pending_id(i);
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            orders.submit_cancel(order_id);
        }
        i += 1;
    }

    pending_tracker = [];
    let new_pending_count = my_orders.pending_count();
    let j = 0;
    while j < new_pending_count {
        pending_tracker.push(my_orders.pending_id(j));
        j += 1;
    }

    let fat_finger_trigger = rng.rand_bool(1);
    if fat_finger_trigger && pending_tracker.len() == 0 {
        let direction = rng.rand_bool(50);
        let fat_amount = normal_order_size * 100;
        if direction {
            orders.submit_market_buy(fat_amount);
        } else {
            orders.submit_market_sell(fat_amount);
        }
        return;
    }

    if pending_tracker.len() == 0 {
        let noise_trade = rng.rand_bool(10);
        if noise_trade {
            let direction = rng.rand_bool(50);
            let price_offset = rng.rand_int(-5, 5);
            if direction {
                let buy_price = market.bid_price_0 + price_offset;
                if buy_price > 0 {
                    orders.submit_limit_buy(buy_price, normal_order_size);
                }
            } else {
                let sell_price = market.ask_price_0 + price_offset;
                if sell_price > 0 {
                    orders.submit_limit_sell(sell_price, normal_order_size);
                }
            }
        }
    }
}