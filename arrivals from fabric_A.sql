CREATE VIEW Arrivals AS 

WITH Colour AS(

SELECT 
	[ORDER_MONTH],
	[MATERIAL],
	[MTOC],
	[ETA],
	[UNITs],
	[FACTORY]
FROM 
	dbo.[06_COLOUR_FIX_VIEW]
WHERE
	[Factory] = 'factory_A'
		
), CTE_book AS(

   SELECT
	[ORDER_MONTH],    	
	[Invoice],
	[MTOC], 
	[Units],
	[Date of Upload],
	[ETA]
   FROM 
	dbo.[06_BOOKINGS]
   WHERE 
	[Factory] = 'factory_A'
   AND
	[Date of Upload] = (SELECT MAX([Date of Upload])
			    FROM dbo.[06_BOOKINGS]
			    WHERE [Factory] = 'factory_A')  
        
), book AS(

SELECT 
	[ORDER_MONTH],
	[Invoice],
   	[MTOC],
	[ETA],
   	SUM([Units]) AS [Unidades booking]
FROM 
	CTE_book
GROUP BY 
	[ORDER_MONTH],
	[Invoice],
	[MTOC],
	[ETA]

), vess AS(

SELECT 
	[INVOICE],
	[MTOC],
	[UNITS],
	[DATE-PLANNED],
	[CONTAINER],
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
	[DATE-PLANNED],
	[CONTAINER],
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
	[DATE-PLANNED],
	[CONTAINER],
	SUM([UNITS]) AS UNITS
FROM
	acc_vess
GROUP BY 
	LEFT([INVOICE], LEN([INVOICE]) - 2),
	[INVOICE],
	[MTOC],
	[DATE-PLANNED],
	[CONTAINER]
), vlookup AS (

SELECT DISTINCT
	LEFT([Invoice], LEN([Invoice]) - 2) AS PO,
	[ORDER_MONTH]
FROM 
	dbo.[06_BOOKINGS]
WHERE
	[Factory] = 'factory_A'
	
), vess_vlookup AS (

SELECT 
	v.[ORDER_MONTH],
	a.[INVOICE],
	a.[MTOC],
	a.[DATE-PLANNED],
	a.[UNITS],
	a.[CONTAINER]
	
FROM 
	agg_vess a

LEFT JOIN 
	vlookup v
	
ON 	
	a.[PO] = v.[PO]
	
), vessel_book AS (

SELECT 
	b.[ORDER_MONTH] AS ORDER_MONTH_BOOKING,
	v.[ORDER_MONTH] AS ORDER_MONTH_VESSEL,
	CASE
		WHEN v.[ORDER_MONTH] IS NOT NULL THEN v.[ORDER_MONTH]
		WHEN v.[ORDER_MONTH] IS NULL THEN b.[ORDER_MONTH]
	END AS [ORDER_MONTH],
	b.[Invoice] AS INVOICE_BOOKING,
	v.[INVOICE] AS INVOICE_VESSEL,
	CASE
		WHEN v.[INVOICE] IS NOT NULL THEN v.[INVOICE]
		WHEN v.[INVOICE] IS NULL THEN b.[Invoice]
	END AS [INVOICE],
	b.[MTOC] AS MTOC_BOOKING,
	v.[MTOC] AS MTOC_VESSEL,
	CASE
		WHEN v.[MTOC] IS NOT NULL THEN v.[MTOC]
		WHEN v.[MTOC] IS NULL THEN b.[MTOC]
	END AS [MTOC],
	b.[Unidades booking],
	v.[UNITS] AS [Unidades vessel],
	CASE
		WHEN v.[UNITS] IS NOT NULL THEN v.[UNITS]
		WHEN v.[UNITS] IS NULL THEN b.[Unidades booking]
	END AS [Unidades],
	b.[ETA] AS [ETA Booking],
	v.[DATE-PLANNED] AS [DATE-PLANNED VESSEL],
	CASE
		WHEN v.[DATE-PLANNED] IS NOT NULL THEN v.[DATE-PLANNED]
		WHEN v.[DATE-PLANNED] IS NULL THEN b.[ETA]
	END AS [Fecha estimada],
	v.[CONTAINER]
	
FROM
	book b

FULL JOIN
	vess_vlookup v
	
ON
	b.[MTOC] = v.[MTOC]
AND
	b.[Invoice] = v.[INVOICE]
		
), cont AS(

SELECT 
	[INVOICE],
	[CONTAINER],
	[ARRIVAL_DATE],
	[DATE_OF_UPLOAD],
	MAX([DATE_OF_UPLOAD]) OVER (PARTITION BY [INVOICE], [CONTAINER]) AS MAX_DATE
FROM
	dbo.[06_CONTAINER_PLANNING]

), acc_cont AS(

SELECT
	[INVOICE],
	[CONTAINER],
	[ARRIVAL_DATE],
	[DATE_OF_UPLOAD]
FROM
	cont
WHERE
	[DATE_OF_UPLOAD] = MAX_DATE
), col_book_vess AS (

SELECT
	c.[ORDER_MONTH],
	c.[MATERIAL],
	c.[MTOC],
	v.[INVOICE],
	v.[CONTAINER],
	c.[UNITs],
	v.[Unidades booking],
	v.[Unidades vessel],
	CASE
		WHEN v.[Unidades] IS NOT NULL THEN v.[Unidades]
		WHEN v.[Unidades] IS NULL THEN c.[UNITs]
	END AS [Unidades],
	c.[ETA] AS [ETA Colour],
	v.[ETA Booking],
	v.[DATE-PLANNED VESSEL] AS [ETA Vessel],
	p.[ARRIVAL_DATE],
	CASE
		WHEN p.[ARRIVAL_DATE] IS NOT NULL THEN p.[ARRIVAL_DATE]
		WHEN p.[ARRIVAL_DATE] IS NULL AND v.[DATE-PLANNED VESSEL] IS NOT NULL THEN v.[DATE-PLANNED VESSEL]
		WHEN p.[ARRIVAL_DATE] IS NULL AND v.[DATE-PLANNED VESSEL] IS NULL AND v.[ETA Booking] <> '1900-01-01' THEN v.[ETA Booking]
		WHEN p.[ARRIVAL_DATE] IS NULL AND v.[DATE-PLANNED VESSEL] IS NULL AND (v.[ETA Booking] IS NULL OR v.[ETA booking] = '1900-01-01') THEN c.[ETA]
	END AS [Fecha de llegada],
	c.[FACTORY]
	
	FROM
		vessel_book v
		
	RIGHT JOIN
		Colour c
	ON 
		v.[ORDER_MONTH] = c.[ORDER_MONTH]
	AND
		v.[MTOC] = c.[MTOC]
		
	LEFT JOIN
		acc_cont p
	ON
		v.[INVOICE] = p.[INVOICE]
	AND
		v.[CONTAINER] = p.[CONTAINER]

)

SELECT 
   *,
   DATEPART(WEEK, [Fecha de llegada]) - DATEPART(WEEK, DATEADD(MONTH, DATEDIFF(MONTH, 0, [Fecha de llegada]), 0)) + 1 AS SemanaDelMes
 
FROM col_book_vess
