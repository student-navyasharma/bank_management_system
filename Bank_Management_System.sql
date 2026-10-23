DROP DATABASE IF EXISTS bank_db;
CREATE DATABASE bank_db;
USE bank_db;

CREATE TABLE branches (
    branch_id     INT AUTO_INCREMENT PRIMARY KEY,
    branch_name   VARCHAR(50)  NOT NULL,
    city          VARCHAR(50)  NOT NULL,
    ifsc_code     VARCHAR(11)  NOT NULL UNIQUE,
    opened_on     DATE         NOT NULL
);

CREATE TABLE customers (
    customer_id   INT AUTO_INCREMENT PRIMARY KEY,
    first_name    VARCHAR(30)  NOT NULL,
    last_name     VARCHAR(30)  NOT NULL,
    dob           DATE         NOT NULL,
    gender        ENUM('M','F','O') NOT NULL,
    phone         VARCHAR(10)  NOT NULL UNIQUE,
    email         VARCHAR(60)  UNIQUE,
    city          VARCHAR(50),
    joined_on     DATE         NOT NULL DEFAULT (CURRENT_DATE)
);

CREATE TABLE accounts (
    account_id    INT AUTO_INCREMENT PRIMARY KEY,
    customer_id   INT           NOT NULL,
    branch_id     INT           NOT NULL,
    account_type  ENUM('SAVINGS','CURRENT') NOT NULL,
    balance       DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    status        ENUM('ACTIVE','CLOSED','FROZEN') NOT NULL DEFAULT 'ACTIVE',
    opened_on     DATE          NOT NULL,
    CONSTRAINT chk_balance CHECK (balance >= 0),
    CONSTRAINT fk_acc_customer FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id) ON DELETE CASCADE,
    CONSTRAINT fk_acc_branch FOREIGN KEY (branch_id)
        REFERENCES branches(branch_id) ON DELETE RESTRICT
) AUTO_INCREMENT = 1001;

CREATE TABLE transactions (
    txn_id        INT AUTO_INCREMENT PRIMARY KEY,
    account_id    INT           NOT NULL,
    txn_type      ENUM('DEPOSIT','WITHDRAWAL','TRANSFER_IN','TRANSFER_OUT') NOT NULL,
    amount        DECIMAL(12,2) NOT NULL,
    txn_date      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    description   VARCHAR(100),
    CONSTRAINT chk_amount CHECK (amount > 0),
    CONSTRAINT fk_txn_account FOREIGN KEY (account_id)
        REFERENCES accounts(account_id) ON DELETE CASCADE
);

CREATE TABLE loans (
    loan_id        INT AUTO_INCREMENT PRIMARY KEY,
    customer_id    INT           NOT NULL,
    branch_id      INT           NOT NULL,
    loan_type      ENUM('HOME','CAR','EDUCATION','PERSONAL') NOT NULL,
    principal      DECIMAL(12,2) NOT NULL,
    interest_rate  DECIMAL(4,2)  NOT NULL,
    tenure_months  INT           NOT NULL,
    status         ENUM('PENDING','ACTIVE','CLOSED') NOT NULL DEFAULT 'PENDING',
    issue_date     DATE,
    CONSTRAINT chk_principal CHECK (principal > 0),
    CONSTRAINT fk_loan_customer FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id) ON DELETE CASCADE,
    CONSTRAINT fk_loan_branch FOREIGN KEY (branch_id)
        REFERENCES branches(branch_id) ON DELETE RESTRICT
);

CREATE INDEX idx_txn_account_date ON transactions(account_id, txn_date);

DELIMITER $$

CREATE TRIGGER trg_check_balance
BEFORE INSERT ON transactions
FOR EACH ROW
BEGIN
    DECLARE v_balance DECIMAL(12,2);

    IF NEW.txn_type IN ('WITHDRAWAL','TRANSFER_OUT') THEN
        SELECT balance INTO v_balance
        FROM accounts
        WHERE account_id = NEW.account_id;

        IF NEW.amount > v_balance THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Insufficient balance for this transaction';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_update_balance
