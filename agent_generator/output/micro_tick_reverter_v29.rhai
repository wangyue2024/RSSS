let initialized = false;
let prev_price = 0;
let price_history = [];
let order_id_to_place_tick = #{};
let last_action_tick = 0;
let fomo_window = 5;
let order_lifetime = 3;
let evaluation_interval = 50;
let base_order_amount = 100;
let price_offset_frac = 10;
let fomo_threshold_percent = 200;

fn on_tick() {
    if !initialized {
        initialized = true;
        prev_price = market.price;
        price_history.push(market.price);
        return;
    }

    if !market.trading_enabled {
        return;
    }

    let current_tick = market.tick;

    price_history.push(market.price);
    if price_history.len() > fomo_window {
        price_history.remove(0);
    }

    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let oid = my_orders.pending_id(i);
        let placed = my_orders.pending_placed_tick(i);
        if current_tick - placed >= order_lifetime {
            orders.submit_cancel(oid);
            order_id_to_place_tick.erase(oid);
        }
        i += 1;
    }

    if price_history.len() == fomo_window {
        let old_price = price_history[0];
        let current_price = market.price;
        if (current_price * 100) > (old_price * (100 + fomo_threshold_percent / 100)) {
            let buy_amount = base_order_amount;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            prev_price = current_price;
            return;
        }
    }

    if current_tick % evaluation_interval == 0 && current_tick != last_action_tick {
        let current_price = market.price;

        let i = 0;
        let pending_cnt = my_orders.pending_count();
        while i < pending_cnt {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }

        if current_price < prev_price {
            let offset = current_price * price_offset_frac / 10000;
            let limit_price = current_price - offset;
            let amount = base_order_amount;
            if limit_price > 0 && amount > 0 {
                let order_id = orders.submit_limit_buy(limit_price, amount);
                if order_id != 0 {
                    order_id_to_place_tick[order_id] = current_tick;
                }
            }
        } else if current_price > prev_price {
            let offset = current_price * price_offset_frac / 10000;
            let limit_price = current_price + offset;
            let amount = base_order_amount;
            if amount > 0 && account.stock >= amount {
                let order_id = orders.submit_limit_sell(limit_price, amount);
                if order_id != 0 {
                    order_id_to_place_tick[order_id] = current_tick;
                }
            }
        }

        last_action_tick = current_tick;
    }

    prev_price = market.price;
}