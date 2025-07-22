SELECT
  * EXCEPT(group_row_number)
FROM (
  SELECT 
    *,
    ROW_NUMBER() OVER (
      PARTITION BY
        CAST(treatment AS STRING),
        CAST(control AS STRING),
        CAST(true_effect AS STRING),
        CAST(N AS STRING),
        CAST(bwfactor AS STRING)
      ORDER BY 
        seed
    ) AS group_row_number
  FROM
    `project.dataset.table_name`
  WHERE
    atet IS NOT NULL
    AND
    se IS NOT NULL
    AND
    coverage IS NOT NULL
)
WHERE
  group_row_number <= 4000
;