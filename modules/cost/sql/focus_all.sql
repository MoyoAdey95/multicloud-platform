-- The three provider views produce the same columns in the same order and with
-- the same types, so they stack with a plain UNION ALL. A change to one view
-- that breaks that shape makes this view fail to create, which is the point.
SELECT * FROM `${dataset}.focus_aws`
UNION ALL
SELECT * FROM `${dataset}.focus_gcp`
UNION ALL
SELECT * FROM `${dataset}.focus_azure`
