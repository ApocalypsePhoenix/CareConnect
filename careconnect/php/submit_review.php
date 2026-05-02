<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

include_once 'db_connect.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"), true);

// 1. Verify we received all required data
if (
    empty($data['booking_id']) || 
    empty($data['reviewer_id']) || 
    empty($data['reviewee_id']) || 
    empty($data['rating'])
) {
    echo json_encode(["success" => false, "message" => "Missing required fields."]);
    exit;
}

$booking_id = $data['booking_id'];
$reviewer_id = $data['reviewer_id'];
$reviewee_id = $data['reviewee_id'];
$rating = (int)$data['rating'];
$comment = isset($data['comment']) ? trim($data['comment']) : '';

try {
    // We use a transaction so if anything fails, it safely rolls back
    $db->beginTransaction();

    // ---------------------------------------------------------
    // STEP A: Insert the review safely into the permanent backup table
    // ---------------------------------------------------------
    $insertQuery = "INSERT INTO reviews (booking_id, reviewer_id, reviewee_id, rating, comment) 
                    VALUES (:booking_id, :reviewer_id, :reviewee_id, :rating, :comment)";
    $stmt = $db->prepare($insertQuery);
    $stmt->execute([
        ':booking_id' => $booking_id,
        ':reviewer_id' => $reviewer_id,
        ':reviewee_id' => $reviewee_id,
        ':rating' => $rating,
        ':comment' => $comment
    ]);

    // ---------------------------------------------------------
    // STEP B: Update the user's overall average rating
    // ---------------------------------------------------------
    $avgQuery = "SELECT AVG(rating) as avg_rating FROM reviews WHERE reviewee_id = :reviewee_id";
    $avgStmt = $db->prepare($avgQuery);
    $avgStmt->execute([':reviewee_id' => $reviewee_id]);
    $avgResult = $avgStmt->fetch(PDO::FETCH_ASSOC);
    $newAvg = $avgResult['avg_rating'] ? round($avgResult['avg_rating'], 2) : 0.00;

    $updateAvgQuery = "UPDATE users SET average_rating = :new_avg WHERE id = :reviewee_id";
    $db->prepare($updateAvgQuery)->execute([
        ':new_avg' => $newAvg, 
        ':reviewee_id' => $reviewee_id
    ]);

    // ---------------------------------------------------------
    // STEP C: SMART WARNING & BANNING SYSTEM (3 Strikes Rule)
    // ---------------------------------------------------------
    $statusMessage = "Review submitted successfully.";
    
    if ($rating <= 2) {
        // Increment their warning count by 1
        $warnQuery = "UPDATE users SET warning_count = warning_count + 1 WHERE id = :reviewee_id";
        $db->prepare($warnQuery)->execute([':reviewee_id' => $reviewee_id]);

        // Fetch their newly updated warning count to see if we need to ban them
        $checkWarnQuery = "SELECT warning_count FROM users WHERE id = :reviewee_id";
        $checkStmt = $db->prepare($checkWarnQuery);
        $checkStmt->execute([':reviewee_id' => $reviewee_id]);
        $warnResult = $checkStmt->fetch(PDO::FETCH_ASSOC);
        $currentWarnings = (int)$warnResult['warning_count'];

        if ($currentWarnings >= 3) {
            // 3rd strike! Ban the user permanently.
            $banQuery = "UPDATE users SET account_status = 'Banned' WHERE id = :reviewee_id";
            $db->prepare($banQuery)->execute([':reviewee_id' => $reviewee_id]);
            $statusMessage = "Review submitted. User has been banned due to receiving 3 warnings.";
        } else {
            // 1st or 2nd strike. Set them to Warning status.
            $setWarnQuery = "UPDATE users SET account_status = 'Warning' WHERE id = :reviewee_id AND account_status != 'Banned'";
            $db->prepare($setWarnQuery)->execute([':reviewee_id' => $reviewee_id]);
            $statusMessage = "Review submitted. User has received a warning ($currentWarnings/3).";
        }
    }

    // Commit all these changes at once
    $db->commit();

    echo json_encode([
        "success" => true, 
        "message" => $statusMessage,
        "new_average" => $newAvg
    ]);

} catch (PDOException $e) {
    // If anything broke, undo everything to keep data safe
    $db->rollBack();
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>