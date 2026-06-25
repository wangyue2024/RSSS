let total_to_sell = 0;
let displayed_chunk = 0;
let remaining_to_sell = 0;
let current_order_id = 0;
let order_placed_tick = 0;
let strategy_initialized = false;

fn on_tick() {
    if !strategy_initialized {
        strategy_initialized = true;
        total_to_sell = 5000;
        displayed_chunk = 50;
        remaining_to_sell = total_to_sell;
        current_order_id = 0;
        order_placed_tick = 0;
    }

    if !market.trading_enabled {
        return;
    }

    if market.ask_price_0 == 0 || market.ask_vol_0 == 0 {
        return;
    }

    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        for i in 0..fill_cnt {
            let fill_id = my_orders.fill_id(i);
            if fill_id == current_order_id {
                let fill_amt = my_orders.fill_amount(i);
                remaining_to_sell -= fill_amt;
                if current_order_id != 0 {
                    orders.submit_cancel(current_order_id);
                    current_order_id = 0;
                }
                break;
            }
        }
    }

    let cancel_current = false;
    if current_order_id != 0 && market.tick - order_placed_tick >= 3 {
        cancel_current = true;
        orders.submit_cancel(current_order_id);
        current_order_id = 0;
    }

    let pending_count = my_orders.pending_count();
    if pending_count > 0 {
        for i in 0..pending_count {
            let oid = my_orders.pending_id(i);
            if oid != current_order_id {
                orders.submit_cancel(oid);
            }
        }
    }

    if remaining_to_sell <= 0 {
        if current_order_id != 0 {
            orders.submit_cancel(current_order_id);
            current_order_id = 0;
        }
        return;
    }

    if current_order_id == 0 {
        let order_price = market.ask_price_0 - 1;
        let order_size = displayed_chunk;
        if order_size > remaining_to_sell {
            order_size = remaining_to_sell;
        }

        if order_size > 0 && order_price > 0 {
            orders.submit_limit_sell(order_price, order_size);
            order_placed_tick = market.tick;
            
            let new_pending_count = my_orders.pending_count();
            for i in 0..new_pending_count {
                let oid = my_orders.pending_id(i);
                let price = my_orders.pending_price(i);
                let amount = my_orders.pending_amount(i);
                if price == order_price && amount == order_size {
                    current_order_id = oid;
                    break;
                }
            }
        }
    }
}