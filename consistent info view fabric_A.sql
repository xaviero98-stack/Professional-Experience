CREATE VIEW consistent_info AS

WITH vess AS(

SELECT 
	[INVOICE],
	[MTOC],
	[UNITS],
	[DATE OF UPLOAD],
	MAX([DATE OF UPLOAD]) OVER (PARTITION BY [INVOICE], [MTOC], [CONTAINER], [UNITS]) AS MAX_DATE
FROM
	dbo.[06_VESSELS]
WHERE 
	[Factory] = 'factory_A'
				
), acc_vess AS (

SELECT
	[INVOICE],
	[MTOC],
	[UNITS],
	[DATE OF UPLOAD]
FROM
	vess
WHERE
	[DATE OF UPLOAD] = MAX_DATE
	
), agg_vess AS(

SELECT
	LEFT([INVOICE], LEN([INVOICE]) - 2) AS PO,
	[INVOICE],
	[MTOC],
	SUM([UNITS]) AS UNITS
FROM
	acc_vess
GROUP BY 
	LEFT([INVOICE], LEN([INVOICE]) - 2),
	[INVOICE],
	[MTOC]
	
), filt_book AS (
	
SELECT 
	[ORDER_MONTH],
	[MTOC],
	[INVOICE],
	[UNITS]
FROM 
	dbo.[06_BOOKINGS]
WHERE
	[Date Of Upload] = (SELECT MAX([Date Of Upload])
			    FROM dbo.[06_BOOKINGS]
			    WHERE [Factory] = 'factory_A') 
AND
	[Factory] = 'factory_A'
		
), grouped_book AS (
	
SELECT 
	[ORDER_MONTH],
	[MTOC],
	[INVOICE],
	SUM([UNITS]) AS [UNIDADES]
FROM 
	filt_book
GROUP BY 
	[ORDER_MONTH],
	[MTOC],
	[INVOICE]

), union_book_vess AS (

SELECT 
	v.[PO],
	b.[ORDER_MONTH],
	v.[INVOICE] AS INVOICE_VESSEL,
	b.[INVOICE] AS INVOICE_BOOK,
	CASE
		WHEN v.[INVOICE] IS NOT NULL THEN v.[INVOICE]
		WHEN v.[INVOICE] IS NULL THEN b.[INVOICE]
	END AS [INVOICE],
	v.[MTOC] AS MTOC_VESSEL,
	b.[MTOC] AS MTOC_BOOK,
	CASE
		WHEN v.[MTOC] IS NOT NULL THEN v.[MTOC]
		WHEN v.[MTOC] IS NULL THEN b.[MTOC]
	END AS [MTOC],
	v.[UNITS] AS UNITS_VESSEL,
	b.[UNIDADES] AS UNITS_BOOK,
	CASE
		WHEN v.[UNITS] = b.[UNIDADES] THEN 'Iguales'
		WHEN v.[UNITS] = b.[UNIDADES] THEN 'Diferentes'
	END AS [Chivato],
	CASE 
		WHEN v.[UNITS] IS NOT NULL THEN v.[UNITS]
		WHEN v.[UNITS] IS NULL THEN b.[UNIDADES]
	END AS [UNIDADES TOTALES]
			
FROM
	agg_vess v
FULL JOIN
	grouped_book b
ON 
	v.[INVOICE] = b.[Invoice]
AND
	v.[MTOC] = b.[MTOC]

), vlookup AS (

SELECT DISTINCT
	LEFT([Invoice], LEN([Invoice]) - 2) AS PO,
	[ORDER_MONTH]
FROM dbo.[06_BOOKINGS]
WHERE 
	[Factory] = 'factory_A'
	
	
), vess_book_agg AS (

SELECT
	v.[ORDER_MONTH] AS [ORDER_MONTH_vlookup],
	u.[ORDER_MONTH],
	CASE
		WHEN v.[ORDER_MONTH] IS NULL THEN u.[ORDER_MONTH]
		WHEN u.[ORDER_MONTH] IS NULL THEN v.[ORDER_MONTH]
		WHEN v.[ORDER_MONTH] IS NOT NULL AND u.[ORDER_MONTH] IS NOT NULL THEN v.[ORDER_MONTH] 
	END AS [ORDER_MONTH_FINAL],
	u.[INVOICE_VESSEL],
	u.[INVOICE_BOOK],
	u.[INVOICE],
	u.[MTOC_VESSEL],
	u.[MTOC_BOOK],
	u.[MTOC],
	u.[UNITS_VESSEL],
	u.[UNITS_BOOK],
	u.[Chivato],
	u.[UNIDADES TOTALES]
FROM 
	union_book_vess u	
LEFT JOIN
	vlookup v
ON
	u.[PO] = v.[PO]
	
), vess_book_group AS (
	
SELECT
	[ORDER_MONTH_FINAL] AS [ORDER_MONTH],
	[MTOC],
	SUM([UNIDADES TOTALES]) AS [UNIDADES BOOKING + VESSEL]
FROM
	vess_book_agg
GROUP BY 
	[ORDER_MONTH_FINAL],
	[MTOC]
		
), colour AS (

SELECT
	[ORDER_MONTH],
	[MATERIAL],
	[MTOC],
	[UNITS]
FROM
	dbo.[06_COLOUR_FIX_VIEW]
WHERE 
	[Factory] = 'factory_A'

), col_ves_book AS (
	
SELECT
	CASE
		WHEN c.[ORDER_MONTH] IS NULL THEN v.[ORDER_MONTH]
		WHEN v.[ORDER_MONTH] IS NULL THEN c.[ORDER_MONTH]
		WHEN v.[ORDER_MONTH] IS NOT NULL AND c.[ORDER_MONTH] IS NOT NULL THEN c.[ORDER_MONTH]
	END AS [ORDER_MONTH],
	c.[MATERIAL],
	CASE
		WHEN c.[MTOC] IS NULL THEN v.[MTOC]
		WHEN v.[MTOC] IS NULL THEN c.[MTOC]
		WHEN v.[MTOC] IS NOT NULL AND c.[MTOC] IS NOT NULL THEN c.[MTOC]
	END AS [MTOC],		
	c.[UNITS] AS [Unidades colour fix],
	v.[UNIDADES BOOKING + VESSEL],
	CASE
		WHEN c.[UNITS] = v.[UNIDADES BOOKING + VESSEL] THEN 'Iguales'
		WHEN c.[UNITS] <> v.[UNIDADES BOOKING + VESSEL] THEN 'Diferentes'
	END AS [Chequeo]
FROM
	colour c
		
FULL OUTER JOIN
	vess_book_group v
ON 
	v.[ORDER_MONTH] = c.[ORDER_MONTH]
AND
	v.[MTOC] = c.[MTOC]
)
SELECT * 
FROM
	col_ves_book
