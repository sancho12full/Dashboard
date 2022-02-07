#Configuracion de Terraform y registry/version del provider
terraform {
    required_providers {
      aws = {
          source = company-resgistry/aws #se usa el company name como muestra para el container registry del cual saca la imagen y luego el provider
          version = "~> 2.0" #es recomendable aclarar la version, luego de aclararla aca no se pone en provider
      }
   }

    required_version = ">= 0.12" 
}

#locals sirve para hacer variables locales y que no tengamos que repetir constantemente palabras
locals {
  local_name = "t2.micro"
}



#Configuracion restante del provider
provider "aws" {
    profile = "default" #las credenciales se configuran en aws configure por temas de seguridad
    region = "us-east-1"
}
#Se configura con dos parametros iniciales, tipo de instancia y luego un name que sera utilizado por propositos de terraform
#Creacion de VPC
resource "aws_vpc" "vpc-name" {
    cidr_block = "10.5.0.0/16"

    tags = {
        Name = "vpc-test"
    }
}
#Creacion de subnet a partir del vpc
resource "aws_subnet" "subnet-name" {
    vpc_id = aws_vpc.vpc-name.id #necesario para obtener data de recurso de VPC, se puede obtener otros datos usando el mismo metodo pero cambiando el 'id
    cidr_block = "10.5.0.0/16"

    tags = {
        Name = "subnet-test"
    }
}


#Creacion de variables
variable "my_intance_type" {
    type = string
    default = "t2.micro"
    description = "My instance type"
}

#Este tipo de varibale que no se especifica el default, cuando se ejecuta terraform apply consulta por un valor
variable "another_variable" {
    type = string
    description = "Another variable"
}


/*
Una buena practica para las variables es crear un file nuevo exclusivo para ellas ejecutando 'touch terraform.tfvars' lo cual va a crear
un archivo nuevo sobre el directorio el cual se puede utilizar de manejar muy sencilla
ej: my_intance_type = "t2.micro"

Tambien se crea un file llamado variables.tf en el cual se usa el mismo formato que arriba
*/

#Creacion de recurso (EC2) sin variables
resource "aws_instance" "ec2-name" {
    ami = "ami-id" #se usa un ami para el tipo de sistema operativo, probablemente este hardcodeado
    count = 2 #se utiliza para crear varias instancias iguales
    instance_type = "${local.local_name}" # (t2.micro) procesador o capacidad del sistema basicamente
    subnet_id = aws_subnet.subnet-name.id #puede o no attacharse el subnet

    tags = {
        tag-key = "tag-name"
        Name = "appnamepyt0${count.index}" #se puede diferencias las instancias con este metodo
        NumberEJ = 123
    }
}

#Creacion de recurso (EC2) con variables
resource "aws_instance" "ec2-name" {
    ami = "ami-id" 
    instance_type = var.my_intance_type 
    subnet_id = aws_subnet.subnet-name.id 

    tags = var.instance_tags
}

/*
La implentacion se da por Terraform CLI o dependiendo del orchestrador que se esta usando

Por CLI se usa 'terraform init' sobre el path del main.tf para descargar las dependencias y demas

Luego se usa 'terraform plan' te dice que es lo que se va a hacer con el file los parametros no especificados aparece como known after apply
Despues se usa 'terraform apply' el cual ejecuta el plan visto anteriormente y crea las intancias solicitadas, pide confirmacion y se puede revisar nuevamente el plan
Y por ultimo se puede utilizar 'terraform destroy' para eliminar la instancia si fuera necesario  

Para hacer modificaciones a la instancia se puede agregar o cambiar esas modificaciones y luego correr el apply nuevamente
Dependiendo el cambio que se haga necesita reboot o no
Tambien por ejemplo si se cambia el ami de la instancia se va a reemplazar por una nueva
*/


/*
Los modulos son archivos de terraform que sirven para no tener todo en un solo archivo MAIN. Este archivo es un modulo, se puede
hacer modulos de todo los recursos y demas. Las variables y los output se definen en el path (../modules/ec2-instance) del modulo como archivos o locales.
Generalmente se crea un archivo main.tf variables.tf y output.tf dependiendo lo que se necesite.
Se tienen que poner las variables que no esten definidas pero si declaradas del path del modulo. Cuando se agrega un modulo se
tiene que correr terraform init primero.
Dentro de los modules se pueden llamar a otros modulos.
*/
module "module_unique_name" {
    source = "PATH"
    vpc_id = aws_vpc.main.id
    cidr_block = " 10.0.0.0/16"
    ec2_name = "example"
    ami = "ami-example"
}

#output muestra valores que quiza quieras ver luego del apply
output vpc {
  value       = aws_vpc.vpc-name.id
  sensitive   = true
  description = "description"
}

