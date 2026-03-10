let initialized = false;
let base_lot_size = 100;
let current_lot_size = base_lot_size;
let last_action_tick = -1000;
let price_buffer = [];
let ma_buffer = [];
let atr_buffer = [];
let buffer_size = 5;
let last_trade_profit = 0;
let position_size = 0;
let entry_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(80, 120);
        current_lot_size = base_lot_size;
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick % 50 != 0 { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    price_buffer.push(market.price);
    ma_buffer.push(market.ma_20);
    atr_buffer.push(market.atr_14);
    
    if price_buffer.len() > buffer_size {
        price_buffer.remove(0);
        ma_buffer.remove(0);
        atr_buffer.remove(0);
    }
    
    if price_buffer.len() < buffer_size { return; }
    
    let delayed_price = price_buffer[0];
    let delayed_ma = ma_buffer[0];
    let delayed_atr = atr_buffer[0];
    
    if delayed_atr == 0 { return; }
    
    let deviation = abs_val(delayed_price - delayed_ma);
    let threshold = (15 * delayed_atr) / 10;
    
    let buy_signal = delayed_price < delayed_ma - threshold;
    let sell_signal = delayed_price > delayed_ma + threshold;
    
    if buy_signal && account.cash > 1000000 {
        let trade_amount = current_lot_size;
        if position_size > 0 {
            let avg_diff = delayed_price - entry_price;
            if avg_diff < 0 {
                last_trade_profit = -1;
            } else {
                last_trade_profit = 1;
            }
        }
        
        orders.submit_limit_buy(delayed_price, trade_amount);
        position_size += trade_amount;
        if position_size > 0 {
            entry_price = (entry_price * (position_size - trade_amount) + delayed_price * trade_amount) / position_size;
        }
        last_action_tick = market.tick;
    }
    
    if sell_signal && position_size > 0 {
        let trade_amount = current_lot_size;
        if trade_amount > position_size {
            trade_amount = position_size;
        }
        
        orders.submit_limit_sell(delayed_price, trade_amount);
        
        if trade_amount == position_size {
            let trade_profit = (delayed_price - entry_price) * position_size;
            if trade_profit < 0 {
                last_trade_profit = -1;
            } else {
                last_trade_profit = 1;
            }
        }
        
        position_size -= trade_amount;
        if position_size == 0 {
            entry_price = 0;
        }
        last_action_tick = market.tick;
    }
    
    if last_action_tick == market.tick {
        if last_trade_profit < 0 {
            current_lot_size = current_lot_size * 2;
            if current_lot_size > 1000 {
                current_lot_size = 1000;
            }
        } else {
            current_lot_size = base_lot_size;
        }
    }
}