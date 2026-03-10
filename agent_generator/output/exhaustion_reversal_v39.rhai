let initialized = false;
let price_buffer = [];
let volume_buffer = [];
let last_trade_loss = false;
let base_lot_size = 1000;
let current_lot_size = 1000;
let short_position_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(800, 1200);
        current_lot_size = base_lot_size;
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= market.total_ticks / 5 {
        let pending = my_orders.pending_count();
        let i = 0;
        while i < pending {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }
    
    price_buffer.push(market.price);
    volume_buffer.push(market.volume);
    
    if price_buffer.len() > 5 {
        price_buffer.remove(0);
        volume_buffer.remove(0);
    }
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    if price_buffer.len() < 5 {
        return;
    }
    
    let delayed_price = price_buffer[0];
    let delayed_volume = volume_buffer[0];
    
    let avg_volume = (volume_buffer[1] + volume_buffer[2] + volume_buffer[3] + volume_buffer[4]) / 4;
    
    let long_exhaustion = delayed_price > market.ma_60 && delayed_volume * 100 < avg_volume && avg_volume > 0;
    
    if long_exhaustion && account.stock <= 0 {
        let sell_amount = current_lot_size;
        if sell_amount > 0 {
            orders.submit_market_sell(sell_amount);
            short_position_price = market.price;
        }
    }
    
    if account.stock < 0 {
        let unrealized_loss = market.price > short_position_price;
        if unrealized_loss {
            let cover_amount = -account.stock;
            if cover_amount > 0 {
                orders.submit_market_buy(cover_amount);
                last_trade_loss = true;
                current_lot_size = current_lot_size * 2;
            }
        } else if market.price * 95 / 100 < short_position_price {
            let cover_amount = -account.stock;
            if cover_amount > 0 {
                orders.submit_market_buy(cover_amount);
                last_trade_loss = false;
                current_lot_size = base_lot_size;
            }
        }
    }
    
    if last_trade_loss && account.stock == 0 {
        current_lot_size = base_lot_size;
        last_trade_loss = false;
    }
}