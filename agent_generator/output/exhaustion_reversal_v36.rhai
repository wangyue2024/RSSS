let initialized = false;
let buffer = [];
let buffer_size = 5;
let volume_threshold = 1000;
let trade_amount = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
    }

    if !market.trading_enabled { return; }

    if market.tick >= market.total_ticks / 5 {
        return;
    }

    let current_tick_data = [market.price, market.volume, market.ma_60, market.high_20];
    buffer.push(current_tick_data);

    if buffer.len() > buffer_size {
        buffer.remove(0);
    }

    if buffer.len() == buffer_size {
        let delayed_data = buffer[0];
        let delayed_price = delayed_data[0];
        let delayed_volume = delayed_data[1];
        let delayed_ma_60 = delayed_data[2];
        let delayed_high_20 = delayed_data[3];

        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }

        if delayed_high_20 > delayed_ma_60 && delayed_volume < volume_threshold {
            let sell_price = market.price + 1;
            orders.submit_limit_sell(sell_price, trade_amount);
        }
    }
}