
-- creating indexes
CREATE index idx_house_key
ON dunnhumby.transaction_data(household_key)

CREATE index idx_sales_value
ON dunnhumby.transaction_data("SALES_VALUE")

create index idx_trans_DAY
ON dunnhumby.transaction_data("DAY")

create index idx_housekey_day
ON dunnhumby.transaction_data(household_key, "DAY")