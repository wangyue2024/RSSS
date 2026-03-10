let initialized = false;
let target_position = 50000;
let slice_size = 500;
let action_interval = 50;

fn on_tick() {
    if !initialized {
        initialized = true;
    }

    if !market.trading_enabled { return; }

    if market.tick % action_interval == 0 {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }

        let current_position = account.stock;
        if current_position < target_position {
            let remaining = target_position - current_position;
            let amount = remaining;
            if amount > slice_size {
                amount = slice_size;
            }
            
            let current_price = market.price;
            let base_price = current_price / 1_000_000 * 1_000_000;
            let remainder = current_price % 1_000_000;
            let round_price = base_price;
            
            if remainder >= 500_000 {
                round_price = base_price + 1_000_000;
            }
            
            let limit_price = round_price + 1;
            orders.submit_limit_buy(limit_price, amount);
        }
    }
}