let initialized = false;
let lot_size = 0;
let base_spread = 0;
let cancel_age = 3;
let inventory_threshold = 1000;
let active_period = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        active_period = market.total_ticks / 5;
        
        let max_lot_value = account.total_equity * 5 / 100;
        let max_shares = max_lot_value / market.price;
        if max_shares < 1 {
            lot_size = 1;
        } else {
            lot_size = rng.rand_int(1, max_shares);
        }
        
        base_spread = market.price * 2 / 100;
        if base_spread < 1000 {
            base_spread = 1000;
        }
    }
    
    if !market.trading_enabled {
        return;
    }
    
    if market.tick >= active_period {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    if market.std_dev > market.price * 10 / 100 {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    let current_tick = market.tick;
    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick >= cancel_age {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    let inventory = account.stock;
    let ref_price = market.price;
    let spread_adjust = 0;
    
    if inventory > inventory_threshold {
        spread_adjust = base_spread * 50 / 100;
    } else if inventory <= 0 {
        spread_adjust = -base_spread * 50 / 100;
    }
    
    let buy_distance = base_spread + spread_adjust;
    let sell_distance = base_spread - spread_adjust;
    
    if buy_distance < 100 {
        buy_distance = 100;
    }
    if sell_distance < 100 {
        sell_distance = 100;
    }
    
    let buy_price = ref_price - buy_distance;
    let sell_price = ref_price + sell_distance;
    
    if buy_price < 1 {
        buy_price = 1;
    }
    
    let pending_buy = false;
    let pending_sell = false;
    let pcount = my_orders.pending_count();
    let j = 0;
    while j < pcount {
        let side = my_orders.pending_side(j);
        if side == 0 {
            pending_buy = true;
        } else if side == 1 {
            pending_sell = true;
        }
        j += 1;
    }
    
    if !pending_buy && buy_price > 0 {
        let buy_amount = lot_size;
        if buy_amount > 0 && account.cash >= buy_price * buy_amount {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    }
    
    if !pending_sell && sell_price > 0 {
        let sell_amount = lot_size;
        if sell_amount > 0 && account.stock >= sell_amount {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}