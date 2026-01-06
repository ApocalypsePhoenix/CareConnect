CREATE DATABASE IF NOT EXISTS arcadius_careconnect;
USE arcadius_careconnect;

-- Table for core account information
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    ic_number VARCHAR(20) UNIQUE NOT NULL,
    phone VARCHAR(20) NOT NULL,
    gender ENUM('Male', 'Female') NOT NULL,
    address TEXT NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('Client', 'Worker', 'Admin') NOT NULL DEFAULT 'Client',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Table for care recipients (The elderly individuals)
-- Linked to a Client user. One client can have many recipients.
CREATE TABLE recipients (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    name VARCHAR(255) NOT NULL,
    age INT NOT NULL,
    relationship VARCHAR(50), -- e.g., 'Parent', 'Self'
    medical_condition TEXT,
    special_needs TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Table for Worker specific details (Phase 2 & 3)
CREATE TABLE worker_details (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    mobility_service TINYINT(1) DEFAULT 0,
    physio_service TINYINT(1) DEFAULT 0,
    nursing_service TINYINT(1) DEFAULT 0,
    is_verified TINYINT(1) DEFAULT 0,
    profile_pic_url VARCHAR(255),
    ic_doc_url VARCHAR(255),
    license_doc_url VARCHAR(255),
    cert_doc_url VARCHAR(255),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;