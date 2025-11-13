<?php
// Create captures directory if it doesn't exist
if (!is_dir('cam_captures')) {
    mkdir('cam_captures', 0777, true);
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['image'])) {
    $uploadDir = 'cam_captures/';
    $filename = $_FILES['image']['name'];
    $uploadFile = $uploadDir . $filename;
    
    if (move_uploaded_file($_FILES['image']['tmp_name'], $uploadFile)) {
        echo "Capture saved: " . $filename;
    } else {
        echo "Error saving capture";
    }
} else {
    echo "Invalid request";
}
?>