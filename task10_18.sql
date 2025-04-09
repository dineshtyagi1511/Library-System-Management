
use library_db;

 -- Task 11. **Create a Table of Books with Rental Price Above a Certain Threshold**:  
CREATE TABLE expensive_books AS
SELECT * FROM books
WHERE rental_price > 7.00;  
  
 -- Task 12: **Retrieve the List of Books Not Yet Returned** 
SELECT * FROM issued_status AS ist
LEFT JOIN return_status AS rs
    ON rs.issued_id = ist.issued_id
WHERE rs.return_id IS NULL;

-- **Task 13: Identify Members with Overdue Books**  
-- Write a query to identify members who have overdue books (assume a 30-day return period). 
-- Display the member's_id, member's name, book title, issue date, and days overdue.
SELECT 
    ist.issued_member_id,
    m.member_name,
    bk.book_title,
    ist.issued_date,
    -- rs.return_date,
    DATEDIFF(CURRENT_DATE, ist.issued_date) AS overdue_days
FROM issued_status AS ist
JOIN members AS m
    ON m.member_id = ist.issued_member_id
JOIN books AS bk
    ON bk.isbn = ist.issued_book_isbn
LEFT JOIN return_status AS rs
    ON rs.issued_id = ist.issued_id
WHERE 
    rs.return_id IS NULL
    AND
    DATEDIFF(CURRENT_DATE, ist.issued_date) > 30
ORDER BY ist.issued_member_id;

-- **Task14: Update Book Status on Return**  
-- Write a query to update the status of books in the books table to "Yes" when they are returned (based on entries in the return_status table).

DELIMITER //

CREATE PROCEDURE add_return_records(
    IN p_return_id VARCHAR(10),
    IN p_issued_id VARCHAR(10),
    IN p_book_quality VARCHAR(10)
)
BEGIN
    DECLARE v_isbn VARCHAR(50);
    DECLARE v_book_name VARCHAR(80);
    
    -- Insert into returns based on user input
    INSERT INTO return_status(return_id, issued_id, return_date, book_quality)
    VALUES (p_return_id, p_issued_id, CURDATE(), p_book_quality);

    -- Get book details from issued status
    SELECT issued_book_isbn, issued_book_name
    INTO v_isbn, v_book_name
    FROM issued_status
    WHERE issued_id = p_issued_id;

    -- Update book availability status
    UPDATE books
    SET status = 'yes'
    WHERE isbn = v_isbn;

    -- Output confirmation message (MySQL uses SELECT instead of RAISE NOTICE)
    SELECT CONCAT('Thank you for returning the book: ', v_book_name) AS message;
END //

DELIMITER ;

