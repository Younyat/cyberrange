# Terraform auto-generado para nodo monitor 1 (id: node1)
data "openstack_networking_network_v2" "node1__network" {
  name = "red_privada"
}

data "openstack_networking_subnet_v2" "node1__subnet" {
  name       = "red_privada_subnet"
  network_id = data.openstack_networking_network_v2.node1__network.id
}

data "openstack_networking_secgroup_v2" "node1__secgroup" {
  name = "sg_wazuh_suricata"
}

data "openstack_images_image_v2" "node1__image" {
  name = "Ubuntu22.04"
}

data "openstack_compute_flavor_v2" "node1__flavor" {
  name = "large"
}

resource "openstack_compute_keypair_v2" "node1__keypair" {
  name       = "nueva_clave_wazuh_node1_"
  public_key = file("${path.module}/nueva_clave_wazuh.pub")
}

resource "openstack_networking_floatingip_v2" "node1__fip" {
  pool = "red_externa"
}

resource "openstack_networking_port_v2" "node1__port" {
  name               = "node1_-port"
  network_id         = data.openstack_networking_network_v2.node1__network.id
  security_group_ids = [data.openstack_networking_secgroup_v2.node1__secgroup.id]
  fixed_ip {
    subnet_id = data.openstack_networking_subnet_v2.node1__subnet.id
  }
}

resource "openstack_networking_floatingip_associate_v2" "node1__fip_associate" {
  floating_ip = openstack_networking_floatingip_v2.node1__fip.address
  port_id     = openstack_networking_port_v2.node1__port.id
}

resource "openstack_compute_instance_v2" "node1__instance" {
  name      = "monitor 1"
  image_id  = data.openstack_images_image_v2.node1__image.id
  flavor_id = data.openstack_compute_flavor_v2.node1__flavor.id
  key_pair  = openstack_compute_keypair_v2.node1__keypair.name

  network {
    port = openstack_networking_port_v2.node1__port.id
  }
 user_data = <<CLOUDCONF
#cloud-config
ssh_pwauth: True
chpasswd:
  list: |
    ubuntu:ubuntu123
  expire: False
CLOUDCONF

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = openstack_networking_floatingip_v2.node1__fip.address
      private_key = file("${path.module}/nueva_clave_wazuh")
    }
    inline = [
      "echo 'cloud-init finished for monitor 1 (node1_) - OS: Ubuntu22.04'"
    ]
  }
}

output "node1__floating_ip" {
  value = openstack_networking_floatingip_v2.node1__fip.address
}
