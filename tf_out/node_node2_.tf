# Terraform auto-generado para nodo attack 2 (id: node2)
data "openstack_networking_network_v2" "node2__network" {
  name = "red_privada"
}

data "openstack_networking_subnet_v2" "node2__subnet" {
  name       = "red_privada_subnet"
  network_id = data.openstack_networking_network_v2.node2__network.id
}

data "openstack_networking_secgroup_v2" "node2__secgroup" {
  name = "sg_wazuh_suricata"
}

data "openstack_images_image_v2" "node2__image" {
  name = "debian-12"
}

data "openstack_compute_flavor_v2" "node2__flavor" {
  name = "medium"
}

resource "openstack_compute_keypair_v2" "node2__keypair" {
  name       = "nueva_clave_wazuh_node2_"
  public_key = file("${path.module}/nueva_clave_wazuh.pub")
}

resource "openstack_networking_floatingip_v2" "node2__fip" {
  pool = "red_externa"
}

resource "openstack_networking_port_v2" "node2__port" {
  name               = "node2_-port"
  network_id         = data.openstack_networking_network_v2.node2__network.id
  security_group_ids = [data.openstack_networking_secgroup_v2.node2__secgroup.id]
  fixed_ip {
    subnet_id = data.openstack_networking_subnet_v2.node2__subnet.id
  }
}

resource "openstack_networking_floatingip_associate_v2" "node2__fip_associate" {
  floating_ip = openstack_networking_floatingip_v2.node2__fip.address
  port_id     = openstack_networking_port_v2.node2__port.id
}

resource "openstack_compute_instance_v2" "node2__instance" {
  name      = "attack 2"
  image_id  = data.openstack_images_image_v2.node2__image.id
  flavor_id = data.openstack_compute_flavor_v2.node2__flavor.id
  key_pair  = openstack_compute_keypair_v2.node2__keypair.name

  network {
    port = openstack_networking_port_v2.node2__port.id
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
      host        = openstack_networking_floatingip_v2.node2__fip.address
      private_key = file("${path.module}/nueva_clave_wazuh")
    }
    inline = [
      "echo 'cloud-init finished for attack 2 (node2_) - OS: debian-12'"
    ]
  }
}

output "node2__floating_ip" {
  value = openstack_networking_floatingip_v2.node2__fip.address
}
