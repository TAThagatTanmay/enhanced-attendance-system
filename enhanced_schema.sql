-- ================================
-- ENHANCED Attendance System Database Schema WITH FACE RECOGNITION
-- ================================
-- Drop tables in reverse order of dependencies (for clean rebuilds)
DROP TABLE IF EXISTS face_recognition_logs CASCADE;
DROP TABLE IF EXISTS attendance_analytics CASCADE;
DROP TABLE IF EXISTS zoom_sessions CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS attendance CASCADE;
DROP TABLE IF EXISTS schedule CASCADE;
DROP TABLE IF EXISTS teacher_sections CASCADE;
DROP TABLE IF EXISTS student_sections CASCADE;
DROP TABLE IF EXISTS classrooms CASCADE;
DROP TABLE IF EXISTS sections CASCADE;
DROP TABLE IF EXISTS persons CASCADE;

-- ================================
-- 1. Enhanced Persons (Students + Teachers) WITH FACE ENCODING
-- ================================
CREATE TABLE persons (
    person_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    rfid_tag VARCHAR(100) UNIQUE NOT NULL,
    role VARCHAR(20) CHECK (role IN ('student', 'teacher')) NOT NULL,
    id_number VARCHAR(20) UNIQUE,
    password VARCHAR(255),
    face_encoding BYTEA,  -- Store 128-dim face encoding as binary
    face_image_path VARCHAR(255),  -- Optional reference image path
    face_registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    face_last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'graduated'))
);

-- ================================
-- 2. Users (For Authentication) - Enhanced
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
-- 3. Sections - Enhanced
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
-- 6. Classrooms - Enhanced
-- ================================
CREATE TABLE classrooms (
    classroom_id SERIAL PRIMARY KEY,
    room_number VARCHAR(20) UNIQUE NOT NULL,
    building VARCHAR(50),
    capacity INT,
    has_camera BOOLEAN DEFAULT false,  -- For face recognition capability
    camera_ip VARCHAR(100),  -- IP camera address if available
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================
-- 7. Schedule (Flexible Timetable) - Enhanced
-- ================================
CREATE TABLE schedule (
    schedule_id SERIAL PRIMARY KEY,
    section_id INT REFERENCES sections(section_id) ON DELETE CASCADE,
    teacher_id INT REFERENCES persons(person_id) ON DELETE CASCADE,
    classroom_id INT REFERENCES classrooms(classroom_id) ON DELETE CASCADE,
    subject_name VARCHAR(100),  -- Subject being taught
    day_of_week VARCHAR(10) CHECK (day_of_week IN 
        ('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    class_type VARCHAR(20) DEFAULT 'offline' CHECK (class_type IN ('offline', 'online', 'hybrid')),
    zoom_meeting_id VARCHAR(100),  -- For online classes
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================
-- 8. Enhanced Attendance Logs WITH FACE RECOGNITION
-- ================================
CREATE TABLE attendance (
    attendance_id SERIAL PRIMARY KEY,
    schedule_id INT REFERENCES schedule(schedule_id) ON DELETE CASCADE,
    person_id INT REFERENCES persons(person_id) ON DELETE CASCADE,
    rfid_tag VARCHAR(100),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(10) CHECK (status IN ('present', 'absent', 'late')) DEFAULT 'present',
    method VARCHAR(20) DEFAULT 'rfid' CHECK (method IN ('rfid', 'face', 'manual', 'zoom')),
    confidence_score FLOAT,  -- Face recognition confidence (0.0-1.0)
    location VARCHAR(50),  -- 'classroom', 'zoom', 'mobile'
    ip_address INET,  -- For tracking location/device
    notes TEXT,
    UNIQUE (schedule_id, person_id) -- prevents duplicates per student per class
);

-- ================================
-- 9. NEW: Zoom Session Tracking
-- ================================
CREATE TABLE zoom_sessions (
    session_id SERIAL PRIMARY KEY,
    schedule_id INT REFERENCES schedule(schedule_id) ON DELETE CASCADE,
    zoom_meeting_id VARCHAR(100) NOT NULL,
    session_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    session_end TIMESTAMP,
    total_participants INT DEFAULT 0,
    face_recognition_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================
-- 10. NEW: Face Recognition Logs (For Debugging/Audit)
-- ================================
CREATE TABLE face_recognition_logs (
    log_id SERIAL PRIMARY KEY,
    person_id INT REFERENCES persons(person_id) ON DELETE SET NULL,
    session_type VARCHAR(20) CHECK (session_type IN ('classroom', 'zoom', 'registration')),
    recognition_result VARCHAR(20) CHECK (recognition_result IN ('success', 'failed', 'no_face', 'multiple_faces')),
    confidence_score FLOAT,
    image_path VARCHAR(255),  -- Path to processed image (if stored)
    processing_time_ms INT,  -- Time taken for recognition
    error_message TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================
-- 11. NEW: Attendance Analytics (Pre-computed for Dashboard)
-- ================================
CREATE TABLE attendance_analytics (
    analytics_id SERIAL PRIMARY KEY,
    person_id INT REFERENCES persons(person_id) ON DELETE CASCADE,
    section_id INT REFERENCES sections(section_id) ON DELETE CASCADE,
    date DATE NOT NULL,
    total_classes INT DEFAULT 0,
    attended_classes INT DEFAULT 0,
    attendance_percentage FLOAT GENERATED ALWAYS AS (
        CASE WHEN total_classes > 0 THEN (attended_classes::FLOAT / total_classes) * 100 ELSE 0 END
    ) STORED,
    rfid_scans INT DEFAULT 0,
    face_recognitions INT DEFAULT 0,
    zoom_attendances INT DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (person_id, date)
);

-- ================================
-- Add indexes for better performance
-- ================================
CREATE INDEX idx_attendance_schedule_id ON attendance(schedule_id);
CREATE INDEX idx_attendance_person_id ON attendance(person_id);
CREATE INDEX idx_attendance_timestamp ON attendance(timestamp);
CREATE INDEX idx_attendance_method ON attendance(method);
CREATE INDEX idx_face_encoding_person ON persons(person_id) WHERE face_encoding IS NOT NULL;
CREATE INDEX idx_zoom_sessions_schedule ON zoom_sessions(schedule_id);
CREATE INDEX idx_face_logs_timestamp ON face_recognition_logs(timestamp);
CREATE INDEX idx_analytics_date ON attendance_analytics(date);
CREATE INDEX idx_analytics_person_date ON attendance_analytics(person_id, date);

-- ================================
-- Create Views for Easy Reporting
-- ================================

-- Daily attendance summary view
CREATE VIEW daily_attendance_summary AS
SELECT 
    a.schedule_id,
    s.section_name,
    s.subject_name,
    sc.day_of_week,
    DATE(a.timestamp) as attendance_date,
    COUNT(*) as total_present,
    COUNT(CASE WHEN a.method = 'rfid' THEN 1 END) as rfid_count,
    COUNT(CASE WHEN a.method = 'face' THEN 1 END) as face_count,
    COUNT(CASE WHEN a.method = 'zoom' THEN 1 END) as zoom_count,
    AVG(CASE WHEN a.confidence_score IS NOT NULL THEN a.confidence_score END) as avg_confidence
FROM attendance a
JOIN schedule sc ON a.schedule_id = sc.schedule_id
JOIN sections s ON sc.section_id = s.section_id
WHERE a.status = 'present'
GROUP BY a.schedule_id, s.section_name, s.subject_name, sc.day_of_week, DATE(a.timestamp);

-- Student attendance analytics view
CREATE VIEW student_attendance_stats AS
SELECT 
    p.person_id,
    p.name,
    p.id_number,
    s.section_name,
    COUNT(a.attendance_id) as total_attendances,
    COUNT(CASE WHEN a.method = 'rfid' THEN 1 END) as rfid_attendances,
    COUNT(CASE WHEN a.method = 'face' THEN 1 END) as face_attendances,
    COUNT(CASE WHEN a.method = 'zoom' THEN 1 END) as zoom_attendances,
    ROUND(AVG(CASE WHEN a.confidence_score IS NOT NULL THEN a.confidence_score END)::numeric, 3) as avg_face_confidence,
    CASE WHEN p.face_encoding IS NOT NULL THEN 'Yes' ELSE 'No' END as face_registered
FROM persons p
JOIN student_sections ss ON p.person_id = ss.person_id
JOIN sections s ON ss.section_id = s.section_id
LEFT JOIN attendance a ON p.person_id = a.person_id
WHERE p.role = 'student'
GROUP BY p.person_id, p.name, p.id_number, s.section_name, p.face_encoding;

-- ================================
-- Sample Data with Face Recognition Support
-- ================================
-- Insert sample persons (keeping existing data)
INSERT INTO persons (name, rfid_tag, role, id_number, password) VALUES
('Nitin Singh', 'B2F7AF6A', 'student', '2500032073', '$2a$10$xqvlgnoqwdiIbauJrYUuC.aL34qhVoLaTeJ6yxqN6RMaLE0.FyCVK'),
('Abhijeet Arjeet', '717C423C', 'student', '2500031388', '$2a$10$Cl1HUEi42jS2R1NzRe9QVOSLF9Yg78fcUhPGa6sIm1pNwyOyaXev2'),
('Ayan Roy', '313F333D', 'student', '2500031529', '$2a$10$OIgEpa6yZ2.EpGywNklktuPBN6PRD53i5WA.7MB4yy3TM0A9yxHNS'),
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

-- Insert sample classrooms with camera capability
INSERT INTO classrooms (room_number, building, capacity, has_camera) VALUES
('Room 101', 'Main Building', 40, true),
('Room 102', 'Main Building', 35, true),
('Room 103', 'Main Building', 45, false),
('Room 201', 'Science Block', 30, true),
('Room 202', 'Science Block', 25, false);

-- Insert enhanced schedule with online/offline support
INSERT INTO schedule (section_id, teacher_id, classroom_id, subject_name, day_of_week, start_time, end_time, class_type) VALUES
(1, 10, 1, 'Computer Science', 'Monday', '09:00:00', '10:30:00', 'offline'),
(1, 10, 2, 'Data Structures', 'Wednesday', '11:00:00', '12:30:00', 'offline'),
(2, 10, 2, 'Programming', 'Tuesday', '09:00:00', '10:30:00', 'offline'),
(1, 10, 3, 'Database Systems', 'Thursday', '14:00:00', '15:30:00', 'hybrid'),
(1, 10, 4, 'Software Engineering', 'Friday', '10:00:00', '11:30:00', 'online');

-- Create function to update analytics automatically
CREATE OR REPLACE FUNCTION update_attendance_analytics()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO attendance_analytics (person_id, section_id, date, total_classes, attended_classes, rfid_scans, face_recognitions, zoom_attendances)
    SELECT 
        NEW.person_id,
        sc.section_id,
        DATE(NEW.timestamp),
        1,
        CASE WHEN NEW.status = 'present' THEN 1 ELSE 0 END,
        CASE WHEN NEW.method = 'rfid' AND NEW.status = 'present' THEN 1 ELSE 0 END,
        CASE WHEN NEW.method = 'face' AND NEW.status = 'present' THEN 1 ELSE 0 END,
        CASE WHEN NEW.method = 'zoom' AND NEW.status = 'present' THEN 1 ELSE 0 END
    FROM schedule sc
    WHERE sc.schedule_id = NEW.schedule_id
    ON CONFLICT (person_id, date)
    DO UPDATE SET
        attended_classes = attendance_analytics.attended_classes + CASE WHEN NEW.status = 'present' THEN 1 ELSE 0 END,
        rfid_scans = attendance_analytics.rfid_scans + CASE WHEN NEW.method = 'rfid' AND NEW.status = 'present' THEN 1 ELSE 0 END,
        face_recognitions = attendance_analytics.face_recognitions + CASE WHEN NEW.method = 'face' AND NEW.status = 'present' THEN 1 ELSE 0 END,
        zoom_attendances = attendance_analytics.zoom_attendances + CASE WHEN NEW.method = 'zoom' AND NEW.status = 'present' THEN 1 ELSE 0 END,
        last_updated = CURRENT_TIMESTAMP;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update analytics
CREATE TRIGGER attendance_analytics_trigger
    AFTER INSERT ON attendance
    FOR EACH ROW
    EXECUTE FUNCTION update_attendance_analytics();