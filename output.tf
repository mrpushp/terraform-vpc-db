output "bastion_public_ip" {
    value = module.bastion.floating_ip_address
}

output "vm_private_ip" {
    value = ibm_is_instance.backend.*.primary_network_interface.0.primary_ipv4_address
}