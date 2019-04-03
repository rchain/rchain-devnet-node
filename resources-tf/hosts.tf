resource "google_compute_address" "node_ext_addr" {
  count = "${var.node_count}"
  name = "${var.resources_name}-node${count.index}"
  address_type = "EXTERNAL"
}

resource "google_dns_record_set" "node_dns_record" {
  count = "${var.node_count}"
  name = "node${count.index}${var.dns_suffix}."
  managed_zone = "rchain-dev"
  type = "A"
  ttl = 300
  rrdatas = ["${google_compute_address.node_ext_addr.*.address[count.index]}"]
}

resource "google_compute_instance" "node_host" {
  count = "${var.node_count}"
  name = "${var.resources_name}-node${count.index}"
  hostname = "node${count.index}${var.dns_suffix}"
  machine_type = "n1-highmem-2"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1810"
      size = 160
      type = "pd-standard"
    }
  }

  tags = [
    "${var.resources_name}-node-public",
    "${var.resources_name}-node-rpc",
    "${var.resources_name}-node-p2p",
    "collectd-out",
    "elasticsearch-out",
    "logstash-tcp-out"
  ]

  network_interface {
    network = "${data.google_compute_network.default_network.self_link}"
    access_config {
      nat_ip = "${google_compute_address.node_ext_addr.*.address[count.index]}"
      //public_ptr_domain_name = "node${count.index}${var.dns_suffix}."
    }
  }

  connection {
    type = "ssh"
    user = "root"
    private_key = "${file("~/.ssh/google_compute_engine")}"
  }

  provisioner "file" {
    source = "${var.rchain_sre_git_crypt_key_file}"
    destination = "/root/rchain-sre-git-crypt-key"
  }

  provisioner "remote-exec" {
    script = "../bootstrap.devnet"
  }
}
