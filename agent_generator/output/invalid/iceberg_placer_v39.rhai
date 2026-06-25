let initialized = false;
let total_target_sell = 0;
let iceberg_size = 0;
let remaining_to_sell = 0;
let last_price = 0;
let last_order_filled = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        total_target_sell = 50000;
        iceberg_size = 100;
        remaining_to_sell = total_target_sell;
        last_price = market.price;
    }
    
    if !market.trading_enabled { return; }
    
    let price_jump_pct = ((market.price - last_price) * 10000) / last_price;
    if price_jump_pct > 200 {
        orders.submit_market_buy(1000);
        last_price = market.price;
        return;
    }
    
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        last_order_filled = true;
        for i in 0..fill_cnt {
            if my_orders.fill_side(i) == 1 {
                let fill_amt = my_orders.fill_amount(i);
                if remaining_to_sell >= fill_amt {
                    remaining_to_sell -= fill_amt;
                }
            }
        }
    }
    
    let pending_cnt = my_orders.pending_count();
    for i in 0..pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
    }
    
    if remaining_to_sell <= 0 { return; }
    
    if last_order_filled || pending_cnt == 0 {
        let raw_price = market.ask_price_0;
        let round_price = ((raw_price + 500_000) / 1_000_000) * 1_000_000;
        
        let order_amt = iceberg_size;
        if order_amt > remaining_to_sell {
            order_amt = remaining_to_sell;
        }
        
        if order_amt > 0 {
            orders.submit_limit_sell(round_price, order_amt);
        }
        
        last_order_filled = false;
    }
    
    last_price = market.price;
}