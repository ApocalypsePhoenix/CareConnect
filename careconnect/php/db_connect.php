<?php
// Set PHP to Global UTC Timezone
date_default_timezone_set('UTC');

// Database credentials
$servername = "localhost"; 
$username = "arcadius_owner"; 
$password = "R5#8%DOOg[{Y+z7="; 
$dbname = "arcadius_careconnect";

class Database {
    private $host;
    private $db_name;
    private $username;
    private $password;
    public $conn;

    public function __construct() {
        global $servername, $username, $password, $dbname;
        $this->host = $servername;
        $this->username = $username;
        $this->password = $password;
        $this->db_name = $dbname;
    }

    public function getConnection() {
        $this->conn = null;
        try {
            $this->conn = new PDO(
                "mysql:host=" . $this->host . ";dbname=" . $this->db_name,
                $this->username,
                $this->password
            );
            $this->conn->exec("set names utf8");
            
            // --- UPDATED: Force MySQL to use Global UTC (+00:00) ---
            $this->conn->exec("SET time_zone = '+00:00'");
            
            $this->conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        } catch(PDOException $exception) {
            header('Content-Type: application/json');
            echo json_encode(["success" => false, "message" => "Connection error: " . $exception->getMessage()]);
            exit;
        }
        return $this->conn;
    }
}
?>