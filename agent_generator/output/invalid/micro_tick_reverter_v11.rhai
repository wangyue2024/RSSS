let initialized = false;
let last_price = 0;
let pending_order_id = 0;
let pending_order_placed_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        last_price = market.price;
        return;
    }

    if !market.trading_enabled { return; }

    let price_change = market.price - last_price;
    last_price = market.price;

    if pending_order_id != 0 {
        let found = false;
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt && !found {
            if my_orders.pending_id(i) == pending_order_id {
                found = true;
            }
            i += 1;
        }
        if !found {
            pending_order_id = 0;
        } else if market.tick - pending_order_placed_tick >= 3 {
            orders.submit_cancel(pending_order_id);
            pending_order_id = 0;
        }
    }

    if pending_order_id == 0 {
        let order_amount = 100;
        if price_change < 0 {
            let calculated_price = market.price - 10;
            let actual_price = calculated_price + 1;
            let new_id = orders.submit_limit_buy(actual_price, order_amount);
            if new_id != 0 {
                pending_order_id = new_id;
                pending_order_placed_tick = market.tick;
            }
        } else if price_change > 0 {
            if account.stock >= order_amount {
                let calculated_price = market.price + 10;
                let actual_price = calculated_price + 1;
                let new_id = orders.submit_limit_sell(actual_price, order_amount);
                if new_id != 0 {
                    pending_order_id = new_id;
                    pending_order_placed_tick = market.tick;
                }
            }
        }
    }
}