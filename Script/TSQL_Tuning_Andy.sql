-- #######################

-- ####################### [Northwind] #######################

-- #######################

USE [Northwind]
GO					-- ALT + X && Markierung

-- Spalten, die mit den Datentypen CHAR, VARCHAR, BINARY und VARBINARY definiert sind, 
-- verfügen über eine definierte Größe (es werden Leerzeichen stets NICHT abgeschnitten).
SET ANSI_PADDING ON 
GO

-- ### Spaß mit CHARACTER = "Bergmann-Problem" ;; TEASER

			[Nachname]
CHAR(10)	'Krause....'	+ TRIM() + LEN() + RIGHT() + LEFT()
VARCHAR(10)	'Krause'

UPDATE [Nachname]

CHAR(10)	'Bergmann..'				; 10 Byte ASCII
VARCHAR(10)	'Bergma'	+ EXTENT_1		; 06 Byte ASCII
...
..
.
EXTENT_1	'nn'	;  1 Speicherseite = 8kB  ==  1 Speicherblock = 64 kB

NCHAR(10)	N'Krause....'				; 10 Byte Content + 10 Byte UTF-8

-- >> siehe dazu später : SPEICHERSEITEN !!

-- ######################################################

-- ########### Abfrage als variable Procedure ###########

-- ######################################################

-- ##### Auswahl der Tabellen für spätere Abfragen

-- Customers	[customerid | CompanyName | ContactName | ContactTitle | City | Country ]
-- Orders		[ EmployeeID | OrderDate | freight | shipcity | shipcountry ]
-- OrderDetails	[ prodid | orderid | unitprice | Quantity ]
-- Products		[ ProductName ]
-- Employees	[ LastName | FirstName | BirthDate | city | country ]

-- ######################################################

-- ##### Grund-Tabelle

SELECT  cust.CustomerID
		, cust.CompanyName
		, cust.ContactName
		, cust.ContactTitle
		, cust.City
		, cust.Country
		, ord.EmployeeID
		, ord.OrderDate
		, ord.freight
		, ord.shipcity
		, ord.shipcountry
		, ods.OrderID
		, ods.ProductID
		, ods.UnitPrice
		, ods.Quantity
		, prod.ProductName
		, emp.LastName
		, emp.FirstName
		, emp.birthdate
-- into dbo.KundeUmsatz
FROM	Customers AS cust
		INNER JOIN Orders AS ord ON cust.CustomerID = ord.CustomerID
		INNER JOIN Employees AS emp ON ord.EmployeeID = emp.EmployeeID
		INNER JOIN [Order Details] AS ods ON ord.orderid = ods.orderid
		INNER JOIN Products AS prod ON ods.productid = prod.productid

	' Neu-Erstellte Dinge müssen dem SSMS erst "bekanntgemacht" werden:
		>> ReFresh Object Explorer
		>> ReFresh Meta Data Infos = CRTL + SHIFT + R '

-- Multiplikation für großen Datenbestand
-- solange bis ~ 1.100.000 erreicht sind > ~ 400 MB Größe

insert into dbo.KundeUmsatz
select * from dbo.KundeUmsatz
GO 9								-- 9 Wiederholungen

select COUNT(*) from dbo.KundeUmsatz -- * versus COUNT(*)

	-- ## 0 : TSQL-$ sind eine RELATIVE Aussage über AUFWAND 
	-- > sie sagen NICHTS darüber aus, WIE LANGE ich auf Daten WARTE

SELECT @@VERSION	-- die HARDWARE der SQL SVR entscheidet den Ablauf !!

-- ### Aufgabenstellung #################################
-- ### Erstelle eine Prozedur, die folgendes erledigt ###

	exec uspKDSuche 'ALFKI'							-- alle finden die custID = 'ALFKI'
	exec uspKDSuche 'A'								-- alle mit A beginnend
	exec uspKDSuche NULL oder exec uspKDSuche '%'	-- alle Kunden ausgeben

-- Prozeduren

GO
CREATE PROCEDURE [uspKDSuche] @kid NCHAR(5) 
AS
SELECT * FROM dbo.KundeUmsatz
WHERE CustomerID LIKE @kid + '%'


exec uspKDSuche 'ALFKI'		-- funzt
exec uspKDSuche 'A%'		-- funzt nicht, WEIL zu kurz = Länge 2
exec uspKDSuche				-- funzt nicht, da kein Parameter übergeben

-- ###########################################################################################
-- ### Erkenntnis #1 : Nehme NIEMALS eine Variable so her wie in der Datenbank-Definition ####
-- ###########################################################################################

-- char(5) hat 5 Zeichen --> 'A%   ' als 'A%xxx' mit x als LEERZEICHEN > MUSS 5 Zeichen haben 
-- Variablen müssen nicht den gleichen Datentyp haben --> lieber "größeren" Typ wählen
-- Sie laufen sogar besser, wenn man NICHT den gleichen Datentyp wählt, da weniger Einschänkung

-- ###########################################################################################
-- ###########################################################################################
-- ###########################################################################################

ALTER PROCEDURE [uspKDSuche] @kid VARCHAR(6) = '%'		-- DEFAULT CONSTRAINT für PROCEDURE, um NULL abzufangen
AS
SELECT * FROM dbo.KundeUmsatz
WHERE CustomerID LIKE @kid + '%'

-- Test

exec uspKDSuche 'A' 
exec uspKDSuche 'ALFKI' 
exec uspKDSuche			

	' 2 Fragen offen > Wie filtere ich effektiv und wie optimiere ich auf 100 DS versus 100.000 DS? '

-- ### Aufgabenstellung #################################
-- ### Suche alle Angestellten im Rentenalter (65) ######

SELECT * FROM dbo.Employees WHERE YEAR(BirthDate) <= 1956 
SELECT * FROM dbo.Employees WHERE DATEDIFF ( YEAR,  birthDate, GETDATE() ) >= 65
SELECT * FROM dbo.Employees WHERE birthDate >= DATEDIFF ( YEAR , -65 , GETDATE() )

SELECT DATEDIFF ( YEAR,  birthDate, GETDATE() ) FROM dbo.Employees
	
	' ISO-DATE : "yyyymmdd"							20211102
				 "yyyymmddThh:mm:ss.1234567+TZ"		2021/11/02T11:52:42.1234567+01:00 '

	' alle 3 sind "gleich gut" , weil es keinen INDEX gibt, der z.B. die Mitarbeiter aufsteigend sortiert abspeichert 
		--> hier hilft "nur noch" der INDEX, weil die Abfrage selbst es nicht mehr "besser" machen kann					'

-- ######################################################

-- #### Verbesserter logischer Fluss in den Abfragen ####

-- ######################################################

-- ### Grundsätzliches in Bezug auf Ablaufpläne

/*
    FROM  (TABELLE t1) 
--> JOIN (TABELLE t2)	--> WHERE (sieht SQl schon T1 und T2)
--> GROUP BY			--> (Vor-) Gruppierung für spätere Aggregationen
--> HAVING				--> kann nicht wissen wie die Spalten im SELECT heißen
--> SELECT				--> keine Ausgabe, sondern Spalten-Alias sowie Berechnungen und FUNCTION()
--> ORDER BY			--> wird immer auf das Ergebnis angewendet)
--> LIMITER				--> TOP | DISTINCT | ...
--> RESULT SET			--> Ausgabe des DATA SETs (also ausgewertete Rohdaten)

*/ 

