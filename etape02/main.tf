terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.25.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

resource "docker_network" "app_network" {
  name = "app_network_unique"
}

resource "docker_volume" "app_volume" {
  name = "app_volume"
}

resource "docker_container" "http_container" {
  name  = "http"
  image = "nginx:latest"

  networks_advanced {
    name = docker_network.app_network.name
  }

  volumes {
    container_path = "/app"
    volume_name    = docker_volume.app_volume.name
  }

  ports {
    internal = 80
    external = 8080
  }

  upload {
    content = <<EOF
server {
    listen 80;
    server_name localhost;

    location / {
        root /app;
        index index.php index.html index.htm;
    }

    location ~ \.php$ {
        root /app;
        fastcgi_pass script:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF
    file    = "/etc/nginx/conf.d/default.conf"
  }
}

resource "docker_image" "php_image" {
  name = "php_custom:latest"
  build {
    context = "."
    dockerfile = "Dockerfile"
  }
}

resource "docker_container" "script_container" {
  name  = "script"
  image = docker_image.php_image.name

  networks_advanced {
    name = docker_network.app_network.name
  }

  volumes {
    container_path = "/app"
    volume_name    = docker_volume.app_volume.name
  }

  upload {
    content = <<EOF
<?php
$servername = "data";
$username = "root";
$password = "example";
$dbname = "testdb";

// Create connection
$conn = new mysqli($servername, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
  die("Connection failed: " . $conn->connect_error);
}

// Create table
$sql = "CREATE TABLE IF NOT EXISTS MyGuests (
id INT(6) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
firstname VARCHAR(30) NOT NULL,
lastname VARCHAR(30) NOT NULL,
reg_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
)";

if ($conn->query($sql) === TRUE) {
  echo "Table MyGuests created successfully";
} else {
  echo "Error creating table: " . $conn->error;
}

// Insert data
$sql = "INSERT INTO MyGuests (firstname, lastname) VALUES ('John', 'Doe')";

if ($conn->query($sql) === TRUE) {
  echo "New record created successfully";
} else {
  echo "Error: " . $sql . "<br>" . $conn->error;
}

// Select data
$sql = "SELECT id, firstname, lastname FROM MyGuests";
$result = $conn->query($sql);

if ($result->num_rows > 0) {
  // output data of each row
  while($row = $result->fetch_assoc()) {
    echo "id: " . $row["id"]. " - Name: " . $row["firstname"]. " " . $row["lastname"]. "<br>";
  }
} else {
  echo "0 results";
}
$conn->close();
?>
EOF
    file    = "/app/test_bdd.php"
  }
}

resource "docker_container" "data_container" {
  name  = "data"
  image = "mariadb:latest"

  networks_advanced {
    name = docker_network.app_network.name
  }

  env = [
    "MYSQL_ROOT_PASSWORD=example",
    "MYSQL_DATABASE=testdb"
  ]

  volumes {
    container_path = "/var/lib/mysql"
    volume_name    = docker_volume.app_volume.name
  }

  ports {
    internal = 3306
    external = 3306
  }
}
