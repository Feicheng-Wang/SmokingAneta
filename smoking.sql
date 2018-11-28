use sy169

-- Select all valid members from both datasets
-- Record the number of entries as the count of total enrollment months
--2min
drop table tmp1AllEnrollmentEffectiveDate_2015
SELECT MemberId,
       min(OriginalEffectiveDate) as OriginalEffectiveDate,
       max(EffectiveDate) AS maxEffectiveDate,
	   count(*) AS recordCount
INTO tmp1AllEnrollmentEffectiveDate_2015
FROM AetnaDataWarehouse.dbo.Enrollment
where (EffectiveDate != '0001-01-01' )
GROUP BY MemberId

SELECT MemberId,
       min(OriginalEffectiveDate) as OriginalEffectiveDate,
       max(EffectiveDate) AS maxEffectiveDate,
	   count(*) AS recordCount
INTO tmp1AllEnrollmentEffectiveDate_2016_2017
FROM AetnaDataWarehouse_2016_2017.dbo.Enrollment
where (EffectiveDate != '0001-01-01' )
GROUP BY MemberId

select * 
into tmp1AllEnrollmentEffectiveDate
from tmp1AllEnrollmentEffectiveDate_2015

Insert into tmp1AllEnrollmentEffectiveDate
select *
from tmp1AllEnrollmentEffectiveDate_2016_2017

-- Merge record from both databases
select MemberId, min(OriginalEffectiveDate) as OriginalEffectiveDate,
max(maxEffectiveDate) AS maxEffectiveDate,
sum(recordCount) AS recordCount
into tmp2AllEnrollmentEffectiveDate
from tmp1AllEnrollmentEffectiveDate
group by MemberId

select MemberId, OriginalEffectiveDate as EnrollmentStartDate,
EOMONTH(maxEffectiveDate) as EnrollmentEndDate, recordCount
into AllEnrollmentBeginEndDate
from tmp2AllEnrollmentEffectiveDate

-- find all who actived for longer than 1 year, and still active on '2016-01-01'
-- 15910238 records
drop table ValidEnrollmentBeginEndDate

Select *
into ValidEnrollmentBeginEndDate
from AllEnrollmentBeginEndDate
where recordCount >= 12
and EnrollmentEndDate > '2016-01-01'

Select top 100 * from ValidEnrollmentBeginEndDate
drop table ValidEnrollmentBeginEndDateAge

-- Add Birth Year into the table
Select A.*,
2018-B.BirthYear as Age
into  tmpValidEnrollmentBeginEndDateAge1
from ValidEnrollmentBeginEndDate A
inner join AetnaDataWarehouse.dbo.Members B on A.MemberId = B.MemberId
where B.BirthYear > 1900

Select A.*,
2018-B.BirthYear as Age 
into tmpValidEnrollmentBeginEndDateAge2
from ValidEnrollmentBeginEndDate A
inner join AetnaDataWarehouse_2016_2017.dbo.Members B on A.MemberId = B.MemberId
where B.BirthYear > 1900

-- Merge consistent results in Age from both databases 
-- 15900130 entries
Select A.*
into ValidEnrollmentBeginEndDateAge
from tmpValidEnrollmentBeginEndDateAge1 A
full outer join tmpValidEnrollmentBeginEndDateAge2 B on A.MemberId = B.MemberId
where A.Age = B.Age
or A.Age is null
or B.Age is null

-- Select All those whose age >= 45 by 2018
-- 6666688 entries
Select *
into ValidEnrollmentBeginEndDateAge45
from ValidEnrollmentBeginEndDateAge
where Age >= 45

-- Select candidate Smokers by Smoking Icd
select B.MemberId,
count(*) as countIcd
into tmpsmokerByIcd_fw
from  ValidEnrollmentBeginEndDateAge45 A
inner join AetnaDataWarehouse.dbo.FactIcd B on A.MemberId = B.MemberId
where (
   B.Icd in ('305.1', 'V15.82', 'F17.1', 'F17.2', 'Z72.0', 'Z86.43', 'Z87.891', 'T65.2', 'O99.33', '649.0')
or B.Icd like 'F17%'
or B.Icd like 'T65.2%'
or B.Icd like 'O99.33%'
or B.Icd like '649.0%'
) and B.DateServiceStarted > '1800-01-01'
group by B.MemberId

Insert into tmpsmokerByIcd_fw
select B.MemberId,
count(*) as countIcd
from  ValidEnrollmentBeginEndDateAge45 A
inner join AetnaDataWarehouse_2016_2017.dbo.FactIcd B on A.MemberId = B.MemberId
where (
   B.Icd in ('305.1', 'V15.82', 'F17.1', 'F17.2', 'Z72.0', 'Z86.43', 'Z87.891', 'T65.2', 'O99.33', '649.0')
or B.Icd like 'F17%'
or B.Icd like 'T65.2%'
or B.Icd like 'O99.33%'
or B.Icd like '649.0%'
) and B.DateServiceStarted > '1800-01-01'
group by B.MemberId

-- Merge two tables and record sum of each member's Icd count
-- 1015182 entries
select MemberId, sum(countIcd) as countIcd
into smokerByIcd_fw
from tmpsmokerByIcd_fw
group by MemberId

-- Select candidate Smokers by Drug Code
-- 38739
SELECT
P.MemberId, countDrug=COUNT(*), sm.ProprietaryName
INTO tmpsmokerByDrug
FROM ValidEnrollmentBeginEndDateAge45 A
inner join AetnaDataWarehouse.dbo.PharmacyClaims P
on A.MemberId=P.MemberId
INNER JOIN smokerDrug sm
ON P.NationalDrugCode = sm.NDCPackageCode
WHERE P.DispenseDate > '1800-01-01'
and P.MemberId is not null
GROUP BY
P.MemberId, sm.ProprietaryName
ORDER BY P.MemberId

Insert into tmpsmokerByDrug
Select
P.MemberId, countDrug=COUNT(*), sm.ProprietaryName
FROM ValidEnrollmentBeginEndDateAge45 A
inner join AetnaDataWarehouse_2016_2017.dbo.PharmacyClaims P
on A.MemberId=P.MemberId
INNER JOIN smokerDrug sm
ON P.NationalDrugCode = sm.NDCPackageCode
WHERE P.DispenseDate > '1800-01-01'
and P.MemberId is not null
GROUP BY
P.MemberId, sm.ProprietaryName
ORDER BY P.MemberId

--Merge two tables
select MemberId, sum(countDrug) as countDrug
into smokerByDrug_fw
from tmpsmokerByDrug
group by MemberId

-- 25206 both have Drug and Icd records
select count(distinct A.MemberId)
from smokerByDrug_fw A
inner join smokerbyIcd B
on A.MemberId = B.MemberId

-- Get count from each type of valid Heavy Smokers: Icd, Drug, Icd and Drug
Select count(distinct MemberId)
from smokerByIcd_fw
where countIcd>=10

Select count(distinct MemberId)
from smokerByDrug_fw
where countDrug>=3

Select count(distinct A.MemberId)
from smokerByDrug_fw A
inner join smokerByIcd_fw B
on A.MemberId = B.MemberId
where A.countDrug>=3
and B.countIcd>=10

-- Get the table of valid heavy smokers
SELECT
MemberId, countIcd as CountSmokingEntries
into tmpsmokerByIcdDrug_fw
from smokerByIcd_fw
Where countIcd>=10

Insert into tmpsmokerByIcdDrug_fw
SELECT
MemberId, countDrug as CountSmokingEntries
from smokerByDrug_fw
where countDrug>=3

-- Heavy smoker table
-- Total entries of both Icd and Drug (may not useful)
Select
MemberId, sum(CountSmokingEntries) as TotalSmokingEntries
into smokerByIcdDrug_fw
from tmpsmokerByIcdDrug_fw
group by MemberId

-- Get all heavy smokers with COPD
-- 1min
select B.MemberId, B.Icd
into tmpCopdPatients_fw
FROM smokerByIcdDrug_fw A
inner join AetnaDataWarehouse.dbo.FactIcd B 
on A.MemberId = B.MemberId
where B.Icd like '46[0-6]%'
or B.Icd like 'J4[0-7]%'

Insert into tmpCopdPatients_fw
select B.MemberId, B.Icd
FROM smokerByIcdDrug_fw A
inner join AetnaDataWarehouse_2016_2017.dbo.FactIcd B 
on A.MemberId = B.MemberId
where B.Icd like '46[0-6]%'
or B.Icd like 'J4[0-7]%'

-- Select All heavy smokers w/o COPD
-- 221746 entries
select A.*
into smokerNoCOPD_fw
FROM smokerByIcdDrug_fw A
left join tmpCopdPatients_fw B on A.MemberId = B.MemberId
where B.MemberId is null

-- Select All heavy smokers w/o COPD but with CVD
select B.MemberId, B.Icd
into NoCopdCVDPatients_fw
FROM smokerNoCOPD_fw A
inner join AetnaDataWarehouse.dbo.FactIcd B 
on A.MemberId = B.MemberId
where B.Icd like 'I[2-5][0-9]%'
or B.Icd like '4[1-2][0-9]%'

Insert into NoCopdCVDPatients_fw
select B.MemberId, B.Icd
FROM smokerNoCOPD_fw A
inner join AetnaDataWarehouse_2016_2017.dbo.FactIcd B 
on A.MemberId = B.MemberId
where B.Icd like 'I[2-5][0-9]%'
or B.Icd like '4[1-2][0-9]%'

-- Select All heavy smokers w/o COPD and CVD
-- 126247 entries
select A.*
into smokerNoCOPDCVD_fw
FROM smokerNoCOPD_fw A
left join NoCopdCVDPatients_fw B on A.MemberId = B.MemberId
where B.MemberId is null

drop table NoCopdNoCVDCancerPatients_fw
-- Select All heavy smokers w/o COPD and CVD but with cancer
select B.MemberId, B.Icd
into NoCopdNoCVDCancerPatients_fw
FROM smokerNoCOPDCVD_fw A
inner join AetnaDataWarehouse.dbo.FactIcd B 
on A.MemberId = B.MemberId
inner join cancerIcd C
on B.Icd = C.code

Insert into NoCopdNoCVDCancerPatients_fw
select B.MemberId, B.Icd
FROM smokerNoCOPDCVD_fw A
inner join AetnaDataWarehouse_2016_2017.dbo.FactIcd B 
on A.MemberId = B.MemberId
inner join cancerIcd C
on B.Icd = C.code

-- Select All heavy smokers w/o COPD, CVD and cancer
-- 103751 entries
select A.*
into smokerNoCOPDCVDCancer_fw
FROM smokerNoCOPDCVD_fw A
left join NoCopdNoCVDCancerPatients_fw B on A.MemberId = B.MemberId
where B.MemberId is null

-- Get total PaidAmount from each candidate
--1min
select A.MemberId, sum(B.PaidAmount) as PaidAmount
into tmpfinalsmoker_fw
from smokerNoCOPDCVDCancer_fw A
inner join AetnaDataWarehouse.dbo.MedicalClaims B
on A.MemberId = B.MemberID
where B.PaidAmount is not null
and B.PaidAmount >= 0
group by A.MemberId

Insert into tmpfinalsmoker_fw
select A.MemberId, sum(B.PaidAmount) as PaidAmount
from smokerNoCOPDCVDCancer_fw A
inner join AetnaDataWarehouse_2016_2017.dbo.MedicalClaims B
on A.MemberId = B.MemberID
where B.PaidAmount is not null
and B.PaidAmount >= 0
group by A.MemberId

select MemberId, sum(PaidAmount) as PaidAmount
into finalsmoker_fw
from tmpfinalsmoker_fw
group by MemberId

-- Get Average PaidAmount by day, and total EnrollDays
select A.*, B.Age as Age, B.Age/5 as AgeGroup,
Datediff(day, B.EnrollmentStartDate, B.EnrollmentEndDate)+1 as enrollDays,
1.0*A.PaidAmount/(Datediff(day, B.EnrollmentStartDate, B.EnrollmentEndDate)+1) as averagePaidAmount
into finalsmokerAge_fw
from finalsmoker_fw A
inner join ValidEnrollmentBeginEndDateAge B
on A.MemberId = B.MemberId

--Choose the lowest 10% by average 
With SlicedData as
(
select *,
NTILE(10) over(PARTITION BY AgeGroup order by averagePaidAmount) as Ntile
from finalsmokerAge_fw
where PaidAmount >= 0
)
select *
into lowestCostSmoker_fw
from SlicedData 
where Ntile = 1 

select AgeGroup, count(*)
from lowestCostSmoker_fw
group by AgeGroup
order by AgeGroup