-- SELECT-Ablaufplan nicht vergessen!
SELECT 	cust.CustomerID AS KDNR
		, cust.CompanyName AS Firma
		, ord.orderid
		, ord.orderdate
FROM  customers AS cust 
	  inner join orders AS ord ON cust.customerid = ord.customerid
WHERE CompanyName LIKE 'A%' -- Firma hier geht nicht als Filter-Eigenschaft
ORDER BY Firma		-- Im Ablaufplan ist erst HIER der ALIAS bekannt

-- ORDER BY bei Aggregationen
SELECT 
		cust.CompanyName AS Firma
		, sum(ord.Freight) AS Frachtmenge
FROM
	  Customers AS cust 
	  inner join Orders AS ord on cust.CustomerID = ord.CustomerID
WHERE 
	CompanyName LIKE 'A%' 
GROUP BY CompanyName	-- auch hier kein ALIAS
ORDER BY Firma -- hier würde es gehen > dennoch schlechter Stil!

-- HAVING-Filterung bei GROUP BY / Aggregation
SELECT 
		companyname as Firma
		, sum(freight) AS Frachtmenge
FROM 
	  customers AS cust
	  inner join orders AS ord on cust.CustomerID = ord.CustomerID
WHERE 
	companyname like 'A%' 
GROUP BY companyname	  -- HAVING benötigt GroupBy-Ebenen für die gruppierte Aggregation
HAVING sum(freight) > 200 
ORDER BY companyname 

-- Unterschied GROUP BY vs. HAVING
select country, companyname , count(*) from customers  -- 1 MIO Datensätze
where country = 'UK' 
group by country, companyname 
order by companyname

select country, companyname , count(*) from customers  -- 1 MIO Datensätze
-- where country = 'UK' 
		-- hätte auf 10000 gefiltert, statt komplett alle durchzugehen
		-- bei Verwendung von WHERE hätte der SQL nicht 1 Mio Datensätze gruppieren müssen
		-- der INDEX verhindert diesen Unsinn und sorgt für IDENTISCHEN Ablaufplan 
group by country, companyname having country='UK' 
order by companyname

-- ### LEFT-JOIN versus IN-Variante >> Vergleich der Ablaufpläne	######################

SELECT DISTINCT
		co.companyname
FROM	dbo.Customers AS co
		LEFT JOIN dbo.Orders AS od ON co.CustomerID = od.CustomerID
ORDER BY co.companyname


SELECT DISTINCT
		co.companyname
FROM	dbo.Customers AS co
		INNER JOIN dbo.Orders AS od ON co.CustomerID = od.CustomerID
ORDER BY co.companyname

-- IN-Variante
SELECT	DISTINCT
		co.companyname
FROM	dbo.Customers AS co
WHERE	CustomerID NOT IN
		( SELECT DISTINCT 
				SQ1.CustomerID
		  FROM dbo.Orders AS SQ1)
GROUP BY co.companyname

-- LEFT OUTER JOIN
SELECT DISTINCT
		co.companyname
FROM	dbo.Customers AS co
		LEFT OUTER JOIN dbo.Orders AS od ON co.CustomerID = od.CustomerID
WHERE	od.CustomerID is null
ORDER BY co.companyname

-- ###########################################################################################
-- ### Erkenntnis #2 : Schreibe NIE etwas in ein HAVING, was ein WHERE gut leisten könnte ####
-- ###########################################################################################

-- HAVING ist >NUR< für Aggregation des GROUP BY da, um Filterung auf Aggregierung anzuwenden
-- logischer Fluss wird bei einfachen Statements berücksichtigt > automatische Korrektur aktiv
-- SQL Server Korrektur bei komplexen Statements nicht mehr möglich > unnötiger Rechenaufwand

-- ###########################################################################################
-- ### Erkenntnis #2 : IN und LEFT JOIN sind zwei Wege zum Ziel, mit Vor- & Nachteilen #######
-- ###########################################################################################

-- WHERE NOT IN gegen DISTINCT SELECT ist <IM REGELFALL> schneller als LEFT OUTER JOIN
-- FULL LEFT JOIN ist <HÄUFIG> schneller als INNER JOIN; knappe Entscheidung bei vielen Daten
-- FULL LEFT JOIN ist <IMMER> schneller als WHERE IN gegen DISTINCT SELECT, da keine Filterung

-- ###########################################################################################
-- ###########################################################################################
-- ###########################################################################################

-- ##### Mess-Techniken und deren Grundlagen ############

-- ######################################################

	Plan erklärt mir nur, WO der SQL die Daten holt, WIE er das macht und WAS er damit tut
	JEDER Plan stellt einen AnwendungsBatch dar = 100% anteilig verteilt zum Verbrauch
	geschätzter / tatsächlicher / Echtzeit- Plan 
	'RELATIVER' Aufwand in RessourcenEinheiten bzgl. FLOP (I/O) TIME (CPU)

	-> 'NICHT BEKANNT' : WAIT-Time, RAM-Verbauch, keine ABSOLUT vergleichbaren Werte 

-- ######################################################

select * from orders where freight < 1				-- 50%  024 E  0.018 $  22 READ  000 CPU   372 TIME
select * from orders where freight > 100			-- 50%  187 E  0.018 $  22 READ  000 CPU   392 TIME

	' dbo.Orders > Indexes > Rechtsklick > Non Clustered Index [freight ASC] INCL [Rest] '

select * from orders where freight < 1				-- 34%  024E  0.003 $   02 READ  000 CPU   250 TIME
select * from orders where freight > 100			-- 66%  187E  0.006 $   07       000       390 

select * from orders where freight < 1				-- 49%  024E  0.003 $	02		 000	   256
select TOP 10 * from orders where freight > 100		-- 51%  010E  0.003 $   02       000       200

	' schmeiße den neuen INDEX weg '

select * from orders where freight < 1				-- 82%  024E  0.018$    22		 000	   250
select TOP 10 * from orders where freight > 100		-- 18%  010E  0.004$	04		 000	   250

	' verweise bewusst auf einen schon existierenden INDEX '

select * from orders 
		WITH (INDEX = OrderDate) where freight < 1	-- 75%  024E  0.202$	1724	000			260
select TOP 10 * from orders 
		WITH (INDEX = OrderDate) where freight > 100-- 25%  010E  0.067$	126		000			200

-- ###########################################################################################
-- #### Erkenntnis #3 : Ablauf-Pläne und Ausloben von Indizes gehen optimal Hand in Hand #####
-- ###########################################################################################

-- Verschiedene TSQL-Statements stets über (erwartete) Ablaufpläne vergleichen
-- Index SEEK stets besser als Index SCAN --> Erstellen neuer Indizes KANN eine Verbesserung sein
-- LIMITER besonders effektiv beim Index, was die individuellen Kosten im Regelfall reduziert

-- ###########################################################################################
-- ###########################################################################################
-- ###########################################################################################

-- ### Der Batch-Delimiter 'GO' als Verhinderer von Stolpersteinen

-- ######################################################

-- GO ist kein TSQL-Befehl, sondern eine Anweisung für den Editor

create proc gpdemo1 
as
select getdate()
		--> Rekursion und damit 0 + 31 Selbstaufrufe
exec gpdemo1

-----------------------------------------------------------------

ALTER proc gpdemo1	--> wird bei SQL SVR 2016 und früher tendentiell nicht funktionieren
as					--> dann: DROP PROC && CREATE PROC
select getdate()
GO		--> Mache hier nur dann weiter, WENN davor erfolgreich
exec gpdemo1

-- ######################################################

-- Variablen-Verhalten innerhalb eines Batch-Aufrufes

-- ######################################################

declare @var1 as int = 1
select @var1

select @var1	--> 2x der Wert der Variable zur Laufzeit bekannt

-----------------------------------------------------------------

declare @var1 as int = 1
select @var1
GO					--> neues "Blatt"
select @var1	--> ERROR, da Variable WEG 

-- ###########################################################################################
-- #### Erkenntnis #4 : Batch-Delimiter 'GO' essentiell für Fehler-freie TSQL-Ausführung #####
-- ###########################################################################################

-- Alles, was markiert ist, wird als EIN Batch verstanden und im Ganzen ausgeführt
-- GO unterteilt den Batch in SubBatch-Aufrufe, die einzeln (Ergebnis, Message,...) ablaufen
-- Besonders bei allen funktionsartigen Aufrufen ist das ESSENTIELL, um Fehler zu vermeiden
-- Variable gilt nur während EINES Batches, also ohne GO da und mit GO weg!

-- ###########################################################################################
-- ###########################################################################################
-- ###########################################################################################

-- ##### Fazit :: Ausführungspläne

-- ######################################################
/*

	erklärt nur, wo SQL die Daten holt, wie er sie holt und was er damit macht
	> jeder Plan stellt einen Batch dar, der 100% Leistung verbraucht
	> die 100% Leistung werden auf die automaren Aktionen verteilt

	ein Plan kann lügen --> Unterschied zwischen geschätztem und tatsächlichem Plan
	> vor allem bei FUNCTION(), denn die werden in tats. Plänen oft nicht mehr angezeigt!
	> ein Plan kann durchaus mal sagen, dass Batch^1 günstiger wäre als Batch^2 (Heuristik!)
	> die Messung kann das Gegenteil zeigen, also dass Batch^1 günstiger als Batch^2 ist
*/

-- ######################################################

-- ##### Messen und Logischer Fluss in den Abfragen #####

-- ######################################################

-- Statistik über das Messen der I/O-Zugriffe und der Zeiten --> nur Aussage über das WIE
-- anhand von Zeiten kann man NICHT sagen, ob er die Daten gut oder schlecht verarbeitet hat
-- Es ist Aufgabe des PLANs, um das WO und WAS zu bewerten also ob Ablauf gut oder schlecht ist

-- ######################################################

-- ### statistische Abfrage zu I/O einschalten

set statistics io, time on -- ZENTRALES Einschalten der Messung

select * from orders where freight < 10

-----------------------------------------------------------------

	logical reads 22, CPU time = 0 ms,  elapsed time = 349 ms.

	' siehe Excel-Mappe > STORAGE '

-- ######################################################

-- ### Speicherverhalten :: Seiten / Blöcke / RAM-Belastung

-- ######################################################

/*
	SQL Server speichert Datensätze in Seiten
	eine Seite hat 8 kiloByte = 8192 Byte  ::  Theoretischer Speicher
							  -  132 Byte  ::  Overhead für jew. Seite
							-------------------------------------------
					NENNGRöße   8060 Byte  ::  Check beim Anlegen der Daten
							  -    7 Byte  ::  Overhead pro Datensatz
							-------------------------------------------
					MAXIMAL	    8053 Byte  ::  Nutzlast  für Datensätze
*/

create table t1 (id int identity, SpalteX char(4100), SpalteY char(4100)) 
	--				11							4100				4100	= 8211 > 8060 - 7			
	' Grundsätzlich muss ein Datensatz in eine Seite passen! '

-- Type-Definitionen
/*
	REFERENZ :: https://msdn.microsoft.com/de-de/library/ms187752(v=sql.120).aspx 
*/

create table t1 (id int identity, SpalteX varchar(4100), SpalteY char(4100)) 
	' Tabelle wird NICHT abgelehnt, aber irgendwann ein Datensatz maximal möglicher Länge! '

-- ######################################################

-- ##### Hinzufügen neuer Datensätze #####

-- ######################################################

drop table if exists dbo.person
go

create table dbo.person (personID int identity, fName nvarchar(50), lName nvarchar(50))
go

-- Insert  mit Skalarwerten

set statistics io, time off		-- Messung würde Ergebnis verfälschen
set nocount off					-- Interne Zählung von betroffenen Zeilen
go	

-- Single-Line-Insert
declare @starttime datetime2(7)
declare @RunningTime int
set @starttime = sysdatetime()
insert into dbo.person (fName, lName)
	values ('Apu', 'Nahasapeemapetilon')
insert into dbo.person (fName, lName)
	values ('Majula', 'Nahasapeemapetilon')
insert into dbo.person (fName, lName)
	values ('Sanjay', 'Nahasapeemapetilon')
set @RunningTime = DATEDIFF(ms, @starttime, sysdatetime())
print 'Ausführungszeit mehrerer Einzelinserts: ' + cast(@runningtime as nvarchar(5))

-- Multi-Line-Insert
set @starttime = sysdatetime()
insert into dbo.person (fName, lName)
	values ('Homer', 'Simpson'), ('Marge', 'Simpson'), ('Bart', 'Simpson'), ('Lisa', 'Simpson'), ('Maggie', 'Simpson')
set @RunningTime = DATEDIFF(ms, @starttime, sysdatetime())
print 'Ausführungszeit Multi-Insert: ' + cast(@runningtime as nvarchar(5))
go

-- INSERT INTO (Anhängen von Zeilen an bestehende Tabelle)

declare @starttime datetime2(7)
declare @RunningTime int
set @starttime = sysdatetime()
insert into dbo.person (fName, lName)
	select firstname, lastname from [AdventureWorksDW2014].dbo.DimEmployee as emp		-- Sub-Query als Derived Table Expression
set @RunningTime = DATEDIFF(ms, @starttime, sysdatetime())
print 'Ausführungszeit Insert-Select: ' + cast(@runningtime as nvarchar(5))
go

select COUNT(*) FROM [AdventureWorksDW2014].dbo.DimEmployee

-- SELECT INTO (Erzeugen einer neuen Tabelle, bereits befüllt mit Daten)

drop table if exists dbo.[Order Details Revised]
go

select COUNT(*) from AdventureWorksDW2014.dbo.FactInternetSales

declare @starttime datetime2(7)
declare @RunningTime int
set @starttime = sysdatetime()
select
	*
	into dbo.[Order Details Revised]			-- TempTabObj / #Table
from AdventureWorksDW2014.dbo.FactInternetSales
set @RunningTime = DATEDIFF(ms, @starttime, sysdatetime())
print 'Ausführungszeit Select-Into: ' + cast(@runningtime as nvarchar(5))

select * from dbo.[Order Details Revised]

-- ###########################################################################################
-- #### Erkenntnis #5 : Speicher-Adressierung ist fundamental für die Optimierungsoption #####
-- ###########################################################################################

