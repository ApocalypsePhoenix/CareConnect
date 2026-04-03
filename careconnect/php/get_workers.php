<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET");

include_once 'db_connect.php';

$database = new Database();
$db = $database->getConnection();

try {
    // We join the users table and worker_details table to get everything we need
    $query = "SELECT u.id, u.name, u.email, u.phone, u.address, u.gender, u.ic_number, u.profile_image,
                     w.is_verified, w.mobility_service, w.physio_service, w.nursing_service,
                     w.ic_doc_url, w.license_doc_url, w.cert_doc_url
              FROM users u
              JOIN worker_details w ON u.id = w.user_id
              WHERE u.role = 'Worker'
              ORDER BY u.created_at DESC";

    $stmt = $db->prepare($query);
    $stmt->execute();

    $workers = [];

    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        // Map the integer status to our dashboard text
        $status = 'PENDING';
        if ($row['is_verified'] == 1) {
            $status = 'APPROVED';
        } elseif ($row['is_verified'] == 2) {
            $status = 'REJECTED';
        }

        // Figure out their primary service label
        $services = [];
        if ($row['mobility_service']) $services[] = "Mobility Service";
        if ($row['physio_service']) $services[] = "Physiotherapy / Rehabilitation";
        if ($row['nursing_service']) $services[] = "Daily Assistance / Nursing Care";
        
        $serviceLabel = implode(", ", $services);
        if (empty($serviceLabel)) $serviceLabel = "Unspecified Service";
        
        // Use the first service for the filter category
        $primaryService = 'all';
        if ($row['mobility_service']) $primaryService = 'mobility service';
        elseif ($row['physio_service']) $primaryService = 'physiotherapy';
        elseif ($row['nursing_service']) $primaryService = 'daily assistance';

        // Prepare the profile image URL
        $profilePicUrl = !empty($row['profile_image']) 
            ? "https://arcadiusengine.xyz/careconnect/" . $row['profile_image'] 
            : "https://ui-avatars.com/api/?name=" . urlencode($row['name']) . "&background=6b436e&color=fff";

        $workers[] = [
            "id" => (int)$row['id'], // FIX: Forced to Integer so the JavaScript button click works!
            "name" => $row['name'],
            "status" => $status,
            "service" => $primaryService,
            "serviceLabel" => $serviceLabel,
            "email" => $row['email'],
            "address" => $row['address'],
            "gender" => $row['gender'],
            "ic" => $row['ic_number'],
            "profile_pic" => $profilePicUrl,
            "ic_doc" => $row['ic_doc_url'],
            "license_doc" => $row['license_doc_url'],
            "cert_doc" => $row['cert_doc_url']
        ];
    }

    http_response_code(200);
    echo json_encode(["success" => true, "workers" => $workers]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Server error: " . $e->getMessage()]);
}
?>