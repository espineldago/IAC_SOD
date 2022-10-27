terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name = "resource_group"
  location = "East US"
}

resource "azurerm_ssh_public_key" "key" {
  name = "key"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  public_key = file("class_key.pem.pub")
}

resource "azurerm_virtual_network" "vpc" {
  name = "vpc"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space = ["10.0.0.0/16"]
  
  tags = {
    "Name" = "Main VPC"
  }
  
}

resource "azurerm_subnet" "subnet2" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vpc.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "public_ip" {
  name = "public_ip"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  allocation_method = "Dynamic"
}


resource "azurerm_network_security_group" "sg" {
  name = "sg-HTTP-SSH"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allow-http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "0.0.0.0/0"
     destination_address_prefix = "*"
  }
   security_rule {
    name                       = "allow-ssh"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "45.238.183.186/32"
     destination_address_prefix = "*"
  }
  
}
e "azurerm_subnet_network_security_group_association" "association2" {
  subnet_id                 = azurerm_subnet.subnet2.id
  network_security_group_id = azurerm_network_security_group.sg.id
}

resource "azurerm_network_interface" "nic" {
  name = "nic"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name = "external"
    subnet_id = azurerm_subnet.subnet2.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.public_ip.id
  }
}

data "template_file" "linux-vm" {
  template = file("custom_data.sh")
}

resource "azurerm_linux_virtual_machine" "vm" {
  name = "vm"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  size = "Standard_F2"
  admin_username = "adminuser"
  custom_data    = base64encode(data.template_file.linux-vm.rendered)
  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]  

  admin_ssh_key {
    username = "adminuser"
    public_key = file("class_key.pem.pub")
  }

  os_disk {
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer = "UbuntuServer"
    sku = "16.04-LTS"
    version = "latest"
  }
}

