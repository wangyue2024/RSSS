let initialized = false;
let base_lot = 0;
let current_lot = 0;
let last_trade_loss = false;
let recent_prices = [];
let cooldown_ticks = 0;
let last_trade_tick = 0;
let avg_entry_price = 0;
let position_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = (account.total_equity * 5 / 100) / market.price;
        if base_lot < 20 { base_lot = 20; }
        if base_lot > 100 { base_lot = 100; }
        current_lot = base_lot;
        avg_entry_price = account.avg_cost;
        position_size = account.stock;
    }
    
    if !market.trading_enabled { return; }
    
    recent_prices.push(market.price);
    if recent_prices.len() > 5 {
        recent_prices.remove(0);
    }
    
    if recent_prices.len() == 5 {
        let old_price = recent_prices[0];
        let new_price = recent_prices[4];
        if (new_price - old_price) * 100 > old_price * 2 {
            let buy_amount = current_lot;
            if buy_amount > 0 && buy_amount * market.price <= account.cash {
                orders.submit_market_buy(buy_amount);
                position_size += buy_amount;
                avg_entry_price = ((avg_entry_price * position_size) + (market.price * buy_amount)) / (position_size + buy_amount);
                last_trade_tick = market.tick;
                cooldown_ticks = 20;
                return;
            }
        }
    }
    
    if market.std_dev > (market.price * 2 / 100) {
        return;
    }
    
    if market.tick - last_trade_tick < cooldown_ticks {
        return;
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.rsi_14 < 3000 {
        let buy_price = market.bid_price_0 * 99 / 100;
        if buy_price == 0 { buy_price = market.price * 99 / 100; }
        let buy_amount = current_lot;
        if buy_amount > 0 && buy_amount * buy_price <= account.cash {
            orders.submit_limit_buy(buy_price, buy_amount);
            last_trade_tick = market.tick;
            cooldown_ticks = 20;
            if last_trade_loss {
                current_lot = current_lot * 2;
                if current_lot > 200 { current_lot = 200; }
            } else {
                current_lot = base_lot;
            }
        }
    } else if market.rsi_14 > 7000 && account.stock > 0 {
        let sell_price = market.ask_price_0 * 101 / 100;
        if sell_price == 0 { sell_price = market.price * 101 / 100; }
        let sell_amount = current_lot;
        if sell_amount > account.stock { sell_amount = account.stock; }
        if sell_amount > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
            last_trade_tick = market.tick;
            cooldown_ticks = 20;
            if market.price < avg_entry_price {
                last_trade_loss = true;
                current_lot = current_lot * 2;
                if current_lot > 200 { current_lot = 200; }
            } else {
                last_trade_loss = false;
                current_lot = base_lot;
            }
        }
    }
    
    let fill_count = my_orders.fill_count();
    if fill_count > 0 {
        let last_fill_idx = fill_count - 1;
        let fill_side = my_orders.fill_side(last_fill_idx);
        let fill_price = my_orders.fill_price(last_fill_idx);
        
        if fill_side == 0 {
            position_size += my_orders.fill_amount(last_fill_idx);
            avg_entry_price = ((avg_entry_price * (position_size - my_orders.fill_amount(last_fill_idx))) + (fill_price * my_orders.fill_amount(last_fill_idx))) / position_size;
        } else {
            position_size -= my_orders.fill_amount(last_fill_idx);
            if market.price < avg_entry_price {
                last_trade_loss = true;
            } else {
                last_trade_loss = false;
            }
        }
    }
}