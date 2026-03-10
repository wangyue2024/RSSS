let initialized = false;
let total_to_sell = 0;
let chunk_size = 0;
let sold_so_far = 0;
let last_order_id = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        total_to_sell = 1000;
        chunk_size = 10;
        sold_so_far = 0;
        last_order_id = 0;
    }
    
    if !market.trading_enabled { return; }
    
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let i = 0;
        while i < fill_cnt {
            let fid = my_orders.fill_id(i);
            if fid == last_order_id && my_orders.fill_side(i) == "sell" {
                sold_so_far = sold_so_far + my_orders.fill_amount(i);
            }
            i = i + 1;
        }
    }
    
    let pending_cnt = my_orders.pending_count();
    let has_pending_sell = false;
    let j = 0;
    while j < pending_cnt {
        let oid = my_orders.pending_id(j);
        if oid == last_order_id && my_orders.pending_side(j) == "sell" {
            has_pending_sell = true;
        }
        j = j + 1;
    }
    
    if !has_pending_sell && sold_so_far < total_to_sell {
        if market.ask_price_0 > 0 {
            let remaining = total_to_sell - sold_so_far;
            let order_amt = chunk_size;
            if order_amt > remaining {
                order_amt = remaining;
            }
            let target_price = market.ask_price_0 + 1;
            last_order_id = orders.submit_limit_sell(target_price, order_amt);
        }
    }
}