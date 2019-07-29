use Banking
go

if schema_id('Cleansed') is null
begin
	create schema Cleansed
end
go

declare @EndDate as date
select @EndDate = max(cast([date] as date))
from dbo.transactions
--final transaction date in the analysis, to be used as reference point for calculating ages


if object_id('Cleansed.Client') is not null
begin
	drop table Cleansed.Client
end

;with DateCleanse
as
(
select
	 client_id
	,cast('19'+
		CASE
		when cast(substring(birth_number,3,2)as int)>12
			then substring(birth_number,1,2)
				+cast(cast(substring(birth_number,3,1) as int)-5 as varchar(1))
				+ substring(birth_number,4,3)
		else birth_number
		end
	as date) as BirthDate
	,district_id
	,CASE
		when cast(substring(birth_number,3,2)as int)>12
			then 'Female'
		else 'Male'
	end as Gender
from dbo.client
)
select
	 *
	,datediff(yy,BirthDate,getdate()) as Age
	,floor(
		datediff(yy,BirthDate,getdate())/10)*10 as AgeBucket
into Cleansed.Client
from DateCleanse
--dealing with Czech birth ID system (and deriving a gender field in the process)
--number is a YYMMDD date for men, but YY(MM+50)DD for women.
--the strings thus need to be converted before a date can be generated.
--CTE used for the birthday derivation, to then allow age and bucket to be calculated in the cleansing process.


if object_id('Cleansed.account') is not null
begin
	drop table Cleansed.account
end

select
	 account_id
	,district_id
	,cast('19' + date as date) as CreationDate
into cleansed.account
from dbo.account
--the only real cleansing here is to cast the creation date in to date format.
--not much information here is likely to be used, but it doesnt hurt to have it.


if object_id('Cleansed.Loans') is not null
begin
	drop table Cleansed.Loans
end

select
	 loan_id
	,account_id
	,cast('19' + [date] as date) as LoanDate
	,cast(amount as decimal(12,2)) as LoanAmount
	,cast(payments as decimal(12,2)) as PaymentAmount
	,[status] as LoanStatus
into cleansed.Loans
from dbo.loan
--loan payments are included in the transaction data.
--since we are concerned with debt we will later focus on cases B and D, but are leaving all now
--an outstanding balance will then be calculated later for each case


if object_id('Cleansed.StandingOrders') is not null
begin
	drop table Cleansed.StandingOrders
end

select
	 order_id
	,account_id
	,account_to
	,cast(amount as decimal(12,2)) as OrderAmount
	,CASE
		when k_symbol = 'POJISTNE'
			then 'Insurance'
		when k_symbol = 'SIPO'
			then 'Household'
		when k_symbol = 'LEASING'
			then 'Leasing'
		when k_symbol = 'UVER'
			then 'Loan'
		else null
	end as PaymentType
into cleansed.StandingOrders
from dbo.[order]
--amounts made decimal and payment types converted to english.
--a few less important columns left out for speed and simplicity


if object_id('Cleansed.Cards') is not null
begin
	drop table Cleansed.Cards
end

select
	 card_id
	,disp_id
	,[type]
	,cast('19'+ issued as date) as CardIssueDate
into Cleansed.Cards
from dbo.[card]
--only cleansing is to correct the date. Mainly helpful for any issues joining card payments to accounts



if object_id('Cleansed.Transactions') is not null
begin
	drop table Cleansed.Transactions
end

select
	 trans_id
	,account_id
	,cast('19'+[date] as date) as PaymentDate
	,CASE
		when [type] = 'PRIJEM'
			then 1
		when [type] = 'VYDAJ'
			then -1
		else null
	end
	* cast(amount as decimal(12,2)) as NetAmount
	--using the credit/debit field (type) to create a net transaction amount for each payment

	,CASE
		when operation = 'VYBER KARTOU'
			then 'Credit Card'
		when operation = 'VKLAD'
			then 'Cash in'
		when operation = 'PREVOD Z UCTU'
			then 'Bank Collection'
		when operation = 'VYBER'
			then 'Cash out'
		when operation = 'PREVOD NA UCET'
			then 'Bank Remittance'
		else null
	end as TransactionMode
	,cast(balance as decimal(12,2)) as BalanceAfterTransaction
	,Case
		when k_symbol = 'POJISTNE'
			then 'Insurance'
		when k_symbol = 'SLUZBY'
			then 'Statement'
		when k_symbol = 'UROK'
			then 'Interest'
		when k_symbol = 'SANKC. UROK'
			then 'Negative Balance Sanction'
		when k_symbol = 'SIPO'
			then 'Household'
		when k_symbol = 'DUCHOD'
			then 'Pension'
		when k_symbol = 'UVER'
			then 'Loan'
		else null
	end as TransactionType
	into Cleansed.Transactions
from dbo.transactions
--here we create net transaction ammounts, and convert category fields to english
--we will need to be careful to capture both issued and received payments on each client account.


/* NOTE:
demographics table will be left untouched as it adds little to our analysis
disposition needs little cleansing, and so will likewise be left as is.
*/
