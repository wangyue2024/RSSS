let initialized = false;
let price_buffer = [];
let last_price = 0;
let lot_size = 100;
let base_lot = 100;
let last_was_loss = false;
let loss_count = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = rng.rand_int(80, 120);
        lot_size = base_lot;
    }
    
    if !market.trading_enabled { return; }
    
    let current_price = market.price;
    
    if price_buffer.len() < 5 {
        price_buffer.push(current_price);
        return;
    }
    
    price_buffer.push(current_price);
    if price_buffer.len() > 5 {
        price_buffer.remove(0);
    }
    
    let delayed_price = price_buffer[0];
    last_price = delayed_price;
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let inventory = account.stock;
    let avg_cost = account.avg_cost;
    
    if inventory != 0 && avg_cost != 0 {
        let price_diff = delayed_price - avg_cost;
        if (inventory > 0 && price_diff < 0) || (inventory < 0 && price_diff > 0) {
            last_was_loss = true;
            loss_count += 1;
        } else {
            last_was_loss = false;
            loss_count = 0;
        }
    }
    
    if last_was_loss && loss_count <= 5 {
        lot_size = base_lot * (1 << loss_count).clamp_val(1, 32);
    } else {
        lot_size = base_lot;
        loss_count = 0;
    }
    
    lot_size = lot_size.clamp_val(1, 10000);
    
    let std_dev = market.std_dev;
    let base_spread = 2000;
    let vol_factor = 8;
    let spread = base_spread + std_dev * vol_factor / 1000;
    spread = spread.clamp_val(500, 50000);
    
    let half_spread = spread / 2;
    let buy_price = delayed_price - half_spread;
    let sell_price = delayed_price + half_spread;
    
    buy_price = buy_price.clamp_val(1, 1000000000);
    sell_price = sell_price.clamp_val(1, 1000000000);
    
    let buy_amount = lot_size;
    let sell_amount = lot_size;
    
    if account.cash >= buy_price * buy_amount / 1000000 {
        orders.submit_limit_buy(buy_price, buy_amount);
    }
    
    if account.stock >= sell_amount {
        orders.submit_limit_sell(sell_price, sell_amount);
    }
}