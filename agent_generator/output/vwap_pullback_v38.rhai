let initialized = false;
let base_lot = 100;
let current_lot = base_lot;
let vwap_threshold = 150;
let trade_active = false;
let last_avg_cost = 0;
let last_buy_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        vwap_threshold = rng.rand_int(100, 200);
        base_lot = rng.rand_int(50, 150);
        current_lot = base_lot;
    }
    
    if !market.trading_enabled { return; }
    
    let pos = account.stock;
    let vwap = market.vwap;
    let price = market.price;
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    if pos == 0 {
        trade_active = false;
        let threshold_value = vwap - (vwap * vwap_threshold / 10000);
        if price <= threshold_value {
            let buy_qty = current_lot;
            orders.submit_market_buy(buy_qty);
            last_buy_price = price;
            trade_active = true;
        }
    } else {
        let cost_basis = account.avg_cost;
        let is_loss = price < cost_basis;
        
        if price >= vwap {
            orders.submit_market_sell(pos);
            if is_loss && trade_active {
                current_lot = current_lot * 2;
            } else {
                current_lot = base_lot;
            }
            trade_active = false;
        }
    }
}