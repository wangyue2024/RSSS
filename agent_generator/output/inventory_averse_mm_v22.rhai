let initialized = false;
let base_lot_size = 100;
let current_lot_size = 100;
let last_trade_profit = 0;
let inventory_high_threshold = 1000;
let base_spread_micros = 5000;
let skew_factor = 2000;
let loss_streak = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(80, 120);
        current_lot_size = base_lot_size;
        inventory_high_threshold = rng.rand_int(800, 1200);
        base_spread_micros = rng.rand_int(4000, 6000);
        skew_factor = rng.rand_int(1500, 2500);
    }
    
    if !market.trading_enabled {
        return;
    }
    
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    let inventory = account.stock;
    
    let fills = my_orders.fill_count();
    if fills > 0 {
        let last_fill_idx = fills - 1;
        let fill_side = my_orders.fill_side(last_fill_idx);
        let fill_price = my_orders.fill_price(last_fill_idx);
        
        let current_value = fill_price * account.stock;
        let cost_basis = account.avg_cost * account.stock;
        
        if fill_side == 0 {
            last_trade_profit = current_value - cost_basis;
        } else {
            last_trade_profit = cost_basis - current_value;
        }
        
        if last_trade_profit < 0 {
            loss_streak += 1;
            current_lot_size = base_lot_size * (1 << loss_streak);
        } else {
            loss_streak = 0;
            current_lot_size = base_lot_size;
        }
        
        current_lot_size = clamp_val(current_lot_size, base_lot_size, base_lot_size * 16);
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if inventory > inventory_high_threshold {
        let buy_price = mid_price - base_spread_micros - skew_factor;
        let sell_price = mid_price + base_spread_micros;
        orders.submit_limit_buy(buy_price, current_lot_size);
        orders.submit_limit_sell(sell_price, current_lot_size * 2);
    } else if inventory <= 0 {
        let buy_price = mid_price - base_spread_micros;
        let sell_price = mid_price + base_spread_micros + skew_factor;
        orders.submit_limit_buy(buy_price, current_lot_size * 2);
        orders.submit_limit_sell(sell_price, current_lot_size);
    } else {
        let buy_price = mid_price - base_spread_micros;
        let sell_price = mid_price + base_spread_micros;
        orders.submit_limit_buy(buy_price, current_lot_size);
        orders.submit_limit_sell(sell_price, current_lot_size);
    }
}