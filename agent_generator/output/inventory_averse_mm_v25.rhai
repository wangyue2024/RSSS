let initialized = false;
let base_spread = 0;
let max_inventory = 0;
let lot_size = 0;
let skew_factor = 0;
let cancel_timer = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(2000, 10000);
        max_inventory = rng.rand_int(800, 2000);
        skew_factor = rng.rand_int(10, 40);
        cancel_timer = 0;
        
        let risk_factor = rng.rand_int(30, 50);
        let available_cash = account.cash / 1_000_000;
        let rough_lot_value = (available_cash * risk_factor) / 100;
        lot_size = rough_lot_value * 100;
        if lot_size < 100 { lot_size = 100; }
    }
    
    if !market.trading_enabled { return; }
    
    cancel_timer += 1;
    if cancel_timer >= 5 {
        cancel_timer = 0;
        let pending = my_orders.pending_count();
        let i = 0;
        while i < pending {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
    }
    
    if market.bid_price_0 <= 0 || market.ask_price_0 <= 0 { return; }
    
    let mid = (market.bid_price_0 + market.ask_price_0) / 2;
    let inventory = account.stock;
    
    let inventory_ratio = (inventory * 100) / max_inventory;
    let inventory_ratio = clamp_val(inventory_ratio, -100, 100);
    
    let bid_offset = (base_spread * (100 - inventory_ratio)) / 200;
    let ask_offset = (base_spread * (100 + inventory_ratio)) / 200;
    
    let bid_price = mid - bid_offset;
    let ask_price = mid + ask_offset;
    
    if bid_price <= 0 || ask_price <= 0 { return; }
    
    let buy_lot = lot_size;
    let sell_lot = lot_size;
    
    if inventory > max_inventory {
        buy_lot = (buy_lot * (100 - skew_factor)) / 100;
        sell_lot = (sell_lot * (100 + skew_factor)) / 100;
    } else if inventory < -max_inventory {
        buy_lot = (buy_lot * (100 + skew_factor)) / 100;
        sell_lot = (sell_lot * (100 - skew_factor)) / 100;
    }
    
    if buy_lot < 10 { buy_lot = 10; }
    if sell_lot < 10 { sell_lot = 10; }
    
    let max_buy = account.cash / bid_price;
    if buy_lot > max_buy { buy_lot = max_buy; }
    
    let max_sell = account.stock;
    if sell_lot > max_sell { sell_lot = max_sell; }
    
    if buy_lot > 0 {
        orders.submit_limit_buy(bid_price, buy_lot);
    }
    
    if sell_lot > 0 {
        orders.submit_limit_sell(ask_price, sell_lot);
    }
}