-- Testing PROCEDURE add_return_records (MySQL doesn't use FUNCTION for this)

-- Check book status before
SELECT * FROM books
WHERE isbn = '978-0-307-58837-1';

-- Check issued status
SELECT * FROM issued_status
WHERE issued_book_isbn = '978-0-307-58837-1';

-- Check return status (should be empty for IS135 initially)
SELECT * FROM return_status
WHERE issued_id = 'IS135';

-- Calling procedure (MySQL uses CALL not SELECT for procedures)
CALL add_return_records('RS138', 'IS135', 'Good');

-- Verify the book status was updated
SELECT * FROM books
WHERE isbn = '978-0-307-58837-1';

-- Verify the return record was created
SELECT * FROM return_status
WHERE issued_id = 'IS135';

-- Call procedure for another record
CALL add_return_records('RS148', 'IS140', 'Good');

-- Verify the second return
SELECT * FROM return_status
WHERE issued_id = 'IS140';


-- **Task 15: Branch Performance Report**  
-- Create a query that generates a performance report for each branch, showing the number of books issued, 
-- the number of books returned, and the total revenue generated from book rentals.

CREATE TABLE branch_reports AS
SELECT 
    b.branch_id,
    b.manager_id,
    COUNT(ist.issued_id) AS number_book_issued,
    COUNT(rs.return_id) AS number_of_book_return,
    SUM(bk.rental_price) AS total_revenue
FROM issued_status AS ist
JOIN employees AS e
    ON e.emp_id = ist.issued_emp_id
JOIN branch AS b
    ON e.branch_id = b.branch_id
LEFT JOIN return_status AS rs
    ON rs.issued_id = ist.issued_id
JOIN books AS bk
    ON ist.issued_book_isbn = bk.isbn
GROUP BY b.branch_id, b.manager_id;

SELECT * FROM branch_reports;


-- **Task 16: CTAS: Create a Table of Active Members**  
-- Use the CREATE TABLE AS (CTAS) statement to create a new table active_members containing members
--  who have issued at least one book in the last 2 months.

CREATE TABLE active_members AS
SELECT * FROM members
WHERE member_id IN (
    SELECT DISTINCT issued_member_id   
    FROM issued_status
    WHERE issued_date >= CURRENT_DATE - INTERVAL 2 MONTH
);

SELECT * FROM active_members;

-- **Task 17: Find Employees with the Most Book Issues Processed**  
-- Write a query to find the top 3 employees who have processed the most book issues.
--  Display the employee name, number of books processed, and their branch.


SELECT 
    e.emp_name,
    b.*,
    COUNT(ist.issued_id) AS no_book_issued
FROM issued_status AS ist
JOIN employees AS e
    ON e.emp_id = ist.issued_emp_id
JOIN branch AS b
    ON e.branch_id = b.branch_id
GROUP BY e.emp_name, b.branch_id, b.manager_id, b.branch_address;

-- Objective:
-- Create a stored procedure to manage the status of books in a library system.
-- Description:
-- Write a stored procedure that updates the status of a book in the library based on its issuance. The procedure should function as follows:
-- The stored procedure should take the book_id as an input parameter.
-- The procedure should first check if the book is available (status = 'yes').
-- If the book is available, it should be issued, and the status in the books table should be updated to 'no'.
-- If the book is not available (status = 'no'), the procedure should return an error message indicating that the book is currently not available.


DELIMITER //

CREATE PROCEDURE issue_book(
    IN p_issued_id VARCHAR(10),
    IN p_issued_member_id VARCHAR(10),
    IN p_issued_book_isbn VARCHAR(20),
    IN p_issued_emp_id VARCHAR(10)
)
BEGIN
    DECLARE v_status VARCHAR(10);
    
    -- Check if book is available ('yes')
    SELECT status INTO v_status
    FROM books
    WHERE isbn = p_issued_book_isbn;
    
    IF v_status = 'yes' THEN
        -- Insert issue record
        INSERT INTO issued_status(issued_id, issued_member_id, issued_date, issued_book_isbn, issued_emp_id)
        VALUES (p_issued_id, p_issued_member_id, CURDATE(), p_issued_book_isbn, p_issued_emp_id);
        
        -- Update book status to unavailable
        UPDATE books
        SET status = 'no'
        WHERE isbn = p_issued_book_isbn;
        
        -- Return success message
        SELECT CONCAT('Book records added successfully for book isbn: ', p_issued_book_isbn) AS message;
    ELSE
        -- Return unavailable message
        SELECT CONCAT('Sorry to inform you the book you have requested is unavailable book_isbn: ', p_issued_book_isbn) AS message;
    END IF;
END //

DELIMITER ;

-- Testing the procedure
-- Check initial book statuses
SELECT * FROM books;
-- Note: "978-0-553-29698-2" has status 'yes'
--       "978-0-375-41398-8" has status 'no'

-- Check current issued books
SELECT * FROM issued_status;

-- Test 1: Try to issue an available book
CALL issue_book('IS155', 'C108', '978-0-553-29698-2', 'E104');

-- Test 2: Try to issue an unavailable book
CALL issue_book('IS156', 'C108', '978-0-375-41398-8', 'E104');

-- Verify the book status changes
SELECT * FROM books
WHERE isbn = '978-0-553-29698-2' OR isbn = '978-0-375-41398-8';

-- Check if new records were added to issued_status
SELECT * FROM issued_status
WHERE issued_id IN ('IS155', 'IS156');

-- Verify the unavailable book wasn't issued
SELECT * FROM issued_status
WHERE issued_book_isbn = '978-0-375-41398-8';