let price_buffer = [];
let delayed_tick_counter = 0;
let order_amount = 100;
let spread_micros = 20;

fn on_tick() {
    if !market.trading_enabled {
        return;
    }

    let current_price = market.price;
    price_buffer.push(current_price);

    if price_buffer.len() > 6 {
        price_buffer.remove(0);
    }

    delayed_tick_counter += 1;

    if delayed_tick_counter < 5 {
        return;
    }

    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if price_buffer.len() >= 2 {
        let old_price = price_buffer[0];
        let new_price = price_buffer[1];

        if new_price < old_price {
            let buy_price = new_price - spread_micros + 1;
            if buy_price > 0 {
                orders.submit_limit_buy(buy_price, order_amount);
            }
        } else if new_price > old_price {
            let sell_price = new_price + spread_micros - 1;
            orders.submit_limit_sell(sell_price, order_amount);
        }
    }
}