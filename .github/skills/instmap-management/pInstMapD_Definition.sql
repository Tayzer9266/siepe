

CREATE PROCEDURE [dbo].[pInstMapD]

	@IDs varchar(8000)

AS

BEGIN



	SET NOCOUNT ON ;

	SET TRANSACTION ISOLATION LEVEL READ COMMITTED ;



	DECLARE @tab_IDs TABLE (id int NOT NULL) ;



	-- Split the input records ...

	INSERT INTO @tab_IDs (id)

		SELECT DISTINCT row

		FROM dbo.fnCOMSplitTableT(@IDs, ',')

		WHERE LEN(row) > 0 ;



	-- Delete any active records specified ...

	UPDATE dbo.tInstMap

	SET RefRecStatusID = 2 , EffThruDate = GETDATE()

	WHERE

		PKID IN (SELECT id FROM @tab_IDs)

		AND

		RefRecStatusID = 1



END



