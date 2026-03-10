let initialized = false;
let price_buffer = [];
let ma_20_buffer = [];
let std_dev_buffer = [];
let tick_buffer = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        price_buffer = [];
        ma_20_buffer = [];
        std_dev_buffer = [];
        tick_buffer = [];
    }
    
    if !market.trading_enabled { return; }
    
    price_buffer.push(market.price);
    ma_20_buffer.push(market.ma_20);
    std_dev_buffer.push(market.std_dev);
    tick_buffer.push(market.tick);
    
    if price_buffer.len() > 5 {
        price_buffer.remove(0);
        ma_20_buffer.remove(0);
        std_dev_buffer.remove(0);
        tick_buffer.remove(0);
    }
    
    if price_buffer.len() == 5 && tick_buffer[0] < market.tick {
        let old_price = price_buffer[0];
        let old_ma_20 = ma_20_buffer[0];
        let old_std_dev = std_dev_buffer[0];
        
        let upper_band = old_ma_20 + 2 * old_std_dev;
        let lower_band = old_ma_20 - 2 * old_std_dev;
        
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        let position_size = 1000;
        
        if account.cash >= lower_band * position_size / 1_000_000 {
            orders.submit_limit_buy(lower_band, position_size);
        }
        
        if account.stock >= position_size {
            orders.submit_limit_sell(upper_band, position_size);
        }
    }
}