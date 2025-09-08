-- ================================
-- FIXED Attendance System Database Schema - Render Ready
-- ================================

-- Drop tables in reverse order of dependencies
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS attendance CASCADE;
DROP TABLE IF EXISTS schedule CASCADE;
DROP TABLE IF EXISTS teacher_sections CASCADE;
DROP TABLE IF EXISTS student_sections CASCADE;
DROP TABLE IF EXISTS classrooms CASCADE;
DROP TABLE IF EXISTS sections CASCADE;
DROP TABLE IF EXISTS persons CASCADE;

-- ================================
-- 1. Persons (Students + Teachers)
-- ================================
CREATE TABLE persons (
    person_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    rfid_tag VARCHAR(100) UNIQUE NOT NULL,
    role VARCHAR(20) CHECK (role IN ('student', 'teacher')) NOT NULL,
    id_number VARCHAR(20) UNIQUE,
    password VARCHAR(255),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'graduated')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================
-- 2. Users (For Authentication)
-- ================================
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(20) CHECK (role IN ('teacher','admin')) DEFAULT 'teacher',
    person_id INT REFERENCES persons(person_id) ON DELETE SET NULL,
    last_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================
-- 3. Sections
-- ================================
CREATE TABLE sections (
    section_id SERIAL PRIMARY KEY,
    section_name VARCHAR(50) UNIQUE NOT NULL,
    academic_year VARCHAR(20) DEFAULT '2024-25',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================
-- 4. Student → Section Mapping
-- ================================
CREATE TABLE student_sections (
    person_id INT REFERENCES persons(person_id) ON DELETE CASCADE,
    section_id INT REFERENCES sections(section_id) ON DELETE CASCADE,
    enrolled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (person_id, section_id)
);

-- ================================
-- 5. Teacher → Section Mapping
-- ================================
CREATE TABLE teacher_sections (
    person_id INT REFERENCES persons(person_id) ON DELETE CASCADE,
    section_id INT REFERENCES sections(section_id) ON DELETE CASCADE,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (person_id, section_id)
);

-- ================================
-- 6. Classrooms
-- ================================
CREATE TABLE classrooms (
    classroom_id SERIAL PRIMARY KEY,
    room_number VARCHAR(20) UNIQUE NOT NULL,
    building VARCHAR(50),
    capacity INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================
-- 7. Schedule (Flexible Timetable)
-- ================================
CREATE TABLE schedule (
    schedule_id SERIAL PRIMARY KEY,
    section_id INT REFERENCES sections(section_id) ON DELETE CASCADE,
    teacher_id INT REFERENCES persons(person_id) ON DELETE CASCADE,
    classroom_id INT REFERENCES classrooms(classroom_id) ON DELETE CASCADE,
    subject_name VARCHAR(100),
    day_of_week VARCHAR(10) CHECK (day_of_week IN 
        ('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    class_type VARCHAR(20) DEFAULT 'offline' CHECK (class_type IN ('offline', 'online', 'hybrid')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================
-- 8. Enhanced Attendance Logs
-- ================================
CREATE TABLE attendance (
    attendance_id SERIAL PRIMARY KEY,
    schedule_id INT REFERENCES schedule(schedule_id) ON DELETE CASCADE,
    person_id INT REFERENCES persons(person_id) ON DELETE CASCADE,
    rfid_tag VARCHAR(100),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(10) CHECK (status IN ('present', 'absent', 'late')) DEFAULT 'present',
    method VARCHAR(20) DEFAULT 'rfid' CHECK (method IN ('rfid', 'face', 'manual', 'zoom')),
    confidence_score FLOAT,
    location VARCHAR(50),
    notes TEXT,
    UNIQUE (schedule_id, person_id)
);

-- ================================
-- Add indexes for better performance
-- ================================
CREATE INDEX idx_attendance_schedule_id ON attendance(schedule_id);
CREATE INDEX idx_attendance_person_id ON attendance(person_id);
CREATE INDEX idx_attendance_timestamp ON attendance(timestamp);
CREATE INDEX idx_persons_rfid ON persons(rfid_tag);

-- ================================
-- Sample Data
-- ================================

-- Insert sample persons (your existing data)
INSERT INTO persons (name, rfid_tag, role, id_number, password) VALUES
('Nitin Singh', 'B2F7AF6A', 'student', '2500032073', '$2a$10$xqvlgnoqwdiIbauJrYUuC.aL34qhVoLaTeJ6yxqN6RMaLE0.FyCVK'),
('Abhijeet Arjeet', '717C423C', 'student', '2500031388', '$2a$10$Cl1HUEi42jS2R1NzRe9QVOSLF9Yg78fcUhPGa6sIm1pNwyOyaXev2'),
('Ayan Roy', '313F333D', 'student', '2500031529', '$2a$10$OIgEpa6yZ2.EpGywNklktuPBN6PRD53i5WA.7MB4yxqN6RMaLE0.FyCVK'),
('Pushkar Roy', 'B16C3A3D', 'student', '2500030922', '$2a$10$Jd3XYSVJGZ74ipriFZmbgO9OgFDqSTlEHQZXvnDDorUqMSVqZGPAy'),
('Raunak Gupta', '315F7C3C', 'student', '2500031322', '$2a$10$VQb1TVSy79xp.PXwQlIKPedk31Gzpi90pYm54UWrho5B1JmTLQpgu'),
('Aman Raj', 'D171283C', 'student', '2500030448', '$2a$10$LSY57RRT93/BxTt951ckROVJzMPexDlbawRehmmiGcUt77zkAR4bS'),
('Prateek Lohiya', '71A2463C', 'student', '2500032264', '$2a$10$8B6c2Hz8TWwZJCVmWue4herXLonmniMExgj3AxyI4JEMXa3qxIZVi'),
('Divyanshu Goyal', 'C1A82F3C', 'student', '2500031363', '$2a$10$uVY6MMSNkdE0C1yfe2Q4IONJWhZylwezVHhmyUpmUh4vRByn/d.Ny'),
('Ayush Kumar', '41F5263C', 'student', '2500032102', '$2a$10$yDUN3X6w5T3X6TD6lt/4Muq6NeZBMxtIHbDtIhQ0JA2CwQodCIN1S'),
('Dr. Teacher', 'TEACH001', 'teacher', 'T001', '$2a$10$iGjkALmc251rAC.B9GCCrez3cYD7xzhFYNP.bxiM2Uz7xKBtsNITy');

-- Insert sample users (for authentication)
INSERT INTO users (username, password, role, person_id) VALUES
('admin', '$2a$10$xqvlgnoqwdiIbauJrYUuC.aL34qhVoLaTeJ6yxqN6RMaLE0.FyCVK', 'admin', NULL),
('teacher', '$2a$10$iGjkALmc251rAC.B9GCCrez3cYD7xzhFYNP.bxiM2Uz7xKBtsNITy', 'teacher', 10);

-- Insert sections
INSERT INTO sections (section_name) VALUES
('S33'), ('S34'), ('S35'), ('S36'), ('S37'), ('S38'), ('S39'), ('S40'),
('S41'), ('S42'), ('S43'), ('S44'), ('S45'), ('S46'), ('S47'), ('S48'),
('S49'), ('S50'), ('S51'), ('S52');

-- Link students to sections
INSERT INTO student_sections (person_id, section_id) VALUES
(1, 1), (2, 1), (3, 1), (4, 1), (5, 2), (6, 2), (7, 2), (8, 2), (9, 2);

-- Link teacher to sections  
INSERT INTO teacher_sections (person_id, section_id) VALUES
(10, 1), (10, 2);

-- Insert sample classrooms
INSERT INTO classrooms (room_number, building, capacity) VALUES
('Room 101', 'Main Building', 40),
('Room 102', 'Main Building', 35),
('Room 103', 'Main Building', 45),
('Room 201', 'Science Block', 30),
('Room 202', 'Science Block', 25);

-- Insert sample schedule
INSERT INTO schedule (section_id, teacher_id, classroom_id, subject_name, day_of_week, start_time, end_time, class_type) VALUES
(1, 10, 1, 'Computer Science', 'Monday', '09:00:00', '10:30:00', 'offline'),
(1, 10, 2, 'Data Structures', 'Wednesday', '11:00:00', '12:30:00', 'offline'),
(2, 10, 2, 'Programming', 'Tuesday', '09:00:00', '10:30:00', 'offline'),
(1, 10, 3, 'Database Systems', 'Thursday', '14:00:00', '15:30:00', 'hybrid'),
(1, 10, 4, 'Software Engineering', 'Friday', '10:00:00', '11:30:00', 'online'),
(1, 10, 5, 'Mathematics', 'Saturday', '09:00:00', '10:30:00', 'offline'),
(1, 10, 1, 'Physics', 'Sunday', '09:00:00', '10:30:00', 'offline');
