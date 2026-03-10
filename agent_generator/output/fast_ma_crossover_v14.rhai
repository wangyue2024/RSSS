let initialized = false;
let ma_5_hist = [];
let ma_20_hist = [];
let prev_cross_state = 0;
let position_state = 0;
const TRADE_AMOUNT = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    ma_5_hist.push(market.ma_5);
    ma_20_hist.push(market.ma_20);
    
    if ma_5_hist.len() > 5 {
        ma_5_hist.remove(0);
        ma_20_hist.remove(0);
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if ma_5_hist.len() < 5 {
        return;
    }
    
    let delayed_ma5 = ma_5_hist[0];
    let delayed_ma20 = ma_20_hist[0];
    
    let new_cross_state = if delayed_ma5 > delayed_ma20 { 1 } else { -1 };
    
    if new_cross_state != prev_cross_state {
        prev_cross_state = new_cross_state;
        
        if new_cross_state == 1 && position_state <= 0 {
            orders.submit_market_buy(TRADE_AMOUNT);
            position_state = 1;
        } else if new_cross_state == -1 && position_state >= 0 {
            if account.stock > 0 {
                orders.submit_market_sell(account.stock);
            }
            position_state = -1;
        }
    }
}