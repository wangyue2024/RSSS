let initialized = false;
let base_lot_size = 100;
let lot_size = base_lot_size;
let last_trade_was_loss = false;
let price_buffer = [];
let delayed_price = 0;
let delay_ticks = 5;
let phase = 0;
let sell_price = 0;
let buy_target = 0;
let stop_loss = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = 100;
        lot_size = base_lot_size;
        last_trade_was_loss = false;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    price_buffer.push(market.price);
    if price_buffer.len() > delay_ticks {
        delayed_price = price_buffer[price_buffer.len() - delay_ticks - 1];
        price_buffer.remove(0);
    }
    
    if phase == 1 {
        if market.price <= buy_target {
            orders.submit_market_buy(lot_size);
            let profit = (sell_price - market.price) * lot_size;
            last_trade_was_loss = profit <= 0;
            if last_trade_was_loss {
                lot_size = lot_size * 2;
                if lot_size > 1000 { lot_size = 1000; }
            } else {
                lot_size = base_lot_size;
            }
            phase = 0;
        } else if market.price >= stop_loss {
            orders.submit_market_buy(lot_size);
            last_trade_was_loss = true;
            lot_size = lot_size * 2;
            if lot_size > 1000 { lot_size = 1000; }
            phase = 0;
        }
        return;
    }
    
    if price_buffer.len() < delay_ticks { return; }
    
    let support_low = delayed_price - delayed_price * 150 / 10000;
    let support_high = delayed_price - delayed_price * 50 / 10000;
    
    let cluster_volume = 0;
    if market.ask_price_0 >= support_low && market.ask_price_0 <= support_high {
        cluster_volume += market.ask_vol_0;
    }
    if market.ask_price_1 >= support_low && market.ask_price_1 <= support_high {
        cluster_volume += market.ask_vol_1;
    }
    if market.ask_price_2 >= support_low && market.ask_price_2 <= support_high {
        cluster_volume += market.ask_vol_2;
    }
    if market.ask_price_3 >= support_low && market.ask_price_3 <= support_high {
        cluster_volume += market.ask_vol_3;
    }
    if market.ask_price_4 >= support_low && market.ask_price_4 <= support_high {
        cluster_volume += market.ask_vol_4;
    }
    
    if cluster_volume > 10 * lot_size && market.price > support_high {
        orders.submit_market_sell(lot_size);
        sell_price = market.price;
        buy_target = sell_price - sell_price * 250 / 10000;
        stop_loss = sell_price + sell_price * 100 / 10000;
        phase = 1;
    }
}