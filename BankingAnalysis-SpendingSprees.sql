use Banking
go
--taking spree to mean consecutive days spending (not just widest spread over the whole period).
--i can identify consecutive payments, but am struggling to identify each individual block of days on an account

if object_id('Cleansed.SpreeTable') is not null
begin
	drop table Cleansed.SpreeTable
end
go

select
	 *
	,lead(PaymentDate) over (Partition by Account_id order by PaymentDate) as NextAccountPayment
	,CASE
		when lead(PaymentDate) over (partition by Account_id order by PaymentDate) = dateadd(dd,1,PaymentDate)
			then 1
		else 0
	end	as SpreeID
	,CASE
		when lead(PaymentDate) over (partition by Account_id order by PaymentDate) = dateadd(dd,1,PaymentDate)
			then lead(PaymentDate) over (partition by Account_id order by PaymentDate)
		else Null
	end	as NextPaymentDate
	
into Cleansed.SpreeTable
from Cleansed.Transactions
where TransactionMode = 'Credit Card'

select *
	
from Cleansed.SpreeTable
where SpreeID = 1

--select distinct
--	 Account_id
--	,max(spreeID) over (partition by Account_id) - min(spreeID) over (partition by Account_ID) as SpreeLength
--from Cleansed.SpreeTable
--where spreeID>0
--order by SpreeLength desc