-- VARCHAR ist flexibel, nimmt so viel Platz wie sie braucht
	-- Fingerzeig zu später :: SHIT after UPDATE & SHIT after ALTER  
-- PAGING-Struktur essentiell bereits beim Einlesen / Updaten / Ändern der Datensätze
	-- mehrere Seiten am Stück (8) nennt man Block
	-- eine Seite kann nie mehr als 700 Datensätze haben
	-- eine Seite sollte immer sehr gut gefüllt sein --> Seiten kommen 1:1 in dem RAM-Speicher
	-- SQL liest IMMER vom RAM Speicher und NIE direkt vom Datenträger
-- PAGEs und EXTENTs
	-- SQL liebt blockweise Lesen --> Festplatte 64k formatieren --> Festplatten liest blockweise
	-- logische Lesevorgänge sind die Seiten, die SQL Server erst noch holen musste
-- OBERSTES ZIEL :: ANZAHL DER SEITEN REDUZIEREN
	-- je weniger Seiten, desto weniger CPU-Einsatz, desto weniger RAM-Verbrauch
	-- ESELSBRÜCKE "Einkaufen" :: großer Wagen im Supermarkt
		-- > man will vermeiden viele kleine Einkaufswagen zu nehmen
		-- > vorzugsweise keine kleine Häppchen immer wieder holen
		-- > Einsatz des Wagens weniger aufwendig, auch wenn mehr Daten (-Platz) als gefragt

-- ###########################################################################################
-- ###########################################################################################
-- ###########################################################################################

-- ######################################################

-- ##### DB-Design - Mehr als "nur" Normalisierungen ####

-- ######################################################

/*
-- Normalisierung :: 1.NF bis 3.NF ist OK, darüber eher akademisch als alltäglich nützlich
-- Generalisierung :: Gleichartige Daten an einem Ort 
	-- > (Lieferanten, Kunden, Angestellte) <~>  Anschrift [ STRASSE | PLZ | ORT ]
-- Extrahierung :: Validiereren von Daten durch [ PLZ | ORT ] , um Fehler zu korrigieren
	-- > Daten die in mehreren Tabellen gleichartig vorkommen, werden extrahiert
	-- > macht keinen Sinn, MasterData Quality Service macht so was, ansonsten nicht extrahieren
-- Redundanz :: Gegenteil von Normalisierung
	-- > Bewusst Daten doppelt vorhalten, da Redundanz sehr schnell für die Auswertung
	-- > Deshalb bitte bewusst die 3.NF
*/

-- ######################################################

-- ##### NORMALISIERUNG : GRAD 1 --> automare Werte

	[ A | 1 , 2 , 3 , 1 , ... ]   [ B | 5 , ... ]

	[ A | 1 ] [ A | 2 ] [ A | 3 ] [ A | 1 ]   ...   [ B | 5 ] ...

	-- > zusammengesetzte Attribute schlecht für Such-Anfragen

-- ##### NORMALISIERUNG : GRAD 2 --> Eindeutigkeit durch PRIMARY KEY

		[ A | 1 ] -- löschen von DS die gleich sind geht nicht
		[ A | 2 ]
		[ A | 3 ]
		[ A | 1 ] -- ERROR-MESSAGE :: zu viele Änderungen in Datenbank

	
	[ 1 | A | 1 ] -- jetzt geht es da es nicht dopplet vorkommt
	[ 2 | A | 2 ]
	[ 3 | A | 3 ]
	[ 4 | A | 1 ]

	-- > Eindeutigkeit der Werte macht Datenmanipulations erst möglich

	
-- ##### NORMALISIERUNG : GRAD 3 --> Keine Abhängigkeit der Spalten untereinander

	Kunde [ PLZ | ORT ] 
	--> ORT ändert PLZ , aber PLZ ändert nicht zwingend ORT (München, Berlin,...)
	--> schnell im schreiben (neuer) Datensätze, aber Vollständigkeit nur über JOINs

-- ##### NORMALISIERUNG : GRAD 3 sollte man bewusst VERLETZEN durch die REDUNDANZ

	Kunde [ Land ] : 1 MIO Kontakte mit durchschnittlich 2 Bestellungen
	Bestellungen   : 2 MIO Einträge mit durchschnittlich 2 Positionen pro Bestellung
	Positionen     : 4 MIO Bestell-Details [ Menge * Preis ]

	Umsatz pro Land eines Kunden
	--> JOIN über ALLE Tabellen :: Redundanz-freier Ansatz
		7 MIO Datensätze, die angefasst werden müssen, um Auswertung möglich zu machen
	--> REDUNDANZ :: Bestellung [ BestellSumme ] als zusätzliche Information
		3 MIO Datensätze, weil die Tabelle Positionen nicht notwendig für Auswertung

-- Data Warehouse macht ganz viel Redundanz, um keine JOINs zu machen --> spart enorme Rechenzeit

-- ###########################################################################################
-- #### Erkenntnis #6 : Verletzte 3.NF ist die Idealform einer Datenbank im REALEN Leben #####
-- ###########################################################################################

-- Gutes Mass ist das Mittelding : Redundanz ist gut, muss aber gepflegt werden (vergiss INDEX nicht!)
	-- > Änderung der Bestell-Details [ Menge ] forciert keine Änderung der [ Bestellsumme ]
	-- > Trigger (schlechte Performance) | Softwarelösung (im Regelfall unsicher, also nur intern)
-- #Temp tabellen sind auch redundant
	-- > Ergebnisse rausziehen als #Temp hat weniger Daten und wird nur (einmal) geladen
	-- > #Temp wird immer wieder abgefragt (reduzierte Datenmenge), diese sind aber doppelt
-- Was ist mit der Physik?!
	-- > vergesst Seiten und Blöcke nicht!
	-- > KEINER schaut sich bei der Normalisierung Seiten und Blöcke an!

-- ###########################################################################################
-- ###########################################################################################
-- ###########################################################################################

-- ### DoomsDay-Beispiel :: Seiten wichtiger als Normalform

-- ######################################################

drop table if exists dbo.tab1
go

create table tab1 (id int identity, SpalteX char(4100)) -- sehr breite Tabelle
	-- CRM hat meist sehr breite Tabellen
	-- Spalten wie : fax1, fax2, fax3, Hobby1, Hobby2, Frau1, Frau2, Frau3, Frau4, Religion

INSERT INTO tab1
SELECT '##'
GO 20000

SELECT * FROM Tab1 

-- ### Show Contingent : Seiten | Blöcke | ScanDichte | SeitenDichte | ...

dbcc showcontig('tab1')

	'[...]'

-- ### SpeicherBericht

DatenBank > Berichte > Standardberichte > Datenträgerverwendung durch oberste Tabellen
DataBase  > Reports  > Standard Reports > Disc Usage by TOP Tables

-- ### Hochskaliertes Problem

	'[...]'

--- ### ReFactoring : ReDesign durchführen

	statt char lieber varchar 
	statt EINER sehr breiter Table lieber zusätzliche AuslagerungsTabellen 

	
					'[...]' Speicherbedarf
	[ Tabelle A ]    <<  SPLITTEN  >>       [ Tabelle B ]
 

					'[...]' Speicherbedarf

-- ###########################################################################################
-- ### RoadMap für die Planung der Optimierung von Datenbank-Struktur und Abfrageverhalten ###
-- ###########################################################################################

-- Standardbericht > Datenträgerverwendung
	-- > Tabellen mit großer Anzahl an Datensätze / große Tabellen finden
-- dbcc showcontig() 
	-- > zeigt komplette Statistik für alle Tabellen an
	-- > untersuchen DatenDichte sowie Seitenanzahl
	-- > ggf. umstrukturieren (ReDesign)
-- Art des ReDesigns wählen > mögliche FehlerQuellen im Auge behalten
	-- > APP geht nicht mehr :: DatenTyp anpassen, Spalten auslagern,... (ReDesign)
	-- > APP weiß nix davon  :: Komprimierung (SHRINK DATABASE) als Sofort-Maßnahme besser

-- ###########################################################################################
-- ###########################################################################################
-- ###########################################################################################

-- ### Schlechtes Design eruieren > Diagramm auslesen

-- ######################################################

	Diagramm -> Tabellenansicht -> Modify Custom -> SpaltenName | DatenTyp-Kurz | NULL zulassen | Identität
	alles markieren -> rechtsklick -> benutzerdef. anzeigen -> IDENTITY auslesen

-- ######################################################

-- ### Schlechtes Design eruieren > DatenTyp ändern

-- ######################################################

	nicht immer ist gesagt, dass es klappt mit Maßnahmen deutlich viel einzusparen
	Tools -> Options -> Designers -> Table Designer.. -> 'Prevent saving changes..'
	Beispiel: Table [DESIGN] -> date statt datetime -> Änderungsskript generieren...

-- ######################################################

-- ### Schlechtes Design eruieren > DB-Komprimierung

-- ######################################################

-- Voraussetzung für Messung:

	create table tab2 (id int identity, SpalteX char(4100))
	
	insert into tab2
	select '##'
	GO 20000

	set statistics io, time on
	select * from tab2
	
-- Kompression

	KompressionsTypen | ROW <> PAGE
	ROW 
		untersucht zeilen auf Leerzeichen und schmeisst die raus
		zieht alles zusammen, wodurch es werden weniger Seiten werden 
	PAGE
		macht zuerst ROW
		danach Mustererkennung und versucht nach diesem Muster zu ersetzen
		Beispiel: [ Deutschland = D ] und verpackt es dann gemäß 'ZIP'-Muster

--	RAM : ungefähr gleich geblieben
	-->	Seiten werden 1:1 in RAM, daher werden die komprimierten Seiten (28) in RAM gelegt

--	CPU : stark schwankend
	--> deutlich weniger Seiten --> CPU weniger
	--> Daten müssen DEKOMPRIMIERT zum Client kommen (sqlservr.exe) --> hier steigt CPU
	--> im Regelfall wird CPU unterm Strich höher ausfallen > DeKompilierung durch DeKompression

-- Dauer : ungefähr gleich
	--> die Dauer würde ansatzweise gleich blieben (man spart, aber dann kommt DeKompression)
	--> große Datenmengen müssen zum Client gebracht werden (160MB dekomprimiert)

-- ###########################################################################################
-- #### Erkenntnis #7 : Tausche Speicher gegen Rechenzeit, profitiere selbst aber nicht ######
-- ###########################################################################################

-- Kompression bringt mehr RAM, kostet aber CPU
-- die komprimierten Tabellen profitieren nicht davon, da Dekomprimierung notwendig für APP
-- der lachende Dritte sind ANDERE Tabellen, die jetzt auch Platz im RAM finden
-- Auswertungshilfe
	--> CPU-Zeit deutlich größer als verstrichene Zeit = Parallele Abarbeitung
	--> verstrichene Zeit deutlich größer als CPU-Zeit = Lesen dauert länger als Verarbeiten

-- Standard-Ansatz für Archiv-Tabellen
	--> selten genutzte Tabellen, die sich gut komprimieren lassen
	--> Seiten-Reduktion ist eigentlich großer Vorteil der Verkleinerung

-- INDEX zielführender, um TABLE-SCAN zu vermeiden
	--> ALLE Datensätze müssen nach wenigen Daten durchsucht werden
	--> fehlender INDEX erzwingt Daten komplett in RAM zu laden > Komprimierung sehr sinnvoll

-- Komprimierung findet im Regelfall nur einmal statt
	--> neue Datensätze werden NICHT mit-komprimiert, Alt-Bestand bleibt komprimiert
	--> nur bei CLUSTERED INDEX werden auch neue Datensätze beim Einlesen mit-komprimiert

-- Ganze Datenbanken lassen sich nicht komprimieren (sonst 100% CPU-Leistung)
	--> SQL Profiler : ALLES führt zu SpeicherVerbrauch (Aufrufen von DB-Eigenschaften)
	--> JEDER Klick mehr würde MEHR CPU-Leistung erfordern als vorher (Dekomprimierung)

-- ###########################################################################################
-- ###########################################################################################
-- ###########################################################################################

-- ###### MAXDOP = MAXimum Degree Of Parallelism ########
					'ENTERPRISE FEATURE'
-- ######################################################

USE [Northwind]
GO

select * from dbo.KundeUmsatz

SELECT * INTO demo1 FROM dbo.KundeUmsatz
GO
ALTER TABLE demo1 ADD ID INT IDENTITY
GO
SELECT * INTO demo2 FROM dbo.KundeUmsatz
GO
ALTER TABLE demo2 ADD ID INT IDENTITY
GO

-- Server-Eigenschaft > Schwellenwert für Parallelität 

set statistics io , time on

SELECT City
	,  SUM(Freight)
FROM dbo.KundeUmsatz
GROUP BY City

SELECT D1.City
	, SUM (D2.Freight)
FROM dbo.demo1 AS D1 INNER JOIN dbo.demo2 AS D2 ON D1.CustomerID = D2.CustomerID
GROUP BY D1.City


-- ### Maler-Beispiel #########################################################################

	-- Problem: je mehr man Maler holt, desto schwieriger wird es es zu organisieren!!
	-- Irgenwann stehen Maler sinnlos herum oder treten sich auf die Füße
	-- Kein anderer kann einen Maler haben, solange alle nur bei einem sind und das nicht effektiv

-- ### das lässt sich auch per Befehl einstellen (Zeit-basiertes Umstellen von Server-Einstellungen!)

EXEC sys.sp_configure N'show advanced options', N'1'  RECONFIGURE WITH OVERRIDE
GO
EXEC sys.sp_configure N'cost threshold for parallelism', N'25'
GO
EXEC sys.sp_configure N'max degree of parallelism', N'4'

-- ### auch in TSQL MAXDOP einsetzbar

select * from orders
where orderid = 10333

select * from orders 
where orderid = 10333 option (maxdop 4) --nimm nicht mehr als 4 ,

-- ###########################################################################################
-- #### Erkenntnis #8 : Viel hilft viel ist ein Irrglaube, was SQL-Parallelität anbelangt ####
-- ###########################################################################################

-- Zunächst verwendet der SQL Server alle CPUs, die er physisch findet
	-- > SQL SVR hat Aufwand das zu verteilen, weshalb der Overhead größer als Nutzen sein kann
	-- > CXPACKET (Class Exchange Package) Ereignis sobald Parallelität zustande kommt
	-- > Je mehr Threads man startet, umso aufwändiger ist die Organisation der einzelnen Teile
