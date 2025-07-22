WITH non_null_simulation_results AS (
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
)
SELECT
  treatment,
  control,
  true_effect,
  N,
  bwfactor,  
  AVG(atet) - true_effect AS bias,
  STDDEV(atet) AS se,
  SQRT(AVG(POW(atet - true_effect, 2))) AS rmse,
  AVG(se) AS avse,
  AVG(coverage) AS coverage_rate
FROM
  non_null_simulation_results
GROUP BY
  treatment, control, true_effect, N, bwfactor
ORDER BY
  treatment, control, N, bwfactor
;