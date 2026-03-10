let initialized = false;
let panic_threshold = 0;
let total_to_sell = 0;
let chunk_size = 0;
let remaining_to_sell = 0;
let round_mod = 1_000_000;

fn on_tick() {
    if !initialized {
        panic_threshold = -rng.rand_int(50_000, 200_000);
        total_to_sell = account.stock;
        chunk_size = total_to_sell / 100;
        if chunk_size < 1 { chunk_size = 1; }
        remaining_to_sell = total_to_sell;
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        orders.submit_market_sell(account.stock);
        remaining_to_sell = 0;
        return;
    }
    
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let i = 0;
        while i < fill_cnt {
            if my_orders.fill_side(i) == 1 {
                let filled = my_orders.fill_amount(i);
                if filled > remaining_to_sell {
                    remaining_to_sell = 0;
                } else {
                    remaining_to_sell -= filled;
                }
            }
            i += 1;
        }
    }
    
    let pending_cnt = my_orders.pending_count();
    let has_pending_sell = false;
    let i = 0;
    while i < pending_cnt {
        if my_orders.pending_side(i) == 1 {
            has_pending_sell = true;
            break;
        }
        i += 1;
    }
    
    if !has_pending_sell && remaining_to_sell > 0 {
        let current_chunk = chunk_size;
        if current_chunk > remaining_to_sell {
            current_chunk = remaining_to_sell;
        }
        
        if current_chunk > 0 && market.ask_price_0 > 0 {
            let raw_price = market.ask_price_0;
            let rounded_price = (raw_price / round_mod) * round_mod;
            
            orders.submit_limit_sell(rounded_price, current_chunk);
        }
    }
}