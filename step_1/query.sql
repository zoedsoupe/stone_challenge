SELECT SUM(amount) AS total_amount
  FROM account_transactions AS t
  GROUP BY MONTH(FROM_UNIXTIME(t.processed_at))
  ORDER BY MONTH(FROM_UNIXTIME(t.processed_at))
  WHERE t.type = 'payment'
  WHERE YEAR(FROM_UNIXTIME(t.processed_at)) = YEAR(CURDATE());