AFTER INSERT ON transactions
FOR EACH ROW
BEGIN
    IF NEW.txn_type IN ('DEPOSIT','TRANSFER_IN') THEN
        UPDATE accounts
        SET balance = balance + NEW.amount
        WHERE account_id = NEW.account_id;
    ELSE
        UPDATE accounts
        SET balance = balance - NEW.amount
        WHERE account_id = NEW.account_id;
    END IF;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE transfer_money(
    IN p_from_acc INT,
    IN p_to_acc   INT,
    IN p_amount   DECIMAL(12,2)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    INSERT INTO transactions (account_id, txn_type, amount, description)
    VALUES (p_from_acc, 'TRANSFER_OUT', p_amount,
            CONCAT('Transfer to account ', p_to_acc));

    INSERT INTO transactions (account_id, txn_type, amount, description)
    VALUES (p_to_acc, 'TRANSFER_IN', p_amount,
            CONCAT('Transfer from account ', p_from_acc));

    COMMIT;
END$$

DELIMITER ;

INSERT INTO branches (branch_name, city, ifsc_code, opened_on) VALUES
('Patiala Main',   'Patiala',    'BNKP0001001', '2008-04-12'),
('Chandigarh Sec17','Chandigarh','BNKC0001017', '2012-09-01'),
('Ludhiana Model Town','Ludhiana','BNKL0001055', '2015-01-20');

INSERT INTO customers (first_name, last_name, dob, gender, phone, email, city, joined_on) VALUES
('Aarav',  'Sharma',  '1998-03-14', 'M', '9876500001', 'aarav.sharma@mail.com',  'Patiala',    '2021-06-10'),
('Simran', 'Kaur',    '1995-11-02', 'F', '9876500002', 'simran.kaur@mail.com',   'Chandigarh', '2020-01-18'),
('Rohan',  'Verma',   '1990-07-25', 'M', '9876500003', 'rohan.verma@mail.com',   'Ludhiana',   '2019-08-05'),
('Priya',  'Singh',   '2000-01-30', 'F', '9876500004', 'priya.singh@mail.com',   'Patiala',    '2022-02-14'),
('Karan',  'Mehta',   '1987-09-09', 'M', '9876500005', 'karan.mehta@mail.com',   'Chandigarh', '2018-11-22'),
('Neha',   'Gupta',   '1993-05-17', 'F', '9876500006', 'neha.gupta@mail.com',    'Ludhiana',   '2021-03-03'),
('Arjun',  'Malhotra','1985-12-21', 'M', '9876500007', 'arjun.malhotra@mail.com','Patiala',    '2017-07-30'),
('Ishita', 'Bansal',  '1999-08-08', 'F', '9876500008', 'ishita.bansal@mail.com', 'Chandigarh', '2023-01-09');

INSERT INTO accounts (customer_id, branch_id, account_type, opened_on) VALUES
(1, 1, 'SAVINGS', '2021-06-10'),
(2, 2, 'SAVINGS', '2020-01-18'),
(3, 3, 'SAVINGS', '2019-08-05'),
(4, 1, 'SAVINGS', '2022-02-14'),
(5, 2, 'CURRENT', '2018-11-22'),
(6, 3, 'SAVINGS', '2021-03-03'),
(7, 1, 'SAVINGS', '2017-07-30'),
(8, 2, 'SAVINGS', '2023-01-09'),
(1, 1, 'CURRENT', '2022-05-01'),
(3, 3, 'CURRENT', '2020-10-12');

INSERT INTO transactions (account_id, txn_type, amount, txn_date, description) VALUES
(1001, 'DEPOSIT',    50000.00,  '2026-01-05 10:15:00', 'Salary credit'),
(1001, 'DEPOSIT',    15000.00,  '2026-02-03 11:40:00', 'Cash deposit'),
(1001, 'WITHDRAWAL',  5000.00,  '2026-02-10 18:05:00', 'ATM withdrawal'),
(1002, 'DEPOSIT',   120000.00,  '2026-01-12 09:30:00', 'Salary credit'),
(1002, 'WITHDRAWAL', 20000.00,  '2026-02-15 14:20:00', 'Rent payment'),
(1003, 'DEPOSIT',    30000.00,  '2026-01-20 12:00:00', 'Cash deposit'),
(1004, 'DEPOSIT',    75000.00,  '2026-02-01 10:00:00', 'Scholarship credit'),
(1004, 'WITHDRAWAL', 10000.00,  '2026-03-04 16:45:00', 'ATM withdrawal'),
(1005, 'DEPOSIT',   200000.00,  '2026-01-08 15:10:00', 'Business income'),
(1006, 'DEPOSIT',    18000.00,  '2026-02-22 13:25:00', 'Cash deposit'),
(1007, 'DEPOSIT',    60000.00,  '2026-03-01 09:50:00', 'Salary credit'),
(1008, 'DEPOSIT',    90000.00,  '2026-03-05 11:15:00', 'Salary credit'),
(1009, 'DEPOSIT',   250000.00,  '2026-03-10 17:30:00', 'Business income'),
(1010, 'DEPOSIT',    45000.00,  '2026-03-12 10:45:00', 'Cheque deposit'),
(1005, 'WITHDRAWAL', 35000.00,  '2026-03-18 12:10:00', 'Vendor payment'),
(1007, 'WITHDRAWAL', 15000.00,  '2026-03-25 19:00:00', 'Bill payments');

CALL transfer_money(1001, 1003, 5000.00);
CALL transfer_money(1002, 1004, 10000.00);
CALL transfer_money(1005, 1009, 25000.00);
CALL transfer_money(1008, 1006, 7500.00);

INSERT INTO loans (customer_id, branch_id, loan_type, principal, interest_rate, tenure_months, status, issue_date) VALUES
(1, 1, 'EDUCATION', 400000.00,  8.50,  60, 'ACTIVE',  '2023-07-01'),
(2, 2, 'HOME',     3500000.00,  7.25, 240, 'ACTIVE',  '2021-04-15'),
(3, 3, 'CAR',       650000.00,  9.10,  48, 'ACTIVE',  '2024-02-10'),
(5, 2, 'PERSONAL',  200000.00, 11.50,  24, 'CLOSED',  '2022-06-20'),
(7, 1, 'HOME',     2800000.00,  7.40, 180, 'ACTIVE',  '2020-09-05'),
(4, 1, 'EDUCATION', 300000.00,  8.75,  48, 'PENDING', NULL);

UPDATE customers SET city = 'Mohali' WHERE customer_id = 8;
UPDATE accounts  SET status = 'FROZEN' WHERE account_id = 1006;
UPDATE accounts  SET status = 'ACTIVE' WHERE account_id = 1006;

CREATE VIEW vw_account_summary AS
SELECT  a.account_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        a.account_type,
        b.branch_name,
        a.balance,
        a.status
FROM accounts a
JOIN customers c ON a.customer_id = c.customer_id
JOIN branches  b ON a.branch_id   = b.branch_id;

CREATE VIEW vw_customer_total_balance AS
SELECT  c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        COUNT(a.account_id) AS total_accounts,
        SUM(a.balance)      AS total_balance
FROM customers c
LEFT JOIN accounts a ON c.customer_id = a.customer_id
GROUP BY c.customer_id, customer_name;

SELECT * FROM vw_account_summary;

SELECT * FROM vw_customer_total_balance
ORDER BY total_balance DESC;

SELECT txn_id, txn_type, amount, txn_date, description
FROM transactions
WHERE account_id = 1001
ORDER BY txn_date;

SELECT  b.branch_name,
        COUNT(a.account_id) AS total_accounts,
        SUM(a.balance)      AS total_balance
FROM branches b
LEFT JOIN accounts a ON b.branch_id = a.branch_id
GROUP BY b.branch_id, b.branch_name
ORDER BY total_balance DESC;

SELECT customer_name, total_balance
FROM vw_customer_total_balance
WHERE total_balance > (SELECT AVG(total_balance) FROM vw_customer_total_balance);

SELECT c.customer_id, c.first_name, c.last_name
FROM customers c
LEFT JOIN loans l ON c.customer_id = l.customer_id
WHERE l.loan_id IS NULL;

SELECT  l.loan_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        l.loan_type,
        l.principal,
        l.interest_rate,
        l.status,
        b.branch_name
FROM loans l
JOIN customers c ON l.customer_id = c.customer_id
JOIN branches  b ON l.branch_id   = b.branch_id;

SELECT loan_type, COUNT(*) AS no_of_loans, SUM(principal) AS total_principal
FROM loans
WHERE status = 'ACTIVE'
GROUP BY loan_type
HAVING SUM(principal) > 500000
ORDER BY total_principal DESC;

SELECT  DATE_FORMAT(txn_date, '%Y-%m') AS month,
        SUM(CASE WHEN txn_type = 'DEPOSIT'    THEN amount ELSE 0 END) AS total_deposits,
        SUM(CASE WHEN txn_type = 'WITHDRAWAL' THEN amount ELSE 0 END) AS total_withdrawals
FROM transactions
GROUP BY DATE_FORMAT(txn_date, '%Y-%m')
ORDER BY month;

SELECT  b.branch_name,
        a.account_id,
        a.balance,
        RANK() OVER (PARTITION BY b.branch_id ORDER BY a.balance DESC) AS balance_rank
FROM accounts a
JOIN branches b ON a.branch_id = b.branch_id;

WITH txn_count AS (
    SELECT a.customer_id, COUNT(t.txn_id) AS total_txns
    FROM accounts a
    JOIN transactions t ON a.account_id = t.account_id
    GROUP BY a.customer_id
)
SELECT CONCAT(c.first_name, ' ', c.last_name) AS customer_name, tc.total_txns
FROM txn_count tc
JOIN customers c ON tc.customer_id = c.customer_id
ORDER BY tc.total_txns DESC
LIMIT 3;

SELECT  c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        COUNT(a.account_id) AS accounts_held
FROM customers c
JOIN accounts a ON c.customer_id = a.customer_id
GROUP BY c.customer_id, customer_name
HAVING COUNT(a.account_id) > 1;

SELECT a.account_id, MAX(t.txn_date) AS last_txn
FROM accounts a
LEFT JOIN transactions t ON a.account_id = t.account_id
GROUP BY a.account_id
HAVING last_txn < (SELECT MAX(txn_date) FROM transactions) - INTERVAL 30 DAY
    OR last_txn IS NULL;
