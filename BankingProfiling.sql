use Banking
go

select top 100
	*
--account id no more than 4 digits, distirct no more than 2
from dbo.account

select top 100
	cast('19'+
		CASE
		when cast(substring(birth_number,3,2)as int)>12
			then substring(birth_number,1,2)
				+cast(cast(substring(birth_number,3,1) as int)-5 as varchar(1))
				+ substring(birth_number,4,3)
		else birth_number
		end
	as date)
from dbo.client
--from online: birth number is YYXXDD/SSSC
--for males, XX is just birth mobth MM (1-12), for females XX = 50+MM
--SSSC is used to distinguish people with same birthday (none exist in our data)

select 
	*
from dbo.disp
--main use from this will be identifying the owner of each account, as this is the focus of our analysis.

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

select
	 max(cast([date] as date)) as EndDate
	,min(cast([date] as date)) as StartDate
from dbo.transactions
--5 year range of dates.
--This is insufficent to examine the lifetime debt of each customer, so will simplify by taking their total debt now.

select top 100
	*
from dbo.loan
where status in ('B','D')


--using cleansed data
;with AllLoans
as
(
select
	 l.loan_id
	,c.client_id
	,a.account_id
	,c.Age
	,l.LoanAmount
	,l.LoanDate
	,datediff(yy,c.BirthDate,l.LoanDate) as AgeAtLoan
from Cleansed.Client as c inner join dbo.disp as d
	on c.client_id = d.client_id
inner join Cleansed.account as a
	on a.account_id = d.account_id
inner join Cleansed.Loans as l
	on a.account_id = l.account_id
)
select distinct
	 client_id
	,count(*) over (partition by client_id) as NumberOfLoans
	,sum(LoanAmount) over (partition by client_id) as TotalLoanAmount
	,max(LoanDate) over (partition by client_id) as DateOfLastLoan
from AllLoans
order by NumberOfLoans desc
--tells us that no client took out multiple loans