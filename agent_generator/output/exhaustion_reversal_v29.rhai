let initialized = false;
let delay_ticks = 5;
let price_buffer = [];
let volume_buffer = [];
let ma_buffer = [];
let lot_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size = rng.rand_int(30, 50);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    price_buffer.push(market.price);
    volume_buffer.push(market.volume);
    ma_buffer.push(market.ma_60);
    
    if price_buffer.len() > delay_ticks {
        price_buffer.remove(0);
        volume_buffer.remove(0);
        ma_buffer.remove(0);
    }
    
    if price_buffer.len() == delay_ticks {
        let old_price = price_buffer[0];
        let old_volume = volume_buffer[0];
        let old_ma = ma_buffer[0];
        
        let condition1 = old_price > old_ma;
        let condition2 = old_volume < 1000;
        
        if condition1 && condition2 {
            let cash_to_use = account.cash * lot_size / 100;
            let sell_amount = cash_to_use / market.price;
            
            if sell_amount > 0 {
                orders.submit_limit_sell(market.price, sell_amount);
            }
        }
    }
}