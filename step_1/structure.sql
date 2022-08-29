CREATE TABLE bank_accounts (
  id serial PRIMARY KEY,
  account varchar(9),
  agency varchar(4),
  CONSTRAINT account_agency UNIQUE (account, agency)
);

CREATE UNIQUE INDEX bank_account_pk_idx on bank_accounts (id);
CREATE INDEX bank_account_idx on bank_accounts (account, agency);

CREATE TYPE transaction_type AS ENUM (
  'income', 'withdrawal', 'payment'
);

CREATE TABLE account_transactions (
  id serial PRIMARY KEY,
  amount integer NOT NULL,
  type transaction_type NOT NULL,
  processed_at timestamp NOT NULL,
  created_at timestamp NOT NULL DEFAULT NOW(),
  bank_account_id int NOT NULL REFERENCES bank_accounts (id)
);

CREATE UNIQUE INDEX account_transaction_pk_idx on account_transactions (id);
CREATE INDEX account_transaction_amount_idx on account_transactions (amount);
CREATE INDEX account_transaction_processed_idx on account_transactions (processed_at);

CREATE TABLE bank_transfers (
  id serial PRIMARY KEY,
  amount integer NOT NULL,
  processed_at timestamp NOT NULL,
  created_at timestamp NOT NULL DEFAULT NOW(),
  from_account int NOT NULL REFERENCES bank_accounts (id),
  to_account int NOT NULL REFERENCES bank_accounts (id)
);

CREATE UNIQUE INDEX bank_transfer_pk_idx on bank_transfers (id);
CREATE INDEX bank_transfer_amount_idx on bank_transfers (amount);
CREATE INDEX bank_transfer_processed_idx on bank_transfers (processed_at);
