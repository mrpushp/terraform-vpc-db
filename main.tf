data "ibm_resource_group" "all_rg" {
  name = var.resource_group_name
}

resource "ibm_is_vpc" "vpc" {
  name           = var.vpc_name == "" ? var.basename : var.vpc_name
  resource_group = data.ibm_resource_group.all_rg.id
}

resource "ibm_is_public_gateway" "backend" {
  count = var.backend_pgw ? 1 : 0
  vpc   = ibm_is_vpc.vpc.id
  name  = "${var.basename}-${var.zone}-pubgw"
  zone  = var.zone
}

# bastion subnet and instance values needed by the bastion module
resource "ibm_is_subnet" "bastion" {
  name                     = "${var.basename}-bastion-subnet"
  vpc                      = ibm_is_vpc.vpc.id
  zone                     = var.zone
  total_ipv4_address_count = 256
  resource_group           = data.ibm_resource_group.all_rg.id
}

data "ibm_is_ssh_key" "sshkey" {
  name = var.ssh_key_name
}

locals {
  bastion_inress_cidr     = "0.0.0.0/0" # DANGER: cidr range that can ssh to the bastion when maintenance is enabled
  maintenance_egress_cidr = "0.0.0.0/0" # cidr range required to contact software repositories when maintenance is enabled
  frontend_ingress_cidr   = "0.0.0.0/0" # DANGER: cidr range that can access the front end service
}

module "bastion" {
  source                   = "./modules/bastion"
  basename                 = var.basename
  ibm_is_vpc_id            = ibm_is_vpc.vpc.id
  ibm_is_resource_group_id = data.ibm_resource_group.all_rg.id
  zone                     = var.zone
  remote                   = local.bastion_inress_cidr
  profile                  = var.profile
  ibm_is_image_id          = var.ibm_is_image_id
  ibm_is_ssh_key_id        = data.ibm_is_ssh_key.sshkey.id
  ibm_is_subnet_id         = ibm_is_subnet.bastion.id
}

# maintenance will require ingress from the bastion, so the bastion has output a maintenance SG
# maintenance may also include installing new versions of open source software that are not in the IBM mirrors
# add the additional egress required to the maintenance security group exported by the bastion
# for example at 53 DNS, 80 http, and 443 https probably make sense
resource "ibm_is_security_group_rule" "maintenance_egress_443" {
  group     = module.bastion.security_group_id
  direction = "outbound"
  remote    = local.maintenance_egress_cidr

  tcp {
    port_min = "443"
    port_max = "443"
  }
}

resource "ibm_is_security_group_rule" "maintenance_egress_80" {
  group     = module.bastion.security_group_id
  direction = "outbound"
  remote    = "0.0.0.0/0"

  tcp {
    port_min = 80
    port_max = 80
  }
}

resource "ibm_is_security_group_rule" "maintenance_egress_53" {
  group     = module.bastion.security_group_id
  direction = "outbound"
  remote    = "0.0.0.0/0"

  tcp {
    port_min = 53
    port_max = 53
  }
}

resource "ibm_is_security_group_rule" "maintenance_egress_udp_53" {
  group     = module.bastion.security_group_id
  direction = "outbound"
  remote    = "0.0.0.0/0"

  udp {
    port_min = 53
    port_max = 53
  }
}

resource "ibm_is_subnet" "frontend" {
  name                     = "${var.basename}-frontend-subnet"
  vpc                      = ibm_is_vpc.vpc.id
  zone                     = var.zone
  total_ipv4_address_count = 256
  resource_group           = data.ibm_resource_group.all_rg.id
}

resource "ibm_is_security_group" "frontend" {
  name           = "${var.basename}-frontend-sg"
  vpc            = ibm_is_vpc.vpc.id
  resource_group = data.ibm_resource_group.all_rg.id
}

resource "ibm_is_security_group_rule" "frontend_ingress_80_all" {
  group     = ibm_is_security_group.frontend.id
  direction = "inbound"
  remote    = local.frontend_ingress_cidr

  tcp {
    port_min = 80
    port_max = 80
  }
}

resource "ibm_is_security_group_rule" "frontend_ingress_22_bastion" {
  group     = ibm_is_security_group.frontend.id
  direction = "inbound"
  remote    = module.bastion.security_group_id

  tcp {
    port_min = 22
    port_max = 22
  }
}

/*resource "ibm_is_security_group_rule" "frontend_ingress_22_bastion_group" {
  group     = ibm_is_security_group.frontend.id
  direction = "inbound"
  remote    = module.bastion.bastion_security_group_id

  tcp {
    port_min = 22
    port_max = 22
  }
}*/


#Frontend
locals {
  # create either [frontend] or [frontend, maintenance] depending on the var.maintenance boolean
  frontend_security_groups = split(
    ",",
    var.maintenance ? format(
      "%s,%s",
      ibm_is_security_group.frontend.id,
      module.bastion.security_group_id,
    ) : ibm_is_security_group.frontend.id,
  )
}

resource "ibm_is_instance" "frontend" {
  name           = "${var.basename}-frontend-vsi"
  image          = var.ibm_is_image_id
  profile        = var.profile
  vpc            = ibm_is_vpc.vpc.id
  zone           = var.zone
  keys           = [data.ibm_is_ssh_key.sshkey.id]
  user_data      = var.frontend_user_data
  resource_group = data.ibm_resource_group.all_rg.id

  primary_network_interface {
    subnet          = ibm_is_subnet.frontend.id
    security_groups = flatten([local.frontend_security_groups])
  }
  volumes = [ibm_is_volume.volume.id]
}

/*resource "ibm_is_floating_ip" "frontend" {
  name           = "${var.basename}-frontend-ip"
  target         = ibm_is_instance.frontend.primary_network_interface[0].id
  resource_group = data.ibm_resource_group.all_rg.id
}*/

resource "ibm_is_volume" "volume" {
  name = "${var.basename}-frontend-volume"
  zone           = var.zone
  iops     = var.iops
  capacity = var.capacity
  profile = var.volume_profile
}


resource "null_resource" "ansible_runner" {
  connection {
    private_key  = var.ssh_private_key
    bastion_host = module.bastion.floating_ip_address
    host = ibm_is_instance.frontend.primary_network_interface.0.primary_ipv4_address
    user = "root"
  }
  provisioner "ansible" {
    plays {
      playbook {
        file_path = "${path.module}/playbooks/mount.yml"
      }
      verbose        = true
    }

      ansible_ssh_settings {
      insecure_no_strict_host_key_checking = true
      connect_timeout_seconds              = 60
    }

  }
}
