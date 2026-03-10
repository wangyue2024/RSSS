let initialized = false;
let total_sell_target = 0;
let visible_amount = 0;
let remaining_sell = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let risk_percentage = rng.rand_int(40, 50);
        total_sell_target = account.stock * risk_percentage / 100;
        visible_amount = rng.rand_int(1, 5);
        if visible_amount > total_sell_target {
            visible_amount = total_sell_target;
        }
        remaining_sell = total_sell_target;
    }
    
    if !market.trading_enabled { return; }
    
    let fills = my_orders.fill_count();
    let i = 0;
    while i < fills {
        let side = my_orders.fill_side(i);
        if side == 1 {
            let filled_qty = my_orders.fill_amount(i);
            remaining_sell = remaining_sell - filled_qty;
        }
        i += 1;
    }
    
    let pending = my_orders.pending_count();
    let j = 0;
    while j < pending {
        let oid = my_orders.pending_id(j);
        orders.submit_cancel(oid);
        j += 1;
    }
    
    if remaining_sell > 0 && market.ask_price_0 > 0 && account.avg_cost > 0 {
        let target_price = market.ask_price_0 - 1;
        if target_price > account.avg_cost {
            let order_qty = visible_amount;
            if order_qty > remaining_sell {
                order_qty = remaining_sell;
            }
            if order_qty > 0 {
                orders.submit_limit_sell(target_price, order_qty);
            }
        }
    }
}