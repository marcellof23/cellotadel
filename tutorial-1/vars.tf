#Set your public SSH key here
variable "ssh_key" {
  default = "b3BlbnNzaC1rZXktdjEAAAAACmFlczI1Ni1jdHIAAAAGYmNyeXB0AAAAGAAAABD20ZZ2EHUcT524pZXg7BCUAAAAGAAAAAEAAAAzAAAAC3NzaC1lZDI1NTE5AAAAIPG04149/u1gKsCwa9l30fQ+k2hnPQhlOecwxIbqk6f+AAAAoDa2RdfbehKSXA8/VanUnmtnlv61ZDxMjMbIgBs9GO1r6j9iCejtclqqZcMF0/hC2ZjyRnkr+sIPYBUcxiGdIiR8u6yuiJAr14CsBB5cPuA7rM9zzc4WVHkY9JhC2YaaTB6tQ+tbmpKVrjvQyIuSH4vaesIpT2AzIRU0TAVBFzIBGy0/h3TC0iJhlV/1l+RRlQ6El9qnkEzrV8NSRpULkiE="
}
#Establish which Proxmox host you'd like to spin a VM up on
variable "proxmox_host" {
    default = "pve.home"
}
#Specify which template name you'd like to use
variable "template_name" {
    default = "talos-1.9.5-template"
}
#Establish which nic you would like to utilize
variable "nic_name" {
    default = "vmbr0"
}
#Establish the VLAN you'd like to use
variable "vlan_num" {
    default = ""
}
#Provide the url of the host you would like the API to communicate on.
#It is safe to default to setting this as the URL for what you used
#as your `proxmox_host`, although they can be different
variable "api_url" {
    default = "https://192.160.0.201:8006"
}
#Blank var for use by terraform.tfvars
variable "token_secret" {
}
#Blank var for use by terraform.tfvars
variable "token_id" {
}