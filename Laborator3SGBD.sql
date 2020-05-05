/*
Validare 
-din tabelul Sponsori validam valoarea , aceasta trebuie sa fie mai mare decat 0
-din tabelul Showroom validam detaliile, valorile pe care le poate lua sunt : nedetaliat sau fara_detalii
-din tabelul Distributie validam descrierea, valorile acesteia putand fi proiectare, proiectare3D
*/

create function uf_Sponsori(@valoare int) returns int as
begin
declare @return int
set @return = 0
if (@valoare > 0)
set @return=1
return @return
end

create function uf_Showroom(@detalii varchar(300)) returns int as
begin
declare @return int
set @return = 0
IF(@detalii in ('nedetaliat','fara_detalii'))
set @return = 1
return @return 
end

create function uf_Distributie(@descriere varchar(300)) returns int as
begin
declare @return int
set @return = 0
if(@descriere in ('proiectare','proiectare3D'))
set @return = 1
return @return
end

/*
LogTable
*/
CREATE TABLE LogTable1(
Lid INT IDENTITY PRIMARY KEY,
TypeOperation VARCHAR(50),
TableOperation VARCHAR(50),
ExecutionDate DATETIME)

/*
Creaţi o procedură stocată ce inserează date pentru entităţi ce se află într-o relaţie m-n.
Dacă o operaţie de inserare eşuează, trebuie făcut roll-back pe întreaga procedură
stocată.
Tabel de legtura: Distributie
-procedura nu ia id-urile ca parametrii
-se valideaza datele , folosindu-ne de raiserror in cazul in care nu respecta cerintele
-se insereaza datele in tabelul de logare si celelalte
-folosim try/catch
-la final se face roolbackul
*/
alter procedure AddSponsoriShowroomFULL_ROLLBACK @nume varchar(300), @valoare int,@eveniment varchar(300), @detalii varchar(300),@descriere varchar(300) as
begin
declare @cod_sponsor int 
declare @cod_eveniment int
BEGIN TRAN
BEGIN TRY
IF(dbo.uf_Sponsori(@valoare)<>1)
BEGIN
RAISERROR('The value must be greater than 0',14,1)
END
IF(dbo.uf_Showroom(@detalii)<>1)
BEGIN
RAISERROR('The details must be nedetaliat,fara_detalii',14,1)
END

IF(dbo.uf_Distributie(@descriere)<>1)
BEGIN
RAISERROR('The description must be proiectare,proiectare3D',14,1)
END
INSERT INTO Sponsori(nume,valoare) VALUES (@nume, @valoare)
SET @cod_sponsor=(SELECT SCOPE_IDENTITY())
INSERT LogTable1(TypeOperation,TableOperation,ExecutionDate) VALUES ('INSERT','Sponsori',GETDATE())

INSERT INTO Showroom(eveniment,detalii) VALUES (@eveniment,@detalii)
SET @cod_eveniment=(SELECT SCOPE_IDENTITY())
INSERT LogTable1(TypeOperation,TableOperation,ExecutionDate) VALUES ('INSERT','Showroom',GETDATE())

INSERT INTO Distributie(cod_sponsor,cod_eveniment,descriere) VALUES (@cod_sponsor,@cod_eveniment,@descriere)
INSERT LogTable1(TypeOperation,TableOperation,ExecutionDate) VALUES ('INSERT','Distributie',GETDATE())
COMMIT TRAN
SELECT 'Transaction committed'
END TRY
BEGIN CATCH
ROLLBACK TRAN
SELECT 'Transaction rollbacked'
SELECT 
   ERROR_NUMBER() as ErrorNumber,
   ERROR_MESSAGE() as ErrorMessage
END CATCH
end

/*
cazuri de testare:
Commit

DELETE FROM LogTable1
SELECT * FROM LogTable1
EXEC AddSponsoriShowroomFULL_ROLLBACK 'Bianca',5,'prezentare','fara_detalii','proiectare'
SELECT * FROM LogTable1

Rollback

Motiv: descrierea nu e in cele 2 categorii 

DELETE FROM LogTable1
SELECT * FROM LogTable1
EXEC AddSponsoriShowroomFULL_ROLLBACK 'Bianca',5,'prezentare','fara_detalii','jwsa'
SELECT * FROM LogTable1
*/

/*
Creaţi o procedură stocată ce inserează date pentru entităţi ce se află într-o relaţie m-n.
Dacă o operaţie de inserare eşuează va trebui să se păstreze cât mai mult posibil din ceea
ce s-a modificat până în acel moment. De exemplu, dacă se încearcă inserarea unei cărţi
şi a autorilor acesteia, iar autorii au fost inseraţi cu succes însă apare o problemă la
inserarea cărţii, atunci să se facă roll-back la inserarea de carte însă autorii acesteia să
rămână în baza de date.
*/

CREATE PROCEDURE AddSponsoriShowroomPARTIAL_ROLLBACK @nume varchar(300), @valoare int,@eveniment varchar(300), @detalii varchar(300),@descriere varchar(300) as
BEGIN
declare @cod_sponsor int = -1
declare @cod_eveniment int =-1

IF(dbo.uf_Sponsori(@valoare)=1)
BEGIN
	BEGIN TRAN
	INSERT INTO Sponsori(nume,valoare) VALUES (@nume,@valoare)
	SET @cod_sponsor=(SELECT SCOPE_IDENTITY())
	INSERT LogTable1(TypeOperation,TableOperation,ExecutionDate) VALUES ('INSERT','Sponsori',GETDATE())
	COMMIT TRAN
END
IF(dbo.uf_Showroom(@detalii)=1)
BEGIN 
	BEGIN TRAN
	INSERT INTO Showroom(eveniment,detalii) VALUES (@eveniment, @detalii)
	SET @cod_eveniment=(SELECT SCOPE_IDENTITY())
	INSERT LogTable1(TypeOperation,TableOperation,ExecutionDate) VALUES ('INSERT','Showroom',GETDATE())
	COMMIT TRAN
END
IF(dbo.uf_Distributie(@descriere)=1 AND @cod_sponsor<>-1 AND @cod_eveniment<>-1)
BEGIN 
	BEGIN TRAN
	INSERT INTO Distributie(cod_sponsor,cod_eveniment,descriere) VALUES (@cod_sponsor,@cod_eveniment,@descriere)
	INSERT LogTable1(TypeOperation,TableOperation,ExecutionDate) VALUES ('INSERT','Distributie',GETDATE())
	COMMIT TRAN
END
END
/*
cazuri de testare:
Commit

DELETE FROM LogTable1
SELECT * FROM LogTable1
EXEC AddSponsoriShowroomPARTIAL_ROLLBACK 'Lavinia',4,'aaa','nedetaliat','proiectare3D'
SELECT * FROM LogTable1

Rollback
Motiv: descrierea nu e in cele 2 categorii 

DELETE FROM LogTable1
SELECT * FROM LogTable1
EXEC AddSponsoriShowroomPARTIAL_ROLLBACK 'Lavinia',4,'aaa','nedetaliat','ok'
SELECT * FROM LogTable1
*/