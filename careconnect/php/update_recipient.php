<?php
// Add CORS headers
header('Access-Control-Allow-Origin: *');
header('Content-Type: application/json');

try {
    require_once 'db_connect.php';

    // Instantiate the Database class from your db_connect.php and get the connection
    $database = new Database();
    $dbConnection = $database->getConnection();

    if ($dbConnection === null) {
        echo json_encode(array('success' => false, 'message' => 'Fatal Error: Could not connect to the database.'));
        exit;
    }

    // Get JSON input from Flutter
    $json_input = file_get_contents("php://input");
    $data = json_decode($json_input, true);

    // Fallback just in case data was sent as form-urlencoded
    if (!$data) {
        $data = $_POST;
    }

    $id = isset($data['id']) ? (int)$data['id'] : 0;
    $name = isset($data['name']) ? $data['name'] : '';
    $relationship = isset($data['relationship']) ? $data['relationship'] : '';
    $age = isset($data['age']) ? (int)$data['age'] : 0;
    $medical_condition = isset($data['medical_condition']) ? $data['medical_condition'] : '';
    $special_needs = isset($data['special_needs']) ? $data['special_needs'] : '';

    if (empty($id) || empty($name)) {
        echo json_encode(array('success' => false, 'message' => 'ID and Name are required.'));
        exit;
    }

    // Prepare the statement targeting the 'recipients' table
    $sql = "UPDATE recipients SET name = ?, relationship = ?, age = ?, medical_condition = ?, special_needs = ? WHERE id = ?";
    
    // Execute the PDO statement
    $stmt = $dbConnection->prepare($sql);
    if (!$stmt) {
        echo json_encode(array('success' => false, 'message' => 'PDO Prepare Error.'));
        exit;
    }
    
    $stmt->execute([$name, $relationship, $age, $medical_condition, $special_needs, $id]);
    
    echo json_encode(array('success' => true, 'message' => 'Updated successfully.'));

} catch (\Throwable $e) {
    // Catch ANY fatal error and return it to Flutter safely
    http_response_code(200); 
    echo json_encode(array(
        'success' => false, 
        'message' => 'Fatal Error Caught: ' . $e->getMessage()
    ));
}
?>