let initialized = false;
let iceberg_total = 0;
let slice_size = 0;
let remaining_to_sell = 0;
let pending_order_id = 0;
let pending_order_age = 0;
let panic_threshold = 0;

fn on_tick() {
    if !initialized {
        iceberg_total = account.stock * 9 / 10;
        slice_size = iceberg_total / 100;
        if slice_size < 1 { slice_size = 1; }
        remaining_to_sell = iceberg_total;
        panic_threshold = -rng.rand_int(50_000, 200_000);
        initialized = true;
    }

    if !market.trading_enabled { return; }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    let found_fill = false;
    let fill_count = my_orders.fill_count();
    let i = 0;
    while i < fill_count {
        if my_orders.fill_side(i) == 1 {
            remaining_to_sell -= my_orders.fill_amount(i);
            found_fill = true;
        }
        i += 1;
    }

    if found_fill && remaining_to_sell > 0 {
        let target_size = slice_size;
        if target_size > remaining_to_sell {
            target_size = remaining_to_sell;
        }
        if market.ask_price_0 > 0 {
            orders.submit_limit_sell(market.ask_price_0, target_size);
            pending_order_age = 0;
        }
    }

    let found_pending = false;
    let pending_count = my_orders.pending_count();
    i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        if oid == pending_order_id && my_orders.pending_side(i) == 1 {
            found_pending = true;
            pending_order_age += 1;
            
            if pending_order_age >= 3 {
                orders.submit_cancel(oid);
                pending_order_id = 0;
                pending_order_age = 0;
                
                if remaining_to_sell > 0 && market.ask_price_0 > 0 {
                    let target_size = slice_size;
                    if target_size > remaining_to_sell {
                        target_size = remaining_to_sell;
                    }
                    orders.submit_limit_sell(market.ask_price_0, target_size);
                }
            }
            break;
        }
        i += 1;
    }

    if !found_pending && remaining_to_sell > 0 {
        pending_order_id = 0;
        pending_order_age = 0;
        
        if market.ask_price_0 > 0 {
            let target_size = slice_size;
            if target_size > remaining_to_sell {
                target_size = remaining_to_sell;
            }
            orders.submit_limit_sell(market.ask_price_0, target_size);
        }
    }
}