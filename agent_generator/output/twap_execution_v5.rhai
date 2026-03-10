let target_position = 50_000;
let base_slice_size = 500;
let ticks_between = 10;
let delay_ticks = 5;

let price_history = [];
let last_trade_was_loss = false;
let current_slice_size = base_slice_size;
let last_action_tick = -ticks_between;
let avg_cost_before_last_trade = 0;

fn on_tick() {
    if !market.trading_enabled { return; }

    price_history.push(market.price);
    if price_history.len() > delay_ticks {
        price_history.remove(0);
    }

    if price_history.len() < delay_ticks {
        return;
    }

    let delayed_price = price_history[0];
    let current_tick = market.tick;

    if current_tick - last_action_tick >= ticks_between {
        if account.stock < target_position {
            let remaining = target_position - account.stock;
            let order_size = current_slice_size;
            if order_size > remaining {
                order_size = remaining;
            }

            if order_size > 0 {
                if last_trade_was_loss && avg_cost_before_last_trade > 0 {
                    if delayed_price < avg_cost_before_last_trade {
                        current_slice_size = current_slice_size * 2;
                    } else {
                        current_slice_size = base_slice_size;
                    }
                }

                avg_cost_before_last_trade = account.avg_cost;
                orders.submit_market_buy(order_size);
                last_action_tick = current_tick;
            }
        }
    }

    if avg_cost_before_last_trade > 0 && account.stock > 0 {
        if delayed_price < avg_cost_before_last_trade {
            last_trade_was_loss = true;
        } else {
            last_trade_was_loss = false;
        }
    }
}