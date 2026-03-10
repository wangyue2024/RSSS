let initialized = false;
let base_lot = 100;
let lot_size = base_lot;
let last_trade_win = true;
let position_side = 0;
let entry_price = 0;

let price_buffer = [];
let volume_buffer = [];
let ma_buffer = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = 100;
        lot_size = base_lot;
        last_trade_win = true;
        position_side = 0;
        entry_price = 0;
        price_buffer = [];
        volume_buffer = [];
        ma_buffer = [];
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

    if price_buffer.len() > 5 {
        price_buffer.remove(0);
        volume_buffer.remove(0);
        ma_buffer.remove(0);
    }

    if price_buffer.len() == 5 {
        let old_price = price_buffer[0];
        let old_volume = volume_buffer[0];
        let old_ma = ma_buffer[0];
        let volume_threshold = 100;

        if old_price > old_ma && old_volume < volume_threshold {
            if position_side == 1 {
                let close_amount = account.stock;
                if close_amount > 0 {
                    orders.submit_market_sell(close_amount);
                    let profit = market.price - entry_price;
                    last_trade_win = profit > 0;
                }
                position_side = 0;
                entry_price = 0;
            } else if position_side == -1 {
                let close_amount = -account.stock;
                if close_amount > 0 {
                    orders.submit_market_buy(close_amount);
                    let profit = entry_price - market.price;
                    last_trade_win = profit > 0;
                }
                position_side = 0;
                entry_price = 0;
            }

            if !last_trade_win {
                lot_size = lot_size * 2;
            } else {
                lot_size = base_lot;
            }

            orders.submit_market_sell(lot_size);
            entry_price = market.price;
            position_side = -1;
        }
    }
}