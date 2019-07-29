use Banking
go

--this script is designed to be run after the BankingAnalysis - Cleansing file, also located in this git repository.

--first creating iterative CTE for all ages 1 to 100.
--goal is to find lowest balance for each client at any given age (based on transactions table)
--can then overlay loan data to find peak debt age per client.

if (object_id('DimAges')) is not null
begin
	drop table DimAges  --dimension tables are generaly lookups/references
end

;with Ages
as
(
select 1 as Age

union all
select
	 1 + Age 
from Ages
where Age + 1 <=100
)
select * into DimAges
from Ages
option(maxrecursion 0) --switches off safety net of 100

--first we want the client list for account owners only (the person who is in debt)
select
	 c.client_id
	,a.account_id
	,c.Age
	,c.AgeBucket
	,c.BirthDate
into Cleansed.AccountOwners
from Cleansed.Client as c inner join dbo.disp as d
	on c.client_id = d.disp_id
inner join Cleansed.account as a
	on a.account_id = d.account_id
where d.[type] = 'OWNER'

--for each client and account the CTE lists all transactions, their balance reached, and their age at that time.
--we then take summarise this with the lowest balance reached by client at each age.

if object_id('Cleansed.ClientLowestBalanceByAge') is not null
begin
	drop table Cleansed.ClientLowestBalanceByAge
end 
go

;with AllPayments
as
(
select
	 c.client_id
	,c.account_id
	,c.Age
	,c.AgeBucket
	,t.BalanceAfterTransaction
	,t.PaymentDate
	,datediff(yy,c.BirthDate,t.PaymentDate) as AgeAtTransaction
from Cleansed.AccountOwners as c inner join dbo.disp as d
	on c.client_id = d.client_id
inner join Cleansed.Transactions as t
	on c.account_id = t.account_id
)
select distinct
	 client_id
	,account_id
	,min(BalanceAfterTransaction) over (partition by client_id, AgeAtTransaction) as LowestBalanceByAge
	,AgeAtTransaction
into Cleansed.ClientLowestBalanceByAge
from AllPayments


--now we want to aggregate all loans taken by a client, along with their age at each loan
--we can then calculate their repayments, and find a peak debt level (which will be on the day of their final loan)

if object_id('Cleansed.LoansByClient') is not null
begin
	drop table Cleansed.LoansByClient
end 
go

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
	,l.PaymentAmount
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
	,avg(PaymentAmount) over (partition by client_id) as RepaymentAmount
	,max(LoanDate) over (partition by client_id) as DateOfLastLoan
	,AgeAtLoan
into Cleansed.LoansByClient
from AllLoans
--each client has taken no more than a single loan, making our life slightly easier.

if object_id('Cleansed.AgeBalanceLoan') is not null
begin
	drop table Cleansed.AgeBalanceLoan
end
go

select
	 a.Age
	,c.client_id
	,c.account_id
	,c.LowestBalanceByAge
	,l.AgeAtLoan
	,l.TotalLoanAmount
	,l.RepaymentAmount
	,CASE
		when a.Age < l.AgeAtLoan then
			c.LowestBalanceByAge
		when a.Age = l.AgeAtLoan then
			c.LowestBalanceByAge - l.TotalLoanAmount
		when a.Age > l.AgeAtLoan then
			c.LowestBalanceByAge - l.TotalLoanAmount +12*(l.RepaymentAmount)
		end
	as TotalDebtAmount
into Cleansed.AgeBalanceLoan
from dbo.DimAges as a inner join Cleansed.ClientLowestBalanceByAge as c
	on a.Age = c.AgeAtTransaction
inner join Cleansed.LoansByClient as l
	on l.client_id = c.client_id

if object_id('Cleansed.MaxDebtByClient') is not null
begin
	drop table Cleansed.MaxDebtByClient
end
go

select distinct
	 client_id
	,min(TotalDebtAmount) over (partition by client_id) as PeakDebt
into Cleansed.MaxDebtByClient
from Cleansed.AgeBalanceLoan

select
	 b.client_id
	,b.account_id
	,b.Age
	,floor(b.Age/10)*10 as AgeBucket
	,d.PeakDebt
into Cleansed.PeakDebts
from Cleansed.AgeBalanceLoan as b inner join Cleansed.MaxDebtByClient as d
	on b.TotalDebtAmount = d.PeakDebt

select distinct
	 AgeBucket
	,avg(Age) over (Partition by AgeBucket) as AveragePeakDebtAge
	,avg(PeakDebt) over (Partition by AgeBucket) as AveragePeakDebtAmount
from Cleansed.PeakDebts
where PeakDebt<0

print('Debt here is taken to be your bank balance less the total of any loans taken out and not repaid.
	Based on transaction records clients minimum balance per age was found, then the total of any loans taken
	out at that age were deducted, to find a peak debt by year per client. These were then stripped back to find the
	age where this peak debt occurred, clients were bucketed, and the averages summarised above.'
	)