-- Es gibt eine Optimale Einstellung im Zusammenspiel zwischen CTP und MaxDOP
	-- > CTP = Cost Threshold for Parallelism = SQL$-Schwelle, über der er erst parallelisiert
	-- > MaxDOP = Maximum Degree of Parallelism = wie viele CPU-Kerne dürfen verwendet werden
	-- > Nach Ändern der Werte IMMER einige Male die Abfrage laufen lassen für Kompilierung
-- Aktualisierung der Server-seitigen Einstellungen bzgl. CTP und MaxDOP
	-- > Die Werte lassen sich jederzeit ändern und gelten erst ab der NÄCHSTEN Abfrage
	-- > Bestehnde Abfragen sind NICHT betroffen und können zur Laufzeit das nicht abändern
	-- > Deshalb lieber TSQL MaxDOP Options wählen, um das "im Kleinen" zu testen
-- Faustregeln, da CTP von 005 SQL$ im Standard einfach absurd wenig ist
	-- > OLTP (ShopSystem) 50% der CPUs und setze CTP auf 25
	-- > OLAP (DatenBank)  CTP auf 50 und 

-- ###########################################################################################
-- ###########################################################################################
-- ###########################################################################################

-- ###### INDIZES, INDIZES, INDIZES, INDIZES, ... #######

-- ######################################################

-- ### Typisierung

	HEAP  :: 'unsortierte' Daten 
				-> Sortierung entsteht durch Schreibvorgang

	INDEX :: '8053 Byte' Seite
				-> Entscheidet wie viele Seiten pro Index-Ebene verwendbar sind
				-> Objekt in Datenbank, das Speicher allokiert, um Anzahl der Speicherzugriffe zu verringern
				-> Im Idealfall ausbalancierter k-närer Baum wie im Telefonbuch ('vs. Mitarbeiter-Hierarchie')
	
	CLUSTERED INDEX :: physische Umsortierung und auch Abspeicherung / Aktualisierung
	COMBINED CLUSTERED INDEX :: mehrere Spalten als ein gemeinsamer Index (PRIMARY KEY COLUMN) 

	NONCLUSTERED INDEX  :: NON CL IX :: VerzeichnisBaum aus VerweisStruktur auf phyischen Speicher der Daten
	CLUSTERED INDEX		::     CL IX :: Daten werden gemäß der Struktur PHYSISCH neu abgelegt bzw. einsortiert

2.     CL IX immer zuerst vergeben auf "Bereichsspalten"
1. NON CL IX						--> wenn RELATIV WENIG rauskommt (ID Spalten , GUID, PK..etc..) 
--------------------------------------------------------
	   Grouped Columnstore Index
	NonGrouped Columnstore Index	--> je weniger Daten bei Anfrage herauskommen, umso günstiger
--------------------------------------------------------

	zusammengesetzter IX					'COMBINED'
	IX mit eingeschlossenen Spalten			'INCLUDING' -- TOP INDEX
	gefilterter IX							'FILTERED'	-- schneller weil kleiner
	partitionierter IX									-- Partionierung
	eindeutiger IX							'UNIQUE'
	abdeckender IX							'COVERED'
	indizierte Sicht									-- INDEX auf VIEW
	real hypothetischer IX								-- macht ein Analyser-Tool

--------------------------------------------------------

select * from sys.indexes		 --< welche Indizes kennt die Datenbank

dbcc IND(0, 'dbo.KundeUmsatz',1) --< welche Index-Struktur hat die Tabelle

--------------------------------------------------------

select newid()					--< Beispiel für General Unique ID (GUID)

--------------------------------------------------------

-- ### Verschiedene Indizes einfach mal durchprobiert

select * into kundeumsatz2 from dbo.KundeUmsatz -- Kopie Tabelle in eine neue Tabelle

-- ### SCAN HEAP

	'[...]'




















					
	'CL ist gut für Bereichsabfragen, aber PK ist eindeutig; ID ; aber wir verlieren durch PK als CL IX 
	auf ID Spalten, die Möglichkeit	den CL IX auf Spalten zu vergeben, die häufig mit Bereichsabfragen
	untersucht werden >>> PK muss NICHT ein CUSTERED INDEX sein!!

	DESIGNER der Tabelle -> Rechtsklick -> Indizes/Schlüssel --> Als Clustered erstellen - Nein --> Ersetzen

	Regel: versuche zu erst den CL IX zu vergeben und dann setzte den PK, da immer gut für Bereichsabfragen! 
	ODER erstelle Tabellen von Hand und schreibe beim PRIMARY KEY gleich NONCLUSTERED hinein'

	-- ###########################################################################################

-- ### Praktische Umsetzung : Gute Idee / Schlechte Idee bezüglich der Abfragen

-- FRAGE | Wie läuft die Abfrage? Gut oder schlecht? Warum? Was könnte man verbessern?
-- IDEE  | Ablaufplan > Index 

USE [Northwind]
GO

SELECT CompanyName, Freight, Country
FROM Customers AS C
	INNER JOIN Orders AS O ON C.CustomerID = O.CustomerID
WHERE C.ContactTitle LIKE '&manager%'
		OR 
		O.Freight < 10
		AND
		EmployeeID in (1,3,5)


-- ###########################################################################################
-- ##### Erkenntnis #9 : Alles steht und fällt mit INDEX-Pflege und dem CLUSTERED INDEX ######
-- ###########################################################################################
/*
-- SQL SVR erstellt keine nutzbaren Indizes automatisch, aber AZURE macht das im Hintergrund
-- INDEX ist kein Allheilmittel, aber ohne ist SEEK nicht möglich und SCAN zwingend
	--> man kann nicht für jede denkbare Abfrage eine Indizierung vorhalten
	--> ohne INDEX ist Abfrage gezwungen, ALLE Daten einzulesen für ggf. nur EINEN Datensatz
-- Für alles einen INDEX bauen oder alle Spalten in den Index aufnehmen ist keine gute Idee
	--> geht nicht, weil nur max 16 Spalten möglich sind (max 900byte Schlüssellänge)
	--> in der Praxis kaum vorstellbar, dass man mehr als 4 Spalten benötigt für ix_NC Infos
	--> für jede Abfrage den idealen Index zu bauen, ist auf Dauer schlecht [INS / UPD / DEL]
-- Index-Typen
	--> CLUSTERED : immer zuerst vergeben auf "Bereichspalten"
	--> NONCLUSTERED : häufige (kombinierte) Filter für Abfragen
	--> COMBINED : nur für WHERE Spalten, alles andere macht keinen Sinn, in JEDER Ebene 
				   wenn im SELECT die Spalte gesucht wird, verhindert dieser einen LOOKUP
	--> INCLUDING : Informationen stehen erst in der untersten Ebene beim VerzeichnisBaum
					Der Baum bleibt klein, damit auch der Aufruf und die Info ist aber da
	--> COVERED : Sonderform des INDCLUDING > Abfrage kann mit SEEK und ohne einen einzigen
				  LOOKUP oder SCAN ; dieser IX ergibt sich, man kann ihn nicht "machen"
*/
-- ###########################################################################################
-- ###########################################################################################
-- ###########################################################################################

-- ######################################################

-- ###### Statistiken und Heuristik des Ablaufplans #####

