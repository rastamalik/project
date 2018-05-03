provider "google" {
  version = "1.4.0"
  project = "${var.project}"
  region  = "${var.region}"

}


resource "google_compute_instance" "app" {
   name         = "gitlab-ci"
  machine_type = "n1-standard-1"
  zone         = "${var.zone}"
  boot_disk {
    initialize_params {
      image = "${var.disk_image}"
    }
  }

  metadata {
    sshKeys = "appuser:${file(var.public_key_path)} "
        
 }
  
  network_interface {
    network       = "default"
    access_config = {}
  }
  connection {
    type        = "ssh"
    user        = "appuser"
    agent       = false
    private_key = "${file(var.private_key)}"
  }
  
  provisioner "remote-exec" {
    script = "files/docker.sh"
  }
}
