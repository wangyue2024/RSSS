let initialized = false;
let base_lot_size = 100;
let current_lot_size = 100;
let was_in_loss = false;
let half_spread = 5_000;
let inventory_skew_factor = 10;
let max_inventory = 1_000;
let loss_tracker = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(80, 120);
        current_lot_size = base_lot_size;
        half_spread = rng.rand_int(4_000, 6_000);
        inventory_skew_factor = rng.rand_int(5, 15);
        max_inventory = rng.rand_int(800, 1_200);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let inventory = account.stock;
    let avg_cost = account.avg_cost;
    let current_price = market.price;
    
    let in_loss = if avg_cost > 0 && inventory > 0 {
        current_price < avg_cost
    } else {
        false
    };
    
    if !was_in_loss && in_loss {
        current_lot_size = current_lot_size * 2;
        loss_tracker = 1;
    } else if was_in_loss && !in_loss && loss_tracker == 1 {
        current_lot_size = base_lot_size;
        loss_tracker = 0;
    }
    was_in_loss = in_loss;
    
    let lot_size = if current_lot_size < 10 { 10 } else {
        if current_lot_size > 1_000 { 1_000 } else { current_lot_size }
    };
    
    let adjustment = 0;
    if inventory > max_inventory {
        adjustment = inventory_skew_factor * (inventory - max_inventory);
    } else if inventory <= 0 {
        adjustment = inventory_skew_factor * inventory;
    }
    
    let adjusted_mid = current_price - adjustment;
    let buy_price = adjusted_mid - half_spread;
    let sell_price = adjusted_mid + half_spread;
    
    let max_buy_amount = account.cash / buy_price;
    let max_sell_amount = account.stock;
    
    if buy_price > 0 && max_buy_amount >= lot_size {
        orders.submit_limit_buy(buy_price, lot_size);
    }
    
    if sell_price > avg_cost && max_sell_amount >= lot_size {
        orders.submit_limit_sell(sell_price, lot_size);
    }
}