# this module does not have defaults for anything but the port that the backend makes available to the frontend

# ssh key name the string 'pfq' in the example below:
# $ ibmcloud is keys
# Listing keys under account Powell Quiring's Account as user pquiring@us.ibm.com...
# ID                                     Name   Type   Length   FingerPrint          Created
# 636f6d70-0000-0001-0000-00000014f113   pfq    rsa    4096     vaziuuZ4/BVQrgFO..   2 months ago
variable "ssh_key_name" {
}

# string added to the front for all created resources, except perhaps the vpc - see next variable
variable "basename" { 
    default = "mydb"
}

# if this is empty use the basename for the vpc name.  If not empty then use this for the vpc_name
variable "vpc_name" {
    default = "mydb"
}

# zone string, us-south-1, in the example below
# $ ibmcloud is zones
# Listing zones in target region us-south under account Powell Quiring's Account as user pquiring@us.ibm.com...
# Name         Region     Status   
# us-south-3   us-south   available   
# us-south-1   us-south   available   
# us-south-2   us-south   available   
variable "zone" {
    default = "us-south-1"
}

# instance profile string, cc1-2x4, in the example below
# $ ibmcloud is instance-profiles
# Listing server profiles under account Powell Quiring's Account as user pquiring@us.ibm.com...
# Name         Family
# ...
# cc1-2x4      cpu
variable "profile" {
    default = "mx2-32x256"
}

# image ID, cc8debe0-1b30-6e37-2e13-744bfb2a0c11, in the example below
# $ ibmcloud is images
# Listing images under account Powell Quiring's Account as user pquiring@us.ibm.com...
# ID                                     Name                    OS                                                        Created        Status   Visibility
# cc8debe0-1b30-6e37-2e13-744bfb2a0c11   centos-7.x-amd64        CentOS (7.x - Minimal Install)                            6 months ago   READY    public
# cfdaf1a0-5350-4350-fcbc-97173b510843   ubuntu-18.04-amd64      Ubuntu Linux (18.04 LTS Bionic Beaver Minimal Install)    6 months ago   READY    public
# ...
variable "ibm_is_image_id" {
    default = "r006-931515d2-fcc3-11e9-896d-3baa2797200f"  #ibm-redhat-7-6-minimal-amd64-1
}

# set to true if the backend should have a public gateway.  This is used to provision software.
variable "backend_pgw" {
    default = true
}

# when true, instance will add the bastion maintenance security group
# to their security group list, allowing ssh access from the bastion
variable "maintenance" {
    default = true
}

# provide the cloud-init script, empty means none
variable "frontend_user_data" {
    default = ""
}

variable "resource_group_name" {
}

variable "ssh_private_key" {
    default = <<EOF
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAuuK3jB4OA+0absjh8UtyBTsMTMZoxz3xXAVvp4HmSv+H/jQX
9Ht8WivPSPhiFJW48jgSwqKB/1PULVT/PGHHgZn0zMEvokUnUSf/Zzysli+dBjg7
iaId0xZQn/goodLojSHCW7QAfH/J2Vb6U/llE0iIp8xB+72ogIdDhNo/rzQOBJU4
udQ0yRbg+rCBht5a5YsMnPW2QHOcQXFGq4rBVRg9t666ubSXHntcgtebIJYk/Wm9
r8MAS983X+LZNK2bqdKDnndJU34G0A469wfqd3VM0+md9wgxqE7lcyTEuylyGg2m
48I60UurPEqi708TCIEPtuP4jf+z14Oxq+wbQwIDAQABAoIBAH648wsA6jIBWbYb
YxHyPZuMYZfBxhSsTPg/+2kTLSxXv0hA3Kl7/mNKZ6EsQ51/tMwR966g8RNILYyb
oQK5rsWTtqoMqRcYW0OtooLHYqPoH0qzYLPACQc0j3EZnbu1PtlMNfVmxhmlsSI9
1zqP1tjPi1J0r51bCmI01jTEpQBQWf2btoKGZJmFKxSNSk+mNSN4URxtJbhQmqsr
l2tGOg2vZQYDaEPnJOxkL3Ijv2toRm7vMuCFGAT4j4KnTltIIQnvqCWNhwJqKuDx
IdS3HNUqQSTaDdPXVsEMFJxto/AiVUs38mixM63xIx0avIeocQ+DDHEKScxdx/d0
MPRpKIECgYEA90wnhk6nOYGtxb2s1CGw618HPgRzJ3bkaRh9YSFTxa3xGV7yUHcb
OxsUa5h9SO+gTMUeILUmBJz4UGZgI9K3knmabUJE41nU53HR3wwK+adQQHwkVuVS
xJVpFgjMGhvWDYSoJs2KEa/nUCmoPKu8C+eH9ds3WMoHsGoP8DMr1cECgYEAwXZT
fCyqtsjfS5tZe9v4xcJiHXSdEVP5yk+H2ejpStErPVEimMySRN0atHAL0RNejVdO
r0s6i/6I3Jkv1zkyDgnaw3B4fcpS6uqPjPuURuqvDMY4MDGrCrabO+1JJpsG1h+4
njG/C6KB/Q6CtMe1MjsNF0bcDBGaPRuvDdlzGgMCgYEAzOktVvyVU/FALDmem6fP
ETkMpzbItEqvuOWx/mm/IG2g+YTTBBmtVqx5ny4bofPsv7AV5sQzXF804mnx/7z6
n0Rj0WS38CrfX2fQnyE7duJMfSJgeiBLFNk42ikv9fJay5jAPGbToRRAdwwNezhR
+QtAfVfH5KqC9Irt6fp8uAECgYAsFaCUjUEhgciQXAgaF1grCE5/U9Fu32nuVg0o
9NAkgmGOCW0O0J8MHi41q8qli/phzuFZRJVEzW22hxnFu3zSgiBdpMVwNKiMa4Lm
p3V0a4oUKR8orEjDmjTphPrEV1NJe9UAB2n3ZsKkPag/NbruhVJIWZdPELvK7QII
7+IwrQKBgBU8C8q2Dh1E7mj5LnlTgqjgLFTqtzZex7MjnBobdfMS/lhfkU6ufnxR
ClOYphom/E9jH6mQ47WmhZqhjMyz5lvfTHVYcm2mz2RPiIG7w6nG7ghHKdo25+04
u4UPFG89Lqn9e+vbDUoro3u3tX+rv6nonIotrVJJrqkohlgXN9/Z
-----END RSA PRIVATE KEY-----
EOF
}