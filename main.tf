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
  backend_ingress_cidr    = "0.0.0.0/0" # DANGER: cidr range that can access the front end service
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

resource "ibm_is_subnet" "backend" {
  name                     = "${var.basename}-backend-subnet"
  vpc                      = ibm_is_vpc.vpc.id
  zone                     = var.zone
  total_ipv4_address_count = 256
  resource_group           = data.ibm_resource_group.all_rg.id
}

resource "ibm_is_security_group" "backend" {
  name           = "${var.basename}-backend-sg"
  vpc            = ibm_is_vpc.vpc.id
  resource_group = data.ibm_resource_group.all_rg.id
}

resource "ibm_is_security_group_rule" "backend_egress_all" {
  group     = ibm_is_security_group.backend.id
  direction = "outbound"
  remote    = local.backend_ingress_cidr
}


#backend
locals {
  # create either [backend] or [backend, maintenance] depending on the var.maintenance boolean
  backend_security_groups = split(
    ",",
    var.maintenance ? format(
      "%s,%s",
      ibm_is_security_group.backend.id,
      module.bastion.security_group_id,
    ) : ibm_is_security_group.backend.id,
  )
}

resource "ibm_is_instance" "backend" {
  count          = var.backend_count
  name           = "${var.basename}-backend-vsi"
  image          = var.ibm_is_image_id
  profile        = var.profile
  vpc            = ibm_is_vpc.vpc.id
  zone           = var.zone
  keys           = [data.ibm_is_ssh_key.sshkey.id]
  user_data      = var.backend_user_data
  resource_group = data.ibm_resource_group.all_rg.id

  primary_network_interface {
    subnet          = ibm_is_subnet.backend.id
    security_groups = flatten([local.backend_security_groups])
  }
  volumes = [element(ibm_is_volume.volume.*.id, count.index)]
}

resource "ibm_is_floating_ip" "backend" {
  count          = var.backend_count
  name           = "${var.basename}-backend-ip"
  target         = element(ibm_is_instance.backend.*.primary_network_interface.0.id, count.index)
  resource_group = data.ibm_resource_group.all_rg.id
}

resource "ibm_is_volume" "volume" {
  count    = var.backend_count
  name     = "${var.basename}-backend-volume"
  zone     = var.zone
  iops     = var.iops
  capacity = var.capacity
  profile  = var.volume_profile
}


resource "null_resource" "mount" {
  count = var.backend_count
  connection {
    private_key  = var.ssh_private_key
    bastion_host = module.bastion.floating_ip_address
    host         = element(ibm_is_instance.backend.*.primary_network_interface.0.primary_ipv4_address, count.index)
    user         = "root"
  }
  provisioner "ansible" {
    plays {
      playbook {
        file_path = "${path.module}/playbooks/mount.yml"
      }
      verbose = true
      extra_vars = {
        block_storage = var.mount_path
      }
    }
    ansible_ssh_settings {
      insecure_no_strict_host_key_checking = true
      connect_timeout_seconds              = 60
    }

  }
}


resource "null_resource" "db2install" {
  count      = var.backend_count
  depends_on = [null_resource.mount]
  connection {
    private_key  = var.ssh_private_key
    bastion_host = module.bastion.floating_ip_address
    host         = element(ibm_is_instance.backend.*.primary_network_interface.0.primary_ipv4_address, count.index)
    user         = "root"
  }
  provisioner "ansible" {
    plays {
      playbook {
        file_path = "${path.module}/playbooks/db2install.yml"
      }
      verbose = true
       extra_vars = {
        db2_image_cos_url = var.db2_image_cos_url
        db2_install_dir = var.db2_install_dir
        db2_owner = var.db2_owner
        db2_owner_password = var.db2_owner_password
        db2_fence_user = var.db2_fence_user
        db2_port = var.db2_port
        db2_name = var.db2_name
      }
    }

    ansible_ssh_settings {
      insecure_no_strict_host_key_checking = true
      connect_timeout_seconds              = 60
    }

  }
}
