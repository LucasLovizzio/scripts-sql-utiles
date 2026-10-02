DECLARE @FilePath NVARCHAR(2000) = N'<PATH_CAMBIAR_ESTO>';  -- CAMBIAR
DECLARE @SQL NVARCHAR(MAX);
DECLARE @ParamCount INT;
DECLARE @Defaults NVARCHAR(MAX) = N'';
DECLARE @i INT = 6; -- Los primeros 5 parámetros los pasamos a mano

-- 1. Buscamos cuántos parámetros exige tu versión exacta de SQL Server
SELECT @ParamCount = COUNT(*) 
FROM sys.all_parameters 
WHERE object_id = OBJECT_ID('sys.fn_dump_dblog');

-- (Fallback por si el usuario no tiene permisos para leer sys.all_parameters)
IF @ParamCount IS NULL OR @ParamCount = 0
    SET @ParamCount = 89; 

-- 2. Rellenamos dinámicamente con la cantidad exacta de ", DEFAULT" que falten
WHILE @i <= @ParamCount
BEGIN
    SET @Defaults = @Defaults + N', DEFAULT';
    SET @i = @i + 1;
END

-- 3. Armamos la consulta cruzando los datos del log
SET @SQL = N'
WITH LogCompleto AS (
    SELECT 
        [Transaction ID],
        [Operation],
        [Transaction Name],
        [Transaction SID],
        [AllocUnitName],
        [Log Record Length]
    FROM sys.fn_dump_dblog (
        NULL, NULL, N''DISK'', 1, N''' + @FilePath + '''' + @Defaults + N'
    )
),
TransaccionesInicio AS (
    SELECT 
        [Transaction ID],
        SUSER_SNAME([Transaction SID]) AS Usuario,
        [Transaction Name]
    FROM LogCompleto
    WHERE [Operation] = ''LOP_BEGIN_XACT''
)
SELECT TOP 20
    t.Usuario,
    t.[Transaction Name] AS Proceso,
    l.[AllocUnitName] AS Esquema_Tabla_Indice,
    COUNT(1) AS Cantidad_De_Filas_Afectadas,
    SUM(CAST(l.[Log Record Length] AS BIGINT)) / 1024 / 1024 AS MB_Escritos
FROM LogCompleto l
INNER JOIN TransaccionesInicio t ON l.[Transaction ID] = t.[Transaction ID]
WHERE l.[Operation] IN (
    ''LOP_INSERT_ROWS'', 
    ''LOP_DELETE_ROWS'', 
    ''LOP_MODIFY_ROW'', 
    ''LOP_FORMAT_PAGE''
)
  AND l.[AllocUnitName] IS NOT NULL
GROUP BY 
    t.Usuario, 
    t.[Transaction Name], 
    l.[AllocUnitName]
ORDER BY 
    MB_Escritos DESC;
';

-- 4. Ejecutamos el análisis
EXEC sp_executesql @SQL;