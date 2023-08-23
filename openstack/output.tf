output "instance_name" {
  description = "생성된 인스턴스의 이름"
  value       = openstack_compute_instance_v2.basic-instance01.name
}

output "floating_ip_address" {
  description = "할당된 플로팅 IP 주소"
  value       = openstack_networking_floatingip_v2.fip_1.address
}