-- ######################################################

	Statistiken: SQL Server macht bei jeder Abfrage Gebrauch von Statistiken (automatisch erstellt)
	SQL braucht eine Schätzung wieviele Datensätze rauskommen > Entscheidung IX SEEK oder IX SCAN

-- Statistik-Tabelle : ESTIMATED vs ACTUAL Execution Plan

select * into o1 from orders

select * from o1 where orderid = 10250 

select * from o1 where shipcountry = 'UK' 

select * from o1 where shipcity = 'berlin' 

select * from o1 where freight < 1 

-- ### Automatische Index-Erstellung durch Statistik (grüner Text im Ablauffenster)

select contactname , sum(freight) from kundeumsatz2
where employeeid = 5 or customerid = 'ALFKI'	--< Kein INDEX bei OR-Verbindung
group by contactname

dbcc showcontig('kundeumsatz2')

-- ######################################################

-- ###### COLUMNSTORE INDEX als "Traum-Index", oder?! ###

-- ######################################################

set statistics io, time off
select		productname, count(*) 
from		kundeumsatz
where		unitprice > 30
group by	productname

select		productname, count(*) 
from		kundeumsatz2				-- NEU ERSTELLEN!
where		unitprice > 30
group by	productname

	'GROUPED COLUMNSTORE INDEX'

	-- ARCHIVE COMPRESSION for COLUMNSTORE
	-- PAGE & ROW COMPRESSION for TABLE DESIGN

-- Spalten lassen sich deutlich besser komprimieren als Zeilen
-- bei Zeilen holt der SQL alles und es ist alles in Spalten hochkomprimiert!

-- Warum ist das so? Welche Nachteile ergeben sich?
-- was ist für jeden IX schlecht: Pflege (UPD / INS / DEL)

-- ###########################################################################################
-- ## Erkenntnis #10 : GROUP COLUMNSTORE INDEX ist ein Wunder-Index, aber mit Einschränkung ##
-- ###########################################################################################
/*
-- neue DS kommen nicht in den CS, sondern bleiben eine Zeit im delta_Store
	-- erwartet eine gewisse Zeit, und komprimiert nicht jeden neuen DS
	-- es sei denn, es sind 1 MIO DS in der Summe oder 140000 DS am Stück; erst dann wird der
		Tupplemover (aus dem DeltaStor in Segmente überführen) die Kompression einleiten.
		Bis dahin ist delta_store = HEAP. Auch CS_IX wird komprimiert in den RAM geladen.
	-- Für Archiv-Tabellen erster Kandidat (für RAM und CUP optimierter Index)'
-- Grenzen der Optimierung
	-- Index wird nicht genommen > Statistik verschätzt sich oder es existiert anderen Index
	-- Indizierte Sicht ist kaum wirklich nutzbar (zu viele Einschränkungen)

-- erst ab SQL 2012 (Non-Grouped COLUMNSTORE INDEX) -> nicht updatebar mittels INS / UPD / DEL
-- ab SQL 2014 Grouped Grouped COLUMNSTORE INDEX -> automatisch updatebar
-- ab SQL 2016 SP1 sind viele Features von ENT in STANDARD und in EXPRESS gewandert
*/
-- ###########################################################################################
-- ###########################################################################################
-- ###########################################################################################

-- ######################################################

-- ###### Interne Auswertung aller verwendeter INDEX ####

-- ######################################################

select * from sys.partition_schemes
select * from sys.partition_functions
select * from sys.schemas
select * from sys.indexes

SELECT * FROM sys.dm_db_index_Usage_Stats		-- Statistische Auswertung der Indizes
WHERE database_id > 4							-- dies sind User-DBs (darunter Sys-DBs)

	-- index_id 0 = HEAP
	-- index id 1 = CL ID
	-- alle höheren sind Nonclustered
	-- die schlechten ohne Seeks am besten löschen!
	-- wenig lookups ist immer gut, werden mit der Hand erstellt

-- ### Tabelle-Index-Name SEIT SQL-SVR-Neustart!!

select * from sys.indexes --< Liste bekannter Indizes (unten Beachten VERWENDETER Indizes!) 

SELECT object_name ( i.object_id ) AS TableName
	, I.type_desc, I.name
	, US.user_seeks , US.user_scans, US.user_lookups, US.user_updates
	, US.last_user_scan, US.last_user_update
FROM sys.hash_indexes AS I
	LEFT OUTER JOIN sys.dm_db_index_usage_stats AS US
		ON I.index_id = US.index_id
		AND I.object_id = US.object_id
WHERE OBJECTPROPERTY ( i.object_id, 'IsUserTable' ) = 1
GO

dbcc showcontig ('kundeumsatz') 

-- ###### forwarded_record_count ####

-- Systemfunktion, die mehr Infos als DBCC liefert.

select * from sys.dm_db_index_physical_stats
	(db_id(),						-- aktuelle DB
	 object_id('kundenumsatz'),		-- von welcher TAB
	 NULL,							-- zusätzl. Schalter
	 NULL,							-- zusätzl. Schalter
	 'detailed'						-- VERBOSE MODE
	)

-- ##### Beispiel

set statistics io, time off

create table demoxy (id int identity, spx char(7500), spy varchar(1000))  -- 8.500 > 8.060 

insert into demoxy values ('xx', 'x')									  -- 7.500 + 1 = 7.501 < 8.060
GO 1000

dbcc showcontig ('demoxy')

select * from sys.dm_db_index_physical_stats
	(db_id(),
	 object_id('demoxy'),
	 NULL,
	 NULL,
	 'detailed'															  -- forward_record_count = 0
	)

select * from demoxy where id = 1										  -- 1.000 Seiten (kein Index!)

update demoxy set spy = replicate('x', 1000)							  -- 1.000 Seiten MIT ÜBERLÄNGE

				--(spx = 7500) + (spy = 1000 ) = 8500 > 8060   (Seite hat nur 8192 Bytes grundsätzlich)

dbcc showcontig ('demoxy')												  -- Seiten zu ca. 93% voll

select * from sys.dm_db_index_physical_stats
	(db_id(),
	 object_id('demoxy2'),
	 NULL,
	 NULL,
	 'detailed'									-- [ROW_OVERFLOW_DATA] = 150 zusätzliche Seiten
	)

-- ######################################################

-- ###### Partionierung der Sicht via Salami-Taktik #####

-- ######################################################

-- ### Problem: UMSATZ 

create table u2018 (id int identity, jahr int, spx int) 
create table u2017 (id int identity, jahr int, spx int)
create table u2016 (id int identity, jahr int, spx int)
create table u2015 (id int, jahr int, spx int)

-- VIEW wird erstellt mit allen Daten

create view Umsatz
as
select * from u2018
UNION ALL			--wichtig: keine doppelten DS möglich
select * from u2017
UNION ALL
select * from u2016
UNION ALL
select * from u2015

select * from umsatz -- alle Tabellen

select * from umsatz where jahr = 2017 -- immer noch ALLE Tabellen

alter view dbo.umsatz with schemabinding
as
select * from u2018
UNION ALL			--wichtig: keine doppelten DS möglich
select * from u2017
UNION ALL
select * from u2016
UNION ALL
select * from u2015

-- CONSTRAINT-Lösung

ALTER TABLE dbo.u2015 ADD CONSTRAINT
	CK_u2015 CHECK (jahr=2015)

