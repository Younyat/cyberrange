# Terraform auto-generado para nodo victim 3 (id: node3)
data "openstack_networking_network_v2" "node3__network" {
  name = "red_privada"
}

data "openstack_networking_subnet_v2" "node3__subnet" {
  name       = "red_privada_subnet"
  network_id = data.openstack_networking_network_v2.node3__network.id
}

data "openstack_networking_secgroup_v2" "node3__secgroup" {
  name = "sg_wazuh_suricata"
}

data "openstack_images_image_v2" "node3__image" {
  name = "debian-12"
}

data "openstack_compute_flavor_v2" "node3__flavor" {
  name = "medium"
}

resource "openstack_compute_keypair_v2" "node3__keypair" {
  name       = "nueva_clave_wazuh_node3_"
  public_key = file("${path.module}/nueva_clave_wazuh.pub")
}

resource "openstack_networking_floatingip_v2" "node3__fip" {
  pool = "red_externa"
}

resource "openstack_networking_port_v2" "node3__port" {
  name               = "node3_-port"
  network_id         = data.openstack_networking_network_v2.node3__network.id
  security_group_ids = [data.openstack_networking_secgroup_v2.node3__secgroup.id]
  fixed_ip {
    subnet_id = data.openstack_networking_subnet_v2.node3__subnet.id
  }
}

resource "openstack_networking_floatingip_associate_v2" "node3__fip_associate" {
  floating_ip = openstack_networking_floatingip_v2.node3__fip.address
  port_id     = openstack_networking_port_v2.node3__port.id
}

resource "openstack_compute_instance_v2" "node3__instance" {
  name      = "victim 3"
  image_id  = data.openstack_images_image_v2.node3__image.id
  flavor_id = data.openstack_compute_flavor_v2.node3__flavor.id
  key_pair  = openstack_compute_keypair_v2.node3__keypair.name

  network {
    port = openstack_networking_port_v2.node3__port.id
  }
 user_data = <<CLOUDCONF
#cloud-config
ssh_pwauth: True
chpasswd:
  list: |
    debian:debian123
  expire: False
CLOUDCONF

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "debian"
      host        = openstack_networking_floatingip_v2.node3__fip.address
      private_key = file("${path.module}/nueva_clave_wazuh")
    }
    inline = [
      "echo 'cloud-init finished for victim 3 (node3_) - OS: debian-12'"
    ]
  }
}

output "node3__floating_ip" {
  value = openstack_networking_floatingip_v2.node3__fip.address
}
