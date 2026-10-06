USE [SIGAJUNTEST]; -- O la base donde estés trabajando
GO

SELECT 
    dp.name AS UsuarioHuerfano_EnBaseDeDatos,
    dp.type_desc AS TipoDeUsuario,
    -- Generamos el script de reparación automático
    'ALTER USER [' + dp.name + '] WITH LOGIN = [' + dp.name + '];' AS ScriptParaReparar
FROM sys.database_principals dp
LEFT JOIN master.sys.server_principals sp 
    ON dp.sid = sp.sid
WHERE dp.type IN ('S', 'U', 'G') -- 'S' = SQL, 'U'/'G' = Windows
  AND dp.principal_id > 4 -- Excluimos usuarios internos del sistema (dbo, guest, etc.)
  AND sp.sid IS NULL; -- La condición clave: no existe ese SID en el servidor