ALTER TABLE dbo.u2016 ADD CONSTRAINT
	CK_u2016 CHECK (jahr=2016)

ALTER TABLE dbo.u2017 ADD CONSTRAINT
	CK_u2017 CHECK (jahr=2017)

ALTER TABLE dbo.u2018 ADD CONSTRAINT
	CK_u2018 CHECK (jahr=2018)

SELECT * FROM umsatz WHERE jahr = 2017 --> über CONSTRAINTs Stück für Stück einschränken

SELECT * FROM umsatz WHERE jahr = 2011 --> bewirkt CONSTANT SCAN, da 2011 nicht existieren kann (KEINE Tabelle)

select * from umsatz where id = 2011   --> immer noch alle Tabellen

-- SEQUENZ-Lösung (internes Programm)

CREATE SEQUENCE [dbo].[mySEQ] 
 AS [bigint]
 START WITH 1
 INCREMENT BY 1
 
insert into umsatz(id, jahr, spx) values (next value for mySEQ, 2016, 4)

insert into umsatz(id, jahr, spx) values (next value for mySEQ, 2017, 3)

insert into umsatz(id, jahr, spx) values (next value for mySEQ, 2018, 3)


select * from umsatz
where id = 100			--< wieder SCAN 

-- ######################################################

-- ###### Physische Partitionierung der Datensätze ######

-- ######################################################

create table tab (id int) --würde so immer auf [PRIMARY] liegen

	'Dateigruppe erstellen > Logischer Name für Aufruf'

create table tab21 (id int) on XY -- als Beispiel

--  Dateigruppen anzulegen (bis100   | bis200    | Rest)
			'LOGICAL NAME : nwbis100 | nwbis200  | nwRest'

	'int Wert nehmen

    -2,1 MRD--------100]------------200]----------------  +2,1Mrd
	            1             2               3	'

-- "isolierte" physikalische Bereiche
	-- bis zu  1.000 Bereiche bis SQL 2005 
	-- bis zu 15.000 Bereiche ab  SQL 2008

-- Partition FUNCTION()

create partition function fZahl1(int)
as
RANGE LEFT FOR VALUES (100,200)

select $partition.fzahl1(201)		--  1 oder 2 oder 3 

-- Partition SCHEMA

create partition scheme schZahl2
as
partition fzahl1 to (nwbis100,nwbis200,nwrest) 

	'alle nwbisxxx sind die Filegroups/Dateigruppen > VORHER angelegt
		logischer Name: bis100 | bis200 |  Rest
-----------------------  1			2	     3   --------------------'

-- Tabelle erstellen und Zahlen schreiben

create table ptab1 (id int identity, nummer int, spx char(4100))
ON schZahl2(nummer)	

	set statistics io, time off	-- Statistik abschalten, sonst dauert das ewig!

	declare @i as int = 1

	while @i <= 20001			-- 20.000 Werte, aufsteigend gezählt
		BEGIN
			insert into ptab1 values(@i, 'XY')
			set @i+=1
		END		

-- ### aktuelle Übersicht der Partitionierung

select $partition.fzahl1(nummer), min(nummer), max(nummer), count(*)
from ptab1
group by $partition.fzahl1(nummer)

-- ##### Ist das akademisch oder hat das einen "echten" Nutzen?

-- Ändere das Schema zum Ergänzen von nwbis5000
alter partition scheme schZahl2 next used nwbis5000
select * from ptab1 where nummer = 1110					-- noch keine Auswirkung

-- Schema anpassen

alter partition function fzahl1() split Range (5000)	-- neue Grenze einziehen

alter partition function fzahl1() merge range(100)		-- untere Grenze verschmelzen

select * from ptab1 where nummer = 11  

-- ##### Grenze entfernen: 100

----x-------200--------5000--------------- betroffen : partition function ()
--     1            2           3          betroffen : Scheme und DataGroups

-- ##### ARCHIV-Funktion

create table archiv
	(id int not null, nummer int, spx char(4100)) on bis200

--es gibt kein TSQL Statement zum Verschieben von Datensätzen
	--hier schon ;-)

alter table ptab1 switch partition 1 to archiv

select * from archiv  -- alle von 1 bis 200

-- ##### Sonderfall : DATUM

create partition function fZahl(datetime) --> 
as
RANGE LEFT FOR VALUES ('31.12.20xx 23:59:59.999','')

	-- Verständnisfragen

	-- Kunden von A bis E  &&  von F bis R  &&   Rest
	

-- ######################################################

-- ###### Lösungen aus den Aufgaben von Kurstag No 1 ####

-- ######################################################

-- Lösung 1

drop proc IF EXISTS uspKDSuche

create proc uspKDSuche @kdid varcahr(10) ='%'
AS
SELECT * FROM KundeUmsatz WHERE CustomerID LIKE @kdid + '%'

-- Idealer Index : idx_NCL_customID mit INCLUDING-Spalten aus dem SELECT

-- Vorteil der Prozedur? Er merkt sich genau den Plan!

exec uspKDSuche 'ALFKI'  -- idealer Plan würde einen SEEK beinhalten
exec uspKDSuche '%'
exec uspKDSuche          -- Ablaufplan immer identisch, auch wenn TABLE SCAN günstiger wäre

set statistics io, time on

SELECT * FROM KundeUMsatz WHERE customerid = 'ALFKI'		-- SEEK

SELECT * FROM KundeUMsatz WHERE customerid like '%' + '%'	-- SCAN : 55.000 Seiten

exec uspKDSuche						-- Faust-Formal : 25% für Index extra > 70.000 geschätzt
									-- Fakt-Auswertung : 1.100.000 LeseVorgänge

	'Der PLAN wird vorkompiliert beim ersten Ausführen der PROCEDURE. Aber PROC sollte immer gleiches
	 leisten, also einen DS mehr oder weniger. Fazit : NIE benutzerfreundliches TSQL in PROC!

	Besser mit 2 PROCEDURES : SucheWenigProc und SucheAlleProc > ist optimiert für den einzelnen Aufruf!'

	alter PROC uspKDSuche @kdid varchar(5)
	AS
	IF %
		exec proc alle
	ELSE
		exec proc wenige

--------------------------------------------------------------

-- Lösung Aufgabe 2

SELECT * FROM employees

SELECT * from employees WHERE year(getdate()) - year(birthdate) >=65

SELECT * FROM employees WHERE datediff(yy, birthdate, getdate()) >=65

	'Beide schlecht! Das wird immer zu einem SCAN führen! Schlecht ist die FUNCTION() um die Spalte im WHERE.'

	suche so: famname like 'K%'		-- schneller Muster-Vergleich
	suche so: left(famname,1) ='K'	-- JEDER Datensatz muss überprüft werden
									-- Mit der FUNCTION() wird stets ALLES überprüft!!

	'Daher bei DB Design sehr sinnvoll : Daten explizit splitten.
	 Bestelldatum (Date) + weitere Spalten: Quartal, Jahr, Tag, Monat'


-- im Falle employees besser abzufragen

SELECT * FROM employees 
WHERE birthdate <= dateadd(yy,  -65, getdate()) -- kann SEEK werden

-- so muss die Spalte nicht zerlegt werden, es werden direkt Werte verglichen (nur über INDEX erklärbar!).

--------------------------------------------------------------------------