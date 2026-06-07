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
    $db->beginTransaction();

    // ---------------------------------------------------------
    // STEP A: Insert the review safely into the database
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
    $avgQuery = "SELECT AVG(rating) as avg_rating, COUNT(*) as total_reviews FROM reviews WHERE reviewee_id = :reviewee_id";
    $avgStmt = $db->prepare($avgQuery);
    $avgStmt->execute([':reviewee_id' => $reviewee_id]);
    $result = $avgStmt->fetch(PDO::FETCH_ASSOC);
    
    $newAvg = $result['avg_rating'] ? round($result['avg_rating'], 2) : 0.00;
    $totalReviews = (int)$result['total_reviews'];

    $updateAvgQuery = "UPDATE users SET average_rating = :new_avg WHERE id = :reviewee_id";
    $db->prepare($updateAvgQuery)->execute([
        ':new_avg' => $newAvg, 
        ':reviewee_id' => $reviewee_id
    ]);

    // ---------------------------------------------------------
    // STEP C: PURE AVERAGE-BASED MODERATION (Grab/Uber Style)
    // ---------------------------------------------------------
    $statusMessage = "Review submitted successfully.";

    // Only apply moderation if the user has received at least 5 reviews (Grace Period)
    if ($totalReviews >= 5) {
        
        if ($newAvg < 3.0) {
            // Danger Zone: Average is extremely low. Ban the user.
            $db->prepare("UPDATE users SET account_status = 'Banned' WHERE id = :reviewee_id")->execute([':reviewee_id' => $reviewee_id]);
            $statusMessage = "Review submitted. User has been Banned due to a critically low average rating ($newAvg).";
            
        } elseif ($newAvg < 4.0) {
            // Warning Zone: Average is getting bad, but not ban-worthy yet.
            $db->prepare("UPDATE users SET account_status = 'Warning' WHERE id = :reviewee_id AND account_status != 'Banned'")->execute([':reviewee_id' => $reviewee_id]);
            $statusMessage = "Review submitted. User placed on Warning due to low average rating ($newAvg).";
            
        } else {
            // Safe Zone: Average is 4.0 or higher. 
            // If they were previously on a Warning, this restores them to Active!
            $db->prepare("UPDATE users SET account_status = 'Active' WHERE id = :reviewee_id AND account_status != 'Banned'")->execute([':reviewee_id' => $reviewee_id]);
        }
    }

    // Commit all changes
    $db->commit();

    echo json_encode([
        "success" => true, 
        "message" => $statusMessage,
        "new_average" => $newAvg
    ]);

} catch (PDOException $e) {
    $db->rollBack();
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>