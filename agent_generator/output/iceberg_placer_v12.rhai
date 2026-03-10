let initialized = false;
let target_sell_amount = 0;
let base_lot_size = 0;
let current_lot_size = 0;
let total_sold = 0;
let panic_threshold = 0;
let last_fill_price = 0;
let last_avg_cost_at_fill = 0;
let current_order_id = 0;

fn on_tick() {
    if !initialized {
        if account.stock > 0 {
            target_sell_amount = (account.stock * 8) / 10;
            base_lot_size = (account.stock * 1) / 100;
            if base_lot_size < 1 { base_lot_size = 1; }
            current_lot_size = base_lot_size;
            panic_threshold = -rng.rand_int(100_000, 500_000);
        }
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    if account.stock <= 0 { return; }
    
    if account.unrealized_pnl < panic_threshold {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }
    
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let i = 0;
        while i < fill_cnt {
            let fill_side = my_orders.fill_side(i);
            if fill_side == 1 {
                total_sold += my_orders.fill_amount(i);
                last_fill_price = my_orders.fill_price(i);
                last_avg_cost_at_fill = account.avg_cost;
                
                if last_fill_price < last_avg_cost_at_fill {
                    current_lot_size = current_lot_size * 2;
                    if current_lot_size > target_sell_amount - total_sold {
                        current_lot_size = target_sell_amount - total_sold;
                    }
                } else {
                    current_lot_size = base_lot_size;
                }
            }
            i += 1;
        }
    }
    
    let remaining = target_sell_amount - total_sold;
    if remaining <= 0 { return; }
    
    let pending_cnt = my_orders.pending_count();
    let has_active = false;
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        if oid == current_order_id {
            has_active = true;
            break;
        }
        i += 1;
    }
    
    if !has_active && remaining > 0 && market.ask_price_0 > 0 {
        let order_amount = current_lot_size;
        if order_amount > remaining { order_amount = remaining; }
        if order_amount > account.stock { order_amount = account.stock; }
        if order_amount > 0 {
            current_order_id = orders.submit_limit_sell(market.ask_price_0, order_amount);
        }
    }
}