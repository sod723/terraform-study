#볼륨추가
resource "openstack_blockstorage_volume_v3" "myvol" {
  region = "RegionOne"
  name = "myvol"
  size = 20
  image_id = "97d89ac9-c47c-4e69-b89b-9a9b398893a6"
}

#인스턴스
resource "openstack_compute_instance_v2" "basic-instance01" {
  name = "basic-instance01"
  image_id = "97d89ac9-c47c-4e69-b89b-9a9b398893a6"
  flavor_id = "6"
  key_pair = "mykey0823"
  security_groups = ["allow-web"]
  metadata = { key1 = "value1" }
  network {
    name = "private1"
  }
}

resource "openstack_networking_floatingip_v2" "fip_1" {
  pool = "extnet"
}

resource "openstack_compute_floatingip_associate_v2" "fip_1" {
  floating_ip = "${openstack_networking_floatingip_v2.fip_1.address}"
  instance_id = "${openstack_compute_instance_v2.basic-instance01.id}"
}

