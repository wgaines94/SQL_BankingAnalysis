use Banking
go

select top 100
	*
--account id no more than 4 digits, distirct no more than 2
from dbo.account

select distinct
	birth_number
from dbo.client
where len(birth_number)>6
--from online: birth number is YYXXDD/SSSC
--for males, XX is just birth mobth MM (1-12), for females XX = 50+MM
--SSSC is used to distinguish people with same birthday (none exist in our data)

select 
	*
from dbo.disp

select top 100
	*
from dbo.district

--database column query
select
	 s.name + '.' + t.name as TableName
	,c.name as ColumnName
	,ty.name + ' (' + cast(ty.max_length as varchar(10)) + ')' as VariableType
from sys.tables as t inner join sys.schemas as s
	on t.[schema_id] = s.[schema_id]
inner join sys.columns as c
	on object_name(c.[object_id]) = t.name
inner join sys.types as ty
	on ty.user_type_id = c.user_type_id