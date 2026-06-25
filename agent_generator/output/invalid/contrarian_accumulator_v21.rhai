let initialized = false;
let panic_threshold = 0;
let trade_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(5000, 20000);
        trade_size = rng.rand_int(20, 100);
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.unrealized_pnl < panic_threshold && account.unrealized_pnl < 0 {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }

    let rsi = market.rsi_14;

    if rsi < 3000 {
        if account.cash > 0 {
            let bid = market.bid_price_0;
            if bid > 0 {
                let limit_price = bid + 1;
                let max_shares = account.cash / limit_price;
                if max_shares > 0 {
                    let shares_to_buy = trade_size;
                    if shares_to_buy > max_shares {
                        shares_to_buy = max_shares;
                    }
                    if shares_to_buy > 0 {
                        orders.submit_limit_buy(limit_price, shares_to_buy);
                    }
                }
            }
        }
    }

    if rsi > 7000 && account.stock > 0 {
        let avg = account.avg_cost;
        let ask = market.ask_price_0;
        if ask > avg && ask > 0 {
            let limit_price = ask - 1;
            let shares_to_sell = trade_size;
            if shares_to_sell > account.stock {
                shares_to_sell = account.stock;
            }
            if shares_to_sell > 0 {
                orders.submit_limit_sell(limit_price, shares_to_sell);
            }
        }
    }
}