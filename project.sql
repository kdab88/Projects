
#STATEMENT-1

WITH PrescriptionDetails AS (
    SELECT
        p.pharmacyID,
        p.treatmentID,
        m.hospitalExclusive,
        c.quantity
    FROM healthcare.prescription p
    JOIN healthcare.treatment t ON p.treatmentID = t.treatmentID
    JOIN healthcare.contain c ON p.prescriptionID = c.prescriptionID
    JOIN healthcare.medicine m ON c.medicineID = m.medicineID
    WHERE t.date BETWEEN '2022-01-01' AND '2022-12-31'
),
PharmacyMedicineQuantities AS (
    SELECT
        pd.pharmacyID,
        SUM(pd.quantity) AS totalQuantity,
        SUM(CASE WHEN pd.hospitalExclusive = 0 THEN pd.quantity ELSE 0 END) AS hospitalExclusiveQuantity
    FROM PrescriptionDetails pd
    GROUP BY pd.pharmacyID
),
PharmacyDetails AS (
    SELECT
        ph.pharmacyID,
        ph.pharmacyName,
        pmq.totalQuantity,
        pmq.hospitalExclusiveQuantity,
        (pmq.hospitalExclusiveQuantity / NULLIF(pmq.totalQuantity, 0)) * 100 AS percentageHospitalExclusive
    FROM healthcare.pharmacy ph
    JOIN PharmacyMedicineQuantities pmq ON ph.pharmacyID = pmq.pharmacyID
)
SELECT
    pharmacyID,
    pharmacyName,
    totalQuantity,
    hospitalExclusiveQuantity,
    percentageHospitalExclusive
FROM PharmacyDetails
ORDER BY percentageHospitalExclusive DESC;


-------------------------

#STATEMENT-2

WITH TreatmentClaimStatus AS (
    -- Join treatments with claims to identify if a treatment has an associated claim
    SELECT
        t.treatmentID,
        a.state,
        CASE
            WHEN c.claimID IS NOT NULL THEN 'With Claim'
            ELSE 'Without Claim'
        END AS Claim_Status
    FROM healthcare.treatment t
    LEFT JOIN healthcare.claim c ON t.claimID = c.claimID
    JOIN healthcare.patient pt ON t.patientID = pt.patientID
    JOIN healthcare.person p ON pt.patientID = p.personID
    JOIN healthcare.address a ON p.addressID = a.addressID
    WHERE t.date BETWEEN '2022-01-01' AND '2022-12-31'
),

TreatmentCounts AS (
    -- Count the total number of treatments and those without claims for each state
    SELECT
        state,
        COUNT(*) AS Total_Treatments,
        SUM(CASE WHEN Claim_Status = 'Without Claim' THEN 1 ELSE 0 END) AS Treatments_Without_Claim
    FROM TreatmentClaimStatus
    GROUP BY state
),

PercentageWithoutClaims AS (
    -- Calculate the percentage of treatments without claims for each state
    SELECT
        state,
        Total_Treatments,
        Treatments_Without_Claim,
        (100.0 * Treatments_Without_Claim / Total_Treatments) AS Percentage_Without_Claim
    FROM TreatmentCounts
)

-- Final report
SELECT
    state AS State,
    Total_Treatments AS Total_Treatments,
    Treatments_Without_Claim AS Treatments_Without_Claim,
    ROUND(Percentage_Without_Claim, 2) AS Percentage_Without_Claim
FROM PercentageWithoutClaims;

--------------------
    
# STATEMENT-3

-- Step 1: Aggregate the number of cases treated for each disease by state
WITH DiseaseTreatmentCount AS (
    SELECT
        a.state AS State,
        d.diseaseName AS Disease,
        COUNT(t.treatmentID) AS Number_of_Cases
    FROM healthcare.treatment t
    JOIN healthcare.disease d ON t.diseaseID = d.diseaseID
    JOIN healthcare.patient pt ON t.patientID = pt.patientID
    JOIN healthcare.person p ON pt.patientID = p.personID
    JOIN healthcare.address a ON p.addressID = a.addressID
    WHERE t.date BETWEEN '2022-01-01' AND '2022-12-31'
    GROUP BY a.state, d.diseaseName
),

-- Step 2: Find the maximum number of cases for each state
MaxCases AS (
    SELECT
        State,
        MAX(Number_of_Cases) AS Max_Cases
    FROM DiseaseTreatmentCount
    GROUP BY State
),

-- Step 3: Find the minimum number of cases for each state
MinCases AS (
    SELECT
        State,
        MIN(Number_of_Cases) AS Min_Cases
    FROM DiseaseTreatmentCount
    GROUP BY State
),

-- Step 4: Identify the most treated diseases by joining with the MaxCases CTE
MostTreated AS (
    SELECT
        dtc.State,
        dtc.Disease AS Most_Treated_Disease,
        dtc.Number_of_Cases AS Number_of_Cases_Most_Treated
    FROM DiseaseTreatmentCount dtc
    JOIN MaxCases mc ON dtc.State = mc.State AND dtc.Number_of_Cases = mc.Max_Cases
),

-- Step 5: Identify the least treated diseases by joining with the MinCases CTE
LeastTreated AS (
    SELECT
        dtc.State,
        dtc.Disease AS Least_Treated_Disease,
        dtc.Number_of_Cases AS Number_of_Cases_Least_Treated
    FROM DiseaseTreatmentCount dtc
    JOIN MinCases mc ON dtc.State = mc.State AND dtc.Number_of_Cases = mc.Min_Cases
)

-- Step 6: Combine results to get a single report
SELECT
    mt.State,
    mt.Most_Treated_Disease,
    mt.Number_of_Cases_Most_Treated,
    lt.Least_Treated_Disease,
    lt.Number_of_Cases_Least_Treated
FROM MostTreated mt
JOIN LeastTreated lt ON mt.State = lt.State;




#STATEMENT-4

WITH CityCounts AS (
    SELECT
        a.city,
        COUNT(*) AS totalRegisteredPeople
    FROM healthcare.person p
    JOIN healthcare.address a ON p.addressID = a.addressID
    GROUP BY a.city
    HAVING COUNT(*) >= 10
),
PatientCounts AS (
    SELECT
        a.city,
        COUNT(*) AS patientCount
    FROM healthcare.person p
    JOIN healthcare.patient pt ON p.personID = pt.patientID
    JOIN healthcare.address a ON p.addressID = a.addressID
    GROUP BY a.city
),
CityPatientStats AS (
    SELECT
        cc.city,
        cc.totalRegisteredPeople,
        COALESCE(pc.patientCount, 0) AS patientCount,
        (COALESCE(pc.patientCount, 0) / NULLIF(cc.totalRegisteredPeople, 0)) * 100 AS percentagePatients
    FROM CityCounts cc
    LEFT JOIN PatientCounts pc ON cc.city = pc.city
)
SELECT
    City,
    TotalRegisteredPeople,
    PatientCount,
    PercentagePatients
FROM CityPatientStats
ORDER BY city;




#STATEMENT-5

-- Step 1: Count the number of medicines containing "ranitidine" (case-insensitive) for each company
WITH MedicineCounts AS (
    SELECT
        m.companyName,
        COUNT(*) AS medicineCount
    FROM healthcare.medicine m
    WHERE LOWER(m.substanceName) = 'ranitidina'
    GROUP BY m.companyName
),

-- Step 2: Rank the companies based on the count of medicines
RankedCompanies AS (
    SELECT
        companyName,
        medicineCount,
        ROW_NUMBER() OVER (ORDER BY medicineCount DESC) AS companyRank
    FROM MedicineCounts
)

-- Step 3: Select the top 3 companies with their rank
SELECT
    companyName,
    medicineCount,
    companyRank
FROM RankedCompanies
WHERE companyRank <= 3
ORDER BY companyRank